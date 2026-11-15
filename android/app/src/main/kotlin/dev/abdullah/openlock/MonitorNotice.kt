package dev.abdullah.openlock

/** User-facing foreground-monitor health notice. */
internal fun monitorNotice(missingAccess: String, monitorFaulted: Boolean): Pair<String, String> {
    if (missingAccess.isNotEmpty()) {
        return "Perlindungan OpenLock perlu perhatian" to
            "Pulihkan akses berikut: $missingAccess"
    }
    if (monitorFaulted) {
        return "Pemantauan OpenLock terganggu" to
            "Pemantauan aplikasi mengalami gangguan. Buka OpenLock untuk memeriksa perlindungan."
    }
    return "OpenLock sedang melindungi aplikasi" to
        "Mode Ketat dan aplikasi terkunci sedang dipantau."
}
