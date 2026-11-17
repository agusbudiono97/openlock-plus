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
        val label = ownLabel.trim().lowercase()
        val mentionsOpenLockService = texts.any { text ->
            (label.isNotEmpty() && text.contains(label)) ||
                text.contains("openlock protection service") ||
                text.contains("layanan perlindungan openlock")
        }
        val identifiesServiceDetail = texts.any { text ->
            text.contains("protection service") ||
                text.contains("layanan perlindungan") ||
                text.contains("accessibility service") ||
                text.contains("layanan aksesibilitas") ||
                text.startsWith("gunakan openlock")
        }
        // The switch may be OFF, so do not depend on isChecked. Its resource
        // id remains available on XOS even when the control is unchecked.
        val hasServiceSwitch = nodes.any {
            it.viewId?.contains("switch", ignoreCase = true) == true ||
                it.viewId?.contains("toggle", ignoreCase = true) == true
        }
        return mentionsOpenLockService && identifiesServiceDetail && hasServiceSwitch
    }

    fun isPrivateDnsScreen(packageName: String, nodes: List<ScreenNode>): Boolean {
        if (packageName !in settingsPackages) return false
        val visibleText = nodes.mapNotNull { it.text }
            .map { it.trim().lowercase() }
            .filter { it.isNotEmpty() }
        if (visibleText.isEmpty()) return false

        val namesPrivateDns = visibleText.any { text ->
            text in privateDnsLabels ||
                text.startsWith("dns pribadi ") ||
                text.startsWith("private dns ") ||
                text.contains("nama host penyedia dns pribadi") ||
                text.contains("private dns provider hostname")
        }
        if (!namesPrivateDns) return false

        // Do not block the parent "Koneksi Multi Perangkat" screen merely
        // because its list contains a "DNS Pribadi" row. Only block after that
        // row has been opened and the mode choices / provider-hostname editor
        // are actually visible.
        val detailMarkers = setOf(
            "nonaktif",
            "otomatis",
            "nama host penyedia dns pribadi",
            "private dns provider hostname",
            "pilih mode dns pribadi",
            "private dns mode",
            "off",
            "automatic",
        )
        return visibleText.any { text ->
            text in detailMarkers ||
                text.contains("nama host penyedia dns pribadi") ||
                text.contains("private dns provider hostname")
        }
    }
}
