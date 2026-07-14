package io.github.notwewnothing.mfaaa

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

// AlarmManager alarms do not survive a reboot; rebuild the native vibration
// alarms from the persisted schedule. (flutter_local_notifications restores
// its own notifications through its own boot receiver.)
class AlarmBuzzBootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        when (intent.action) {
            Intent.ACTION_BOOT_COMPLETED,
            Intent.ACTION_MY_PACKAGE_REPLACED,
            "android.intent.action.QUICKBOOT_POWERON",
            "com.htc.intent.action.QUICKBOOT_POWERON",
            -> AlarmBuzzScheduler.rescheduleAll(context)
        }
    }
}
