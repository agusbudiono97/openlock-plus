package dev.abdullah.openlock

import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class FreezeGuardTest {
    private val label = "OpenLock"
    private val pkg = "dev.abdullah.openlock"

    @Test
    fun detectsIndonesianFreezeActionForOpenLock() {
        assertTrue(
            FreezeGuard.isFreezeActionForOwnApp(
                listOf(
                    ScreenNode(null, "Aplikasi"),
                    ScreenNode(null, "OpenLock"),
                    ScreenNode(null, "Bekukan aplikasi"),
                ),
                label,
                pkg,
            ),
        )
    }

    @Test
    fun detectsEnglishFreezerActionForOpenLock() {
        assertTrue(
            FreezeGuard.isFreezeActionForOwnApp(
                listOf(
                    ScreenNode(null, pkg),
                    ScreenNode(null, "Add to freezer"),
                ),
                label,
                pkg,
            ),
        )
    }

    @Test
    fun doesNotMatchOtherAppsOrGenericFreezeControls() {
        assertFalse(
            FreezeGuard.isFreezeActionForOwnApp(
                listOf(ScreenNode(null, "Chrome"), ScreenNode(null, "Bekukan")),
                label,
                pkg,
            ),
        )
        assertFalse(
            FreezeGuard.isFreezeActionForOwnApp(
                listOf(ScreenNode(null, "OpenLock Pro"), ScreenNode(null, "Freeze")),
                label,
                pkg,
            ),
        )
        assertFalse(
            FreezeGuard.isFreezeActionForOwnApp(
                listOf(ScreenNode(null, "OpenLock"), ScreenNode(null, "Buka")),
                label,
                pkg,
            ),
        )
    }
}
