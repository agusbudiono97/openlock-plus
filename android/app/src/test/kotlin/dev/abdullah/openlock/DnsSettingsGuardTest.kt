package dev.abdullah.openlock

import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class DnsSettingsGuardTest {
    @Test
    fun blocksOnlyOpenedPrivateDnsModeScreen() {
        assertTrue(
            DnsSettingsGuard.isPrivateDnsScreen(
                "com.android.settings",
                listOf(
                    ScreenNode("settings:id/title", "DNS Pribadi"),
                    ScreenNode("settings:id/summary", "Otomatis"),
                    ScreenNode("settings:id/radio", "Nonaktif"),
                ),
            ),
        )
        assertTrue(
            DnsSettingsGuard.isPrivateDnsScreen(
                "com.android.settings",
                listOf(
                    ScreenNode("settings:id/title", "Private DNS"),
                    ScreenNode("settings:id/title", "Private DNS provider hostname"),
                ),
            ),
        )
    }

    @Test
    fun doesNotBlockParentConnectivityScreenContainingPrivateDnsRow() {
        assertFalse(
            DnsSettingsGuard.isPrivateDnsScreen(
                "com.android.settings",
                listOf(
                    ScreenNode("settings:id/title", "Koneksi Multi Perangkat"),
                    ScreenNode("settings:id/title", "DNS Pribadi"),
                    ScreenNode("settings:id/summary", "7m1.example-dns.com"),
                    ScreenNode("settings:id/title", "VPN"),
                ),
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
                    ScreenNode("settings:id/title", "OpenLock protection service"),
                    ScreenNode("settings:id/switch_widget", "Gunakan OpenLock protection service", isChecked = true),
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
