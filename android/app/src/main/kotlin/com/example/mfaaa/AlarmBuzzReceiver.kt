package com.example.mfaaa

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.media.AudioAttributes
import android.os.Build
import android.os.VibrationEffect
import android.os.Vibrator
import android.os.VibratorManager

// Fires from AlarmManager.setAlarmClock() at alarm time — while the phone is
// locked, the app is backgrounded, or the process is dead — and hands off to
// the vibration foreground service.
class AlarmBuzzReceiver : BroadcastReceiver() {

    companion object {
        const val EXTRA_REQUEST_CODE = "requestCode"
    }

    override fun onReceive(context: Context, intent: Intent) {
        val requestCode = intent.getIntExtra(EXTRA_REQUEST_CODE, -1)
        if (requestCode != -1) AlarmBuzzScheduler.markFired(context, requestCode)

        val alarmId = intent.getIntExtra(AlarmBuzzService.EXTRA_ALARM_ID, -1)
        try {
            AlarmBuzzService.start(context, alarmId)
        } catch (_: Exception) {
            // Foreground start refused (shouldn't happen off setAlarmClock,
            // but OEMs get creative) — buzz straight from the receiver as a
            // best effort. Lives only as long as the process, but it's better
            // than a silent alarm.
            vibrateDirectly(context)
        }
    }

    private fun vibrateDirectly(context: Context) {
        try {
            val vibrator = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                (context.getSystemService(Context.VIBRATOR_MANAGER_SERVICE) as VibratorManager).defaultVibrator
            } else {
                @Suppress("DEPRECATION")
                context.getSystemService(Context.VIBRATOR_SERVICE) as Vibrator
            }
            val timings = longArrayOf(0, 1400, 100, 250, 70, 250, 70, 250, 70, 250, 100, 700, 150)
            val attributes = AudioAttributes.Builder()
                .setUsage(AudioAttributes.USAGE_ALARM)
                .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                .build()
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                @Suppress("DEPRECATION")
                vibrator.vibrate(VibrationEffect.createWaveform(timings, 0), attributes)
            } else {
                @Suppress("DEPRECATION")
                vibrator.vibrate(timings, 0, attributes)
            }
        } catch (_: Exception) {
        }
    }
}
