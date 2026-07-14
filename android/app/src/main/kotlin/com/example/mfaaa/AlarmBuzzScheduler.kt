package com.example.mfaaa

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build

// Schedules the native vibration alarms that mirror every notification the
// Flutter side schedules. setAlarmClock() fires exactly (even in Doze) and
// grants the background-start exemption AlarmBuzzReceiver needs to launch the
// foreground service while the app is dead or the phone is locked.
//
// Entries are persisted as "requestCode|alarmId|epochMillis" so the boot
// receiver can rebuild them after a reboot or app update.
object AlarmBuzzScheduler {

    private const val KEY_SCHEDULED = "scheduled"

    fun schedule(context: Context, requestCode: Int, alarmId: Int, triggerAtMillis: Long) {
        val am = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val pi = pendingIntent(context, requestCode, alarmId)

        val canExact = Build.VERSION.SDK_INT < Build.VERSION_CODES.S || am.canScheduleExactAlarms()
        if (canExact) {
            val show = context.packageManager.getLaunchIntentForPackage(context.packageName)?.let {
                PendingIntent.getActivity(
                    context,
                    requestCode,
                    it,
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
                )
            }
            am.setAlarmClock(AlarmManager.AlarmClockInfo(triggerAtMillis, show), pi)
        } else {
            am.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, triggerAtMillis, pi)
        }

        val prefs = context.getSharedPreferences(AlarmBuzzService.PREFS, Context.MODE_PRIVATE)
        val entries = prefs.getStringSet(KEY_SCHEDULED, emptySet())!!.toMutableSet()
        entries.removeAll { it.split("|").firstOrNull() == requestCode.toString() }
        entries.add("$requestCode|$alarmId|$triggerAtMillis")
        prefs.edit().putStringSet(KEY_SCHEDULED, entries).apply()
    }

    fun cancelAll(context: Context) {
        val am = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val prefs = context.getSharedPreferences(AlarmBuzzService.PREFS, Context.MODE_PRIVATE)
        for (entry in prefs.getStringSet(KEY_SCHEDULED, emptySet())!!) {
            val requestCode = entry.split("|").firstOrNull()?.toIntOrNull() ?: continue
            val pi = pendingIntent(context, requestCode, -1)
            am.cancel(pi)
            pi.cancel()
        }
        prefs.edit().remove(KEY_SCHEDULED).apply()
    }

    // Called by the boot receiver: re-arm every persisted alarm still in the
    // future, drop the ones that went stale while the phone was off.
    fun rescheduleAll(context: Context) {
        val prefs = context.getSharedPreferences(AlarmBuzzService.PREFS, Context.MODE_PRIVATE)
        val entries = prefs.getStringSet(KEY_SCHEDULED, emptySet())!!.toList()
        prefs.edit().remove(KEY_SCHEDULED).apply()
        val now = System.currentTimeMillis()
        for (entry in entries) {
            val parts = entry.split("|")
            if (parts.size != 3) continue
            val requestCode = parts[0].toIntOrNull() ?: continue
            val alarmId = parts[1].toIntOrNull() ?: continue
            val at = parts[2].toLongOrNull() ?: continue
            if (at > now) schedule(context, requestCode, alarmId, at)
        }
    }

    // Called by AlarmBuzzReceiver once an alarm fires, so a later reboot does
    // not resurrect it.
    fun markFired(context: Context, requestCode: Int) {
        val prefs = context.getSharedPreferences(AlarmBuzzService.PREFS, Context.MODE_PRIVATE)
        val entries = prefs.getStringSet(KEY_SCHEDULED, emptySet())!!.toMutableSet()
        if (entries.removeAll { it.split("|").firstOrNull() == requestCode.toString() }) {
            prefs.edit().putStringSet(KEY_SCHEDULED, entries).apply()
        }
    }

    private fun pendingIntent(context: Context, requestCode: Int, alarmId: Int): PendingIntent {
        val intent = Intent(context, AlarmBuzzReceiver::class.java)
            .putExtra(AlarmBuzzReceiver.EXTRA_REQUEST_CODE, requestCode)
            .putExtra(AlarmBuzzService.EXTRA_ALARM_ID, alarmId)
        return PendingIntent.getBroadcast(
            context,
            requestCode,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
    }
}
