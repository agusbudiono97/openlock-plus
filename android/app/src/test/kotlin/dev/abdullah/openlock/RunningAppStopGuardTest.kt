package dev.abdullah.openlock

import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class RunningAppStopGuardTest {
    private val label = "OpenLock"
    private val pkg = "dev.abdullah.openlock"

    @Test
    fun detectsIndonesianRunningAppStopButton() {
        assertTrue(
            RunningAppStopGuard.isStopActionForOwnApp(
                listOf(
                    ScreenNode(null, "Aplikasi yang Sedang Berjalan"),
                    ScreenNode("id/app_name", "OpenLock"),
                    ScreenNode("id/stop", "Berhenti"),
                ),
                label,
                pkg,
            ),
        )
    }

    @Test
    fun detectsEnglishForceStopButton() {
        assertTrue(
            RunningAppStopGuard.isStopActionForOwnApp(
                listOf(
                    ScreenNode(null, "OpenLock"),
                    ScreenNode(null, "Force stop"),
                ),
                label,
                pkg,
            ),
        )
    }

    @Test
    fun doesNotMatchOtherAppsOrGenericStopActions() {
        assertFalse(
            RunningAppStopGuard.isStopActionForOwnApp(
                listOf(ScreenNode(null, "Chrome"), ScreenNode(null, "Berhenti")),
                label,
                pkg,
            ),
        )
        assertFalse(
            RunningAppStopGuard.isStopActionForOwnApp(
                listOf(ScreenNode(null, "OpenLock Pro"), ScreenNode(null, "Berhenti")),
                label,
                pkg,
            ),
        )
        assertFalse(
            RunningAppStopGuard.isStopActionForOwnApp(
                listOf(ScreenNode(null, "OpenLock"), ScreenNode(null, "Buka")),
                label,
                pkg,
            ),
        )
    }
}
