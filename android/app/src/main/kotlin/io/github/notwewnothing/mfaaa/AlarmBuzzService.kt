package io.github.notwewnothing.mfaaa

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.media.AudioAttributes
import android.media.AudioManager
import android.media.MediaPlayer
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.os.PowerManager
import android.os.SystemClock
import android.os.VibrationAttributes
import android.os.VibrationEffect
import android.os.Vibrator
import android.os.VibratorManager
import java.io.File

// Foreground service that makes the alarm genuinely inescapable. The device
// vibrates continuously at full amplitude for VIBRATE_FOR_MS, and the bundled
// alarm sound is blasted at forced-max alarm volume on an escalating schedule
// (PLAY_TARGETS). Everything runs with ALARM usage attributes, so it keeps
// going while the phone is locked, while other apps are in the foreground,
// and while the Flutter UI is dead. The in-app buttons do NOT stop it — the
// service quits on its own once the last blast finishes.
class AlarmBuzzService : Service() {

    companion object {
        const val EXTRA_ALARM_ID = "alarmId"
        const val EXTRA_FRESH_FIRE = "freshFire"
        const val PREFS = "alarm_buzz"
        const val KEY_ACTIVE_ID = "activeAlarmId"

        private const val CHANNEL_ID = "alarm_buzz_service"
        private const val NOTIFICATION_ID = 0x7A11

        // [offMs, onMs, offMs, onMs, ...] — a long roar, a machine-gun burst,
        // then a medium roar. Loops forever in hardware (repeat = 0). Gaps are
        // tiny so it reads as one relentless, urgent buzz.
        private val TIMINGS = longArrayOf(0, 1400, 100, 250, 70, 250, 70, 250, 70, 250, 100, 700, 150)

        // Same length as TIMINGS: 0 for the gaps, 255 (max) for the buzzes.
        private val AMPLITUDES = intArrayOf(0, 255, 0, 255, 0, 255, 0, 255, 0, 255, 0, 255, 0)

        // Several OEMs silently cap a looping waveform after a few seconds;
        // re-issuing it on an interval makes it genuinely endless.
        private const val KEEPALIVE_MS = 5000L

        // Vibration never lets up for a full 10 minutes.
        private const val VIBRATE_FOR_MS = 10 * 60 * 1000L

        // Blast start times, ms since the sequence began: 3 blasts 10s apart,
        // 3 more 30s apart, 3 more 60s apart, and a final 5 blasts 5min apart.
        // Each blast restarts the track from the top if it is still playing.
        private val PLAY_TARGETS = longArrayOf(
            0, 10_000, 20_000,
            50_000, 80_000, 110_000,
            170_000, 230_000, 290_000,
            590_000, 890_000, 1_190_000, 1_490_000, 1_790_000,
        )

        // The bundled track runs ~106s; the hard deadline covers the final
        // blast plus slack in case MediaPlayer dies without ever delivering
        // its completion callback.
        private const val SHUTDOWN_SLACK_MS = 180_000L

        private const val SOUND_ASSET = "flutter_assets/assets/1784034034146_afbm86.mp3"

        fun start(context: Context, alarmId: Int, freshFire: Boolean = false) {
            val intent = Intent(context, AlarmBuzzService::class.java)
                .putExtra(EXTRA_ALARM_ID, alarmId)
                .putExtra(EXTRA_FRESH_FIRE, freshFire)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(intent)
            } else {
                context.startService(intent)
            }
        }

        fun stop(context: Context) {
            context.stopService(Intent(context, AlarmBuzzService::class.java))
        }
    }

    private val handler = Handler(Looper.getMainLooper())
    private var wakeLock: PowerManager.WakeLock? = null
    private var player: MediaPlayer? = null
    private var playIndex = 0
    private var sequenceStartedAt = -1L
    private var soundStaged = false

    private val keepAlive = object : Runnable {
        override fun run() {
            buzz()
            handler.postDelayed(this, KEEPALIVE_MS)
        }
    }

    private val vibrationCutoff = Runnable {
        handler.removeCallbacks(keepAlive)
        try {
            vibrator.cancel()
        } catch (_: Exception) {
        }
    }

    private val soundStep = object : Runnable {
        override fun run() {
            forceMaxAlarmVolume()
            blast()
            playIndex++
            if (playIndex < PLAY_TARGETS.size) {
                val elapsed = SystemClock.elapsedRealtime() - sequenceStartedAt
                handler.postDelayed(this, (PLAY_TARGETS[playIndex] - elapsed).coerceAtLeast(0L))
            }
        }
    }

    // Turned the volume down mid-blast? It goes right back up every second.
    private val volumeGuard = object : Runnable {
        override fun run() {
            val current = player ?: return
            val playing = try {
                current.isPlaying
            } catch (_: Exception) {
                false
            }
            if (!playing) return
            forceMaxAlarmVolume()
            handler.postDelayed(this, 1000L)
        }
    }

    private val shutdown = Runnable { stopSelf() }

    private val vibrator: Vibrator by lazy {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            (getSystemService(Context.VIBRATOR_MANAGER_SERVICE) as VibratorManager).defaultVibrator
        } else {
            @Suppress("DEPRECATION")
            getSystemService(Context.VIBRATOR_SERVICE) as Vibrator
        }
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onCreate() {
        super.onCreate()
        val pm = getSystemService(Context.POWER_SERVICE) as PowerManager
        wakeLock = pm.newWakeLock(PowerManager.PARTIAL_WAKE_LOCK, "mfaaa:AlarmBuzz").apply {
            setReferenceCounted(false)
            acquire(12 * 60 * 60 * 1000L)
        }
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val notification = buildNotification()
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
            startForeground(
                NOTIFICATION_ID,
                notification,
                ServiceInfo.FOREGROUND_SERVICE_TYPE_SYSTEM_EXEMPTED,
            )
        } else {
            startForeground(NOTIFICATION_ID, notification)
        }

        // intent is null on a START_STICKY restart — keep the persisted id.
        if (intent != null) {
            getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit()
                .putInt(KEY_ACTIVE_ID, intent.getIntExtra(EXTRA_ALARM_ID, -1))
                .apply()
        }

        // A fresh AlarmManager fire restarts the whole sequence; anything else
        // (the ring page reopening mid-ring, a START_STICKY restart) must not
        // reset the clock on a sequence already in flight.
        val freshFire = intent?.getBooleanExtra(EXTRA_FRESH_FIRE, false) ?: false
        if (freshFire || sequenceStartedAt < 0) startSequence()
        return START_STICKY
    }

    private fun startSequence() {
        handler.removeCallbacksAndMessages(null)
        sequenceStartedAt = SystemClock.elapsedRealtime()
        playIndex = 0
        keepAlive.run()
        handler.postDelayed(vibrationCutoff, VIBRATE_FOR_MS)
        soundStep.run()
        handler.postDelayed(shutdown, PLAY_TARGETS.last() + SHUTDOWN_SLACK_MS)
    }

    private fun blast() {
        stopPlayer()
        try {
            val mp = MediaPlayer()
            mp.setAudioAttributes(alarmAudioAttributes())
            mp.setDataSource(soundFile().absolutePath)
            mp.setVolume(1f, 1f)
            mp.setOnCompletionListener {
                stopPlayer()
                if (playIndex >= PLAY_TARGETS.size) stopSelf()
            }
            mp.prepare()
            mp.start()
            player = mp
            handler.removeCallbacks(volumeGuard)
            handler.postDelayed(volumeGuard, 1000L)
        } catch (_: Exception) {
            // Sound failed (asset missing, media stack weirdness) — vibration
            // and the shutdown deadline still run, so the alarm degrades
            // instead of dying.
            stopPlayer()
        }
    }

    private fun stopPlayer() {
        handler.removeCallbacks(volumeGuard)
        player?.let {
            try {
                it.stop()
            } catch (_: Exception) {
            }
            try {
                it.release()
            } catch (_: Exception) {
            }
        }
        player = null
    }

    private fun forceMaxAlarmVolume() {
        try {
            val am = getSystemService(Context.AUDIO_SERVICE) as AudioManager
            am.setStreamVolume(
                AudioManager.STREAM_ALARM,
                am.getStreamMaxVolume(AudioManager.STREAM_ALARM),
                0,
            )
        } catch (_: Exception) {
        }
    }

    // Flutter packs assets under flutter_assets/ inside the APK; MediaPlayer
    // can't read compressed APK entries, so stage a plain copy in the cache
    // dir. Re-copied once per service instance so app updates take effect.
    private fun soundFile(): File {
        val staged = File(cacheDir, "alarm_blast.mp3")
        if (!soundStaged) {
            try {
                assets.open(SOUND_ASSET).use { input ->
                    staged.outputStream().use { input.copyTo(it) }
                }
                soundStaged = true
            } catch (_: Exception) {
                // Fall back to whatever a previous run staged.
            }
        }
        return staged
    }

    private fun buzz() {
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                val effect = if (vibrator.hasAmplitudeControl()) {
                    VibrationEffect.createWaveform(TIMINGS, AMPLITUDES, 0)
                } else {
                    VibrationEffect.createWaveform(TIMINGS, 0)
                }
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                    vibrator.vibrate(
                        effect,
                        VibrationAttributes.createForUsage(VibrationAttributes.USAGE_ALARM),
                    )
                } else {
                    @Suppress("DEPRECATION")
                    vibrator.vibrate(effect, alarmAudioAttributes())
                }
            } else {
                @Suppress("DEPRECATION")
                vibrator.vibrate(TIMINGS, 0, alarmAudioAttributes())
            }
        } catch (_: Exception) {
        }
    }

    private fun alarmAudioAttributes(): AudioAttributes =
        AudioAttributes.Builder()
            .setUsage(AudioAttributes.USAGE_ALARM)
            .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
            .build()

    private fun buildNotification(): Notification {
        val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            // Mandatory companion notification for the foreground service.
            // Deliberately silent and low-importance — the loud, full-screen
            // alarm notification is posted separately by the Flutter side.
            val channel = NotificationChannel(
                CHANNEL_ID,
                "Alarm vibration",
                NotificationManager.IMPORTANCE_LOW,
            ).apply {
                setSound(null, null)
                enableVibration(false)
                setShowBadge(false)
            }
            manager.createNotificationChannel(channel)
        }

        val launch = packageManager.getLaunchIntentForPackage(packageName)
        val contentIntent = launch?.let {
            PendingIntent.getActivity(
                this,
                0,
                it,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
            )
        }

        val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(this, CHANNEL_ID)
        } else {
            @Suppress("DEPRECATION")
            Notification.Builder(this).setPriority(Notification.PRIORITY_LOW)
        }
        return builder
            .setSmallIcon(R.drawable.ic_stat_alarm)
            .setContentTitle("ALARM RINGING")
            .setContentText("It stops when it's done. GET UP.")
            .setOngoing(true)
            .apply { if (contentIntent != null) setContentIntent(contentIntent) }
            .build()
    }

    override fun onTaskRemoved(rootIntent: Intent?) {
        // User swiped the app away — keep ringing. That's the whole point.
    }

    override fun onDestroy() {
        handler.removeCallbacksAndMessages(null)
        stopPlayer()
        try {
            vibrator.cancel()
        } catch (_: Exception) {
        }
        getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit()
            .remove(KEY_ACTIVE_ID)
            .apply()
        wakeLock?.let { if (it.isHeld) it.release() }
        wakeLock = null
        super.onDestroy()
    }
}
