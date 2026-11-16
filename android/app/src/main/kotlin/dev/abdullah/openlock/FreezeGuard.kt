package dev.abdullah.openlock

/**
 * Recognises XOS Freezer actions targeting OpenLock.
 *
 * XOS does not expose a literal "Freeze" button in the observed flow. It
 * opens an app picker ("Pilih aplikasi (n/68)"), lets the user select
 * OpenLock, then freezes the selection when "Oke" is tapped. Match that
 * complete picker signature rather than relying only on a Freeze label.
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

        val normalized = texts.map {
            it.lowercase().replace(Regex("\\s+"), " ").trim()
        }

        val explicitFreezeAction = normalized.any { text ->
            text in freezeLabels ||
                text.contains("add to freezer") ||
                text.contains("bekukan aplikasi")
        }
        if (explicitFreezeAction) return true

        // Observed Infinix/XOS flow: + -> "Pilih aplikasi (n/68)" ->
        // select OpenLock -> "Batal" / "Oke". The confirmation commits
        // the freeze immediately, so block the picker before "Oke".
        val appPicker = normalized.any { text ->
            text.startsWith("pilih aplikasi") || text.startsWith("select apps")
        }
        val confirm = normalized.any { it == "oke" || it == "ok" || it == "done" }
        val cancel = normalized.any { it == "batal" || it == "cancel" }
        return appPicker && confirm && cancel
    }
}
