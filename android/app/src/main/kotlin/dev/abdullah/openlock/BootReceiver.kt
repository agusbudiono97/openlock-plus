package dev.abdullah.openlock

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build

/** Restarts the monitor service after a reboot or app update. */
class BootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val action = intent.action
        if (action != Intent.ACTION_BOOT_COMPLETED &&
            action != Intent.ACTION_MY_PACKAGE_REPLACED
        ) {
            return
        }

        val store = ConfigStore.get(context)
        val hasStrictModeWork = store.strictModeActive() &&
            store.strictModePackages().isNotEmpty()
        val hasPinProtectedWork = store.pinHash() != null &&
            (store.lockedPackages().isNotEmpty() || store.schedules().length() > 0)

        // Strict Mode does not depend on a configured PIN. Do not let the
        // normal app-lock PIN gate silently disable Strict Mode after reboot.
        if (!hasStrictModeWork && !hasPinProtectedWork) return

        val serviceIntent = Intent(context, OpenLockMonitorService::class.java)
        runCatching {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(serviceIntent)
            } else {
                context.startService(serviceIntent)
            }
        }
    }
}
