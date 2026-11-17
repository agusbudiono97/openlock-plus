package dev.abdullah.openlock

/**
 * Best-effort detector for Android Settings screens that expose the Private
 * DNS control. It deliberately requires the system Settings package and
 * explicit Private DNS wording; generic network settings remain untouched.
 */
internal object DnsSettingsGuard {
    private val settingsPackages = setOf(
        "com.android.settings",
        "com.android.settings.intelligence",
        "com.google.android.settings.intelligence",
    )

    private val privateDnsLabels = setOf(
        "dns pribadi",
        "private dns",
        "nama host penyedia dns pribadi",
        "private dns provider hostname",
        "pilih mode dns pribadi",
        "private dns mode",
    )

    fun isOpenLockAccessibilitySettings(
        packageName: String,
        nodes: List<ScreenNode>,
        ownLabel: String,
    ): Boolean {
        if (packageName !in settingsPackages) return false
        val texts = nodes.mapNotNull { it.text }.map { it.trim().lowercase() }
        val mentionsOpenLock = texts.any { it == ownLabel.lowercase() }
        val mentionsAccessibility = texts.any {
            it.contains("aksesibilitas") || it.contains("accessibility")
        }
        val hasServiceSwitch = nodes.any {
            it.isChecked || it.viewId?.contains("switch", ignoreCase = true) == true
        }
        return mentionsOpenLock && mentionsAccessibility && hasServiceSwitch
    }

    fun isPrivateDnsScreen(packageName: String, nodes: List<ScreenNode>): Boolean {
        if (packageName !in settingsPackages) return false
        val visibleText = nodes.mapNotNull { it.text }
            .map { it.trim().lowercase() }
            .filter { it.isNotEmpty() }
        if (visibleText.isEmpty()) return false

        // A result row or the dedicated settings page must explicitly identify
        // Private DNS. Do not match ordinary Wi-Fi, VPN, or general DNS text.
        return visibleText.any { text ->
            text in privateDnsLabels ||
                text.startsWith("dns pribadi ") ||
                text.startsWith("private dns ") ||
                text.contains("nama host penyedia dns pribadi") ||
                text.contains("private dns provider hostname")
        }
    }
}
