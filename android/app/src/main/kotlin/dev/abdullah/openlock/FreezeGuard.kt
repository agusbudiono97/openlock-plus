package dev.abdullah.openlock

/**
 * Best-effort recognition of an OEM app-freezer action targeting OpenLock.
 * A match requires OpenLock's exact label/package AND an explicit freeze
 * action in the same accessibility window.
 */
object FreezeGuard {
    private val freezeLabels = setOf(
        "bekukan", "bekukan aplikasi", "bekukan app",
        "freeze", "freeze app", "freeze application",
        "add to freezer", "add to freeze list", "deep freeze",
    )

    fun isFreezeActionForOwnApp(
        nodes: List<ScreenNode>,
        ownLabel: String,
        ownPackage: String,
    ): Boolean {
        val texts = nodes.mapNotNull { it.text?.trim()?.takeIf(String::isNotEmpty) }
        val namesOpenLock = texts.any { text ->
            text == ownPackage || text.equals(ownLabel, ignoreCase = true)
        }
        if (!namesOpenLock) return false

        return texts.any { text ->
            val normalized = text.lowercase().replace(Regex("\\s+"), " ")
            normalized in freezeLabels ||
                normalized.contains("add to freezer") ||
                normalized.contains("bekukan aplikasi")
        }
    }
}
