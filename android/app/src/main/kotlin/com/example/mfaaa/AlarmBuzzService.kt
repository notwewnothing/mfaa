package com.example.mfaaa

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.media.AudioAttributes
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.os.PowerManager
import android.os.VibrationAttributes
import android.os.VibrationEffect
import android.os.Vibrator
import android.os.VibratorManager

// Foreground service that drives the device vibrator at full amplitude for as
// long as it lives. The vibration is issued to the system VibratorService with
// USAGE_ALARM attributes, so it keeps buzzing while the phone is locked, while
// other apps are in the foreground, and while the Flutter UI is dead. It stops
// ONLY when the service is stopped (ring page stop/snooze via MethodChannel).
class AlarmBuzzService : Service() {

    companion object {
        const val EXTRA_ALARM_ID = "alarmId"
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

        fun start(context: Context, alarmId: Int) {
            val intent = Intent(context, AlarmBuzzService::class.java)
                .putExtra(EXTRA_ALARM_ID, alarmId)
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
    private val keepAlive = object : Runnable {
        override fun run() {
            buzz()
            handler.postDelayed(this, KEEPALIVE_MS)
        }
    }

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

        handler.removeCallbacks(keepAlive)
        keepAlive.run()
        return START_STICKY
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
            .setSmallIcon(applicationInfo.icon)
            .setContentTitle("ALARM RINGING")
            .setContentText("Vibrating — open the app to stop")
            .setOngoing(true)
            .apply { if (contentIntent != null) setContentIntent(contentIntent) }
            .build()
    }

    override fun onTaskRemoved(rootIntent: Intent?) {
        // User swiped the app away — keep ringing. That's the whole point.
    }

    override fun onDestroy() {
        handler.removeCallbacks(keepAlive)
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
