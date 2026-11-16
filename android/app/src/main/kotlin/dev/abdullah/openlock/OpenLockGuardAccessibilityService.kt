package dev.abdullah.openlock

import android.accessibilityservice.AccessibilityService
import android.content.Intent
import android.os.SystemClock
import android.view.accessibility.AccessibilityEvent
import android.view.accessibility.AccessibilityNodeInfo

/**
 * Independent enforcement path for Strict Mode. Android binds this service
 * through Accessibility even when the OpenLock launcher task is absent from
 * Recents or the foreground monitor service has been stopped.
 *
 * It also recognises Settings / installer screens that refer specifically to
 * OpenLock, so Strict Mode can guard App info and Device Administrator pages.
 * Window contents are inspected in memory only.
 */
class OpenLockGuardAccessibilityService : AccessibilityService() {

    private var windowPackage: String? = null
    private var windowClass: String? = null
    private var lastBarrierKey: String? = null
    private var lastBarrierAt = 0L
    private lateinit var store: ConfigStore

    override fun onServiceConnected() {
        super.onServiceConnected()
        store = ConfigStore.get(this)
    }

    override fun onAccessibilityEvent(event: AccessibilityEvent) {
        val type = event.eventType
        val eventPkg = event.packageName?.toString()

        if (type == AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED) {
            windowPackage = eventPkg
            windowClass = event.className?.toString()

            // Second enforcement path: do not depend on UsageStats polling or
            // the launcher task remaining alive. Only act on window changes,
            // not content changes, to avoid repeatedly opening the barrier.
            if (eventPkg != null && eventPkg != packageName &&
                store.strictModeActive() &&
                store.strictModePackages().contains(eventPkg)
            ) {
                showStrictBarrier(eventPkg, eventPkg)
                return
            }
        } else if (type != AccessibilityEvent.TYPE_WINDOW_CONTENT_CHANGED) {
            return
        }

        if (type == AccessibilityEvent.TYPE_WINDOW_CONTENT_CHANGED &&
            (eventPkg == null || !UninstallGuard.isCandidatePackage(eventPkg))
        ) {
            return
        }

        val root = rootInActiveWindow
        val rootPkg = root?.packageName?.toString()
        if (root == null || rootPkg == null ||
            !UninstallGuard.isCandidatePackage(rootPkg)
        ) {
            GuardedScreen.clear()
            if (type == AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED &&
                rootPkg != packageName
            ) {
                lastBarrierKey = null
            }
            return
        }

        val aboutOpenLock = UninstallGuard.isAboutOwnApp(
            windowPackage = rootPkg,
            windowClass = if (windowPackage == rootPkg) windowClass else null,
            nodes = flatten(root),
            ownLabel = applicationInfo.loadLabel(packageManager).toString(),
            ownPackage = packageName,
        )

        if (aboutOpenLock) {
            GuardedScreen.set(rootPkg)
            // Strict Mode guards our own App info and the Device Admin
            // deactivate screen, not merely the apps selected in the blocklist.
            if (store.strictModeActive()) {
                showStrictBarrier(rootPkg, packageName)
            }
        } else {
            GuardedScreen.clear()
        }
    }

    private fun showStrictBarrier(key: String, displayedPackage: String) {
        val now = SystemClock.elapsedRealtime()
        if (key == lastBarrierKey && now - lastBarrierAt < RELAUNCH_GUARD_MS) return
        lastBarrierKey = key
        lastBarrierAt = now

        val intent = Intent(this, StrictModeActivity::class.java).apply {
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            addFlags(Intent.FLAG_ACTIVITY_NO_ANIMATION)
            addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP)
            putExtra(StrictModeActivity.EXTRA_PACKAGE, displayedPackage)
        }
        runCatching { startActivity(intent) }
    }

    override fun onInterrupt() = Unit

    override fun onDestroy() {
        GuardedScreen.clear()
        super.onDestroy()
    }

    private fun flatten(root: AccessibilityNodeInfo): List<ScreenNode> {
        val out = ArrayList<ScreenNode>()
        val stack = ArrayDeque<AccessibilityNodeInfo>()
        stack.addLast(root)
        while (stack.isNotEmpty() && out.size < MAX_NODES) {
            val node = stack.removeLast()
            val text = node.text?.toString() ?: node.contentDescription?.toString()
            out.add(ScreenNode(node.viewIdResourceName, text))
            for (i in node.childCount - 1 downTo 0) {
                node.getChild(i)?.let { stack.addLast(it) }
            }
        }
        return out
    }

    private companion object {
        const val MAX_NODES = 600
        const val RELAUNCH_GUARD_MS = 1_200L
    }
}

/**
 * The candidate window (Settings / package installer) currently showing a
 * screen about OpenLock, as last seen by [OpenLockGuardAccessibilityService].
 */
object GuardedScreen {
    @Volatile private var pkg: String? = null

    fun set(windowPackage: String) {
        pkg = windowPackage
    }

    fun clear() {
        pkg = null
    }

    fun isShowing(windowPackage: String): Boolean = pkg == windowPackage
}
