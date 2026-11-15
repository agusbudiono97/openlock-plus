package dev.abdullah.openlock

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.app.usage.UsageEvents
import android.app.usage.UsageStatsManager
import android.app.AppOpsManager
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.os.Process
import android.provider.Settings
import java.util.Calendar
import java.util.concurrent.ConcurrentHashMap

/**
 * Persistent foreground service that detects the current foreground app via
 * [UsageStatsManager] and throws up [LockActivity] over any locked app that is
 * not currently in an unlocked session (per relock policy + schedules).
 */
class OpenLockMonitorService : Service() {

    private lateinit var store: ConfigStore
    private lateinit var usageStatsManager: UsageStatsManager
    private val handler = Handler(Looper.getMainLooper())

    private val leftAppAt = ConcurrentHashMap<String, Long>()
    @Volatile private var screenOffAt: Long = 0L
    private var lastForegroundPkg: String? = null
    private var lastLaunchedPkg: String? = null
    private var lastLaunchAt: Long = 0L
    private var lastStrictLaunchedPkg: String? = null
    private var lastStrictLaunchAt: Long = 0L
    @Volatile private var observedForegroundPkg: String? = null
    private var lastNotificationAccessState: String? = null

    private val screenReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context?, intent: Intent?) {
            when (intent?.action) {
                Intent.ACTION_SCREEN_OFF -> {
                    screenOffAt = System.currentTimeMillis()
                    observedForegroundPkg = null
                    lastForegroundPkg = null
                    lastStrictLaunchedPkg = null
                    lastLaunchedPkg = null
                }
            }
        }
    }

    private val poller = object : Runnable {
        override fun run() {
            try {
                tick()
            } catch (_: Exception) {
                // Never let a transient failure kill the loop.
            }
            handler.postDelayed(this, POLL_INTERVAL_MS)
        }
    }

    override fun onCreate() {
        super.onCreate()
        store = ConfigStore.get(this)
        usageStatsManager = getSystemService(Context.USAGE_STATS_SERVICE) as UsageStatsManager
        registerReceiver(screenReceiver, IntentFilter(Intent.ACTION_SCREEN_OFF))
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        startForeground(NOTIFICATION_ID, buildNotification())
        isRunning = true
        handler.removeCallbacks(poller)
        handler.post(poller)
        return START_STICKY
    }

    override fun onDestroy() {
        isRunning = false
        handler.removeCallbacks(poller)
        runCatching { unregisterReceiver(screenReceiver) }
        super.onDestroy()
    }

    override fun onBind(intent: Intent?): IBinder? = null

    private fun tick() {
        refreshNotificationIfNeeded()
        val current = foregroundApp() ?: return
        val now = System.currentTimeMillis()

        // Track departures from the foreground for the relock policy.
        val previous = lastForegroundPkg
        if (previous != null && previous != current) {
            leftAppAt[previous] = now
        }
        lastForegroundPkg = current

        // Once the user is in an app, its hidden-notification backlog is stale —
        // clear OpenLock's redacted notice for it. (No-op when the listener is
        // off or nothing was hidden.)
        OpenLockNotificationListenerService.onAppForegrounded(current)

        // Never lock ourselves.
        if (current == packageName) return

        // Strict Mode is a hard block, separate from the normal PIN app-lock.
        // It is active until its wall-clock deadline; a null deadline means
        // indefinite. The activity itself only displays the block/countdown.
        if (store.strictModeActive() && store.strictModePackages().contains(current)) {
            if (current == lastStrictLaunchedPkg &&
                now - lastStrictLaunchAt < RELAUNCH_GUARD_MS
            ) return
            lastStrictLaunchedPkg = current
            lastStrictLaunchAt = now
            launchStrictMode(current)
            return
        }

        // Clear the strict-mode debounce when the user leaves the blocked app.
        lastStrictLaunchedPkg = null

        // Uninstall protection: guard the OS screens about OpenLock itself
        // (App info, uninstall dialog, device-admin deactivation), as read by
        // OpenLockGuardAccessibilityService. Runs before the normal locked-app
        // check because Settings is not in the locked set.
        val strictActive = store.strictModeActive()
        val uninstallGuardEnabled =
            strictActive || (store.pinHash() != null && store.preventUninstall())
        if (uninstallGuardEnabled && GuardedScreen.isShowing(current)) {
            // During Strict Mode there is no early-unlock path: show the
            // non-dismissible Strict Mode barrier even when no ordinary PIN
            // has ever been configured. Outside Strict Mode, retain the
            // existing PIN-authenticated device-admin flow.
            if (strictActive) {
                if (current != lastLaunchedPkg ||
                    now - lastLaunchAt >= RELAUNCH_GUARD_MS
                ) {
                    lastLaunchedPkg = current
                    lastLaunchAt = now
                    launchStrictMode(current)
                }
            } else {
                val unlockedAt = LockSession.unlockedAt(current)
                val stillUnlocked = unlockedAt != 0L && screenOffAt <= unlockedAt
                if (!stillUnlocked &&
                    !(current == lastLaunchedPkg && now - lastLaunchAt < RELAUNCH_GUARD_MS)
                ) {
                    lastLaunchedPkg = current
                    lastLaunchAt = now
                    launchLock(current)
                }
            }
            return
        }

        val locked = HashSet(store.lockedPackages())
        locked.addAll(LockLogic.scheduledLockedPackages(store.schedules(), Calendar.getInstance()))
        if (!locked.contains(current)) return

        // No PIN configured yet → nothing to enforce.
        if (store.pinHash() == null) return

        val shouldLock = LockLogic.isLocked(
            mode = store.relockMode(),
            timeoutMinutes = store.relockTimeoutMinutes(),
            unlockedAt = LockSession.unlockedAt(current),
            leftAppAt = leftAppAt[current] ?: 0L,
            screenOffAt = screenOffAt,
            now = now,
        )
        if (!shouldLock) return

        // Debounce so we don't stack multiple lock screens for the same app.
        if (current == lastLaunchedPkg && now - lastLaunchAt < RELAUNCH_GUARD_MS) return
        lastLaunchedPkg = current
        lastLaunchAt = now
        launchLock(current)
    }

    private fun launchStrictMode(packageName: String) {
        val intent = Intent(this, StrictModeActivity::class.java).apply {
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            addFlags(Intent.FLAG_ACTIVITY_NO_ANIMATION)
            putExtra(StrictModeActivity.EXTRA_PACKAGE, packageName)
        }
        runCatching { startActivity(intent) }
    }

    private fun launchLock(packageName: String) {
        val intent = Intent(this, LockActivity::class.java).apply {
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            addFlags(Intent.FLAG_ACTIVITY_NO_ANIMATION)
            putExtra(LockActivity.EXTRA_PACKAGE, packageName)
        }
        runCatching { startActivity(intent) }
    }

    /** The latest foreground package. */
    private fun foregroundApp(): String? {
        val end = System.currentTimeMillis()
        val begin = end - LOOKBACK_MS
        val events = usageStatsManager.queryEvents(begin, end)
        val event = UsageEvents.Event()
        while (events.hasNextEvent()) {
            events.getNextEvent(event)
            // Ignore history from before the display was turned off. Otherwise
            // a poll immediately after screen-off could resurrect the last
            // app from the lookback window and show a block over the lockscreen.
            if (event.timeStamp <= screenOffAt) continue

            // Android 10+ reports ACTIVITY_RESUMED; older releases report
            // MOVE_TO_FOREGROUND. Keep the latest observed package between
            // polls: the foreground event is emitted once on app launch, not
            // continuously, so returning null after LOOKBACK_MS would silently
            // stop enforcing an app that stays open.
            val entersForeground =
                event.eventType == UsageEvents.Event.MOVE_TO_FOREGROUND ||
                    (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q &&
                        event.eventType == UsageEvents.Event.ACTIVITY_RESUMED)
            val leavesForeground =
                event.eventType == UsageEvents.Event.MOVE_TO_BACKGROUND ||
                    (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q &&
                        event.eventType == UsageEvents.Event.ACTIVITY_PAUSED)

            if (entersForeground) {
                observedForegroundPkg = event.packageName
            } else if (leavesForeground && observedForegroundPkg == event.packageName) {
                // Clear only the package that actually left. A later resumed
                // event in the same query window will set the new foreground.
                observedForegroundPkg = null
            }
        }
        return observedForegroundPkg
    }

    /**
     * Detect permissions that are essential for foreground-app enforcement.
     * Android can revoke these while Strict Mode is active; the persistent
     * notification must not continue claiming protection is healthy.
     */
    private fun missingEnforcementAccess(): String {
        val missing = ArrayList<String>(2)
        val usageAllowed = runCatching {
            val appOps = getSystemService(Context.APP_OPS_SERVICE) as AppOpsManager
            val mode = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                appOps.unsafeCheckOpNoThrow(
                    AppOpsManager.OPSTR_GET_USAGE_STATS,
                    Process.myUid(),
                    packageName,
                )
            } else {
                @Suppress("DEPRECATION")
                appOps.checkOpNoThrow(
                    AppOpsManager.OPSTR_GET_USAGE_STATS,
                    Process.myUid(),
                    packageName,
                )
            }
            mode == AppOpsManager.MODE_ALLOWED
        }.getOrDefault(false)
        if (!usageAllowed) missing.add("Akses penggunaan")
        if (!Settings.canDrawOverlays(this)) missing.add("Tampil di atas aplikasi lain")
        return missing.joinToString(" dan ")
    }

    private fun refreshNotificationIfNeeded() {
        val missing = missingEnforcementAccess()
        if (missing == lastNotificationAccessState) return
        val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        manager.notify(NOTIFICATION_ID, buildNotification())
    }

    private fun buildNotification(): Notification {
        val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "App lock protection",
                NotificationManager.IMPORTANCE_LOW,
            ).apply {
                description = "Shown while OpenLock is guarding your apps."
                setShowBadge(false)
            }
            manager.createNotificationChannel(channel)
        }

        val openIntent = packageManager.getLaunchIntentForPackage(packageName)
        val pending = openIntent?.let {
            PendingIntent.getActivity(
                this,
                0,
                it,
                PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
            )
        }

        val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(this, CHANNEL_ID)
        } else {
            @Suppress("DEPRECATION")
            Notification.Builder(this)
        }
        val missingAccess = missingEnforcementAccess()
        lastNotificationAccessState = missingAccess
        val contentText = if (missingAccess.isEmpty()) {
            "Mode Ketat dan aplikasi terkunci sedang dipantau."
        } else {
            "Perlindungan perlu dipulihkan: $missingAccess"
        }
        val contentTitle = if (missingAccess.isEmpty()) {
            "OpenLock sedang melindungi aplikasi"
        } else {
            "Perlindungan OpenLock perlu perhatian"
        }

        return builder
            .setContentTitle(contentTitle)
            .setContentText(contentText)
            .setSmallIcon(android.R.drawable.ic_lock_lock)
            .setOngoing(true)
            .setContentIntent(pending)
            .build()
    }

    companion object {
        @Volatile
        var isRunning: Boolean = false
            private set

        private const val CHANNEL_ID = "openlock_monitor"
        private const val NOTIFICATION_ID = 4711
        private const val POLL_INTERVAL_MS = 300L
        private const val LOOKBACK_MS = 10_000L
        private const val RELAUNCH_GUARD_MS = 1_500L
    }
}
