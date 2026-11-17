package dev.abdullah.openlock

import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class DnsSettingsGuardTest {
    @Test
    fun blocksPrivateDnsSettingsAndSearchResult() {
        assertTrue(
            DnsSettingsGuard.isPrivateDnsScreen(
                "com.android.settings",
                listOf(ScreenNode("settings:id/title", "DNS Pribadi")),
            ),
        )
        assertTrue(
            DnsSettingsGuard.isPrivateDnsScreen(
                "com.android.settings",
                listOf(ScreenNode("settings:id/title", "Private DNS provider hostname")),
            ),
        )
    }

    @Test
    fun doesNotBlockOtherSettingsOrNonSettingsApps() {
        assertFalse(
            DnsSettingsGuard.isPrivateDnsScreen(
                "com.android.settings",
                listOf(ScreenNode("settings:id/title", "Wi-Fi")),
            ),
        )
        assertFalse(
            DnsSettingsGuard.isPrivateDnsScreen(
                "com.android.systemui",
                listOf(ScreenNode("systemui:id/title", "DNS Pribadi")),
            ),
        )
    }

    @Test
    fun detectsOpenLockAccessibilityServiceSwitch() {
        assertTrue(
            DnsSettingsGuard.isOpenLockAccessibilitySettings(
                "com.android.settings",
                listOf(
                    ScreenNode("settings:id/title", "OpenLock"),
                    ScreenNode("settings:id/switch_widget", "Aksesibilitas", isChecked = true),
                ),
                "OpenLock",
            ),
        )
    }

    @Test
    fun ignoresAccessibilityListWithoutOpenLockSwitch() {
        assertFalse(
            DnsSettingsGuard.isOpenLockAccessibilitySettings(
                "com.android.settings",
                listOf(
                    ScreenNode("settings:id/title", "Aksesibilitas"),
                    ScreenNode("settings:id/title", "TalkBack"),
                    ScreenNode("settings:id/switch_widget", null, isChecked = true),
                ),
                "OpenLock",
            ),
        )
    }
}
