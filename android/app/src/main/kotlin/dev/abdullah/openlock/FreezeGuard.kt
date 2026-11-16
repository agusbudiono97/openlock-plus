package dev.abdullah.openlock

/**
 * Recognises XOS Freezer actions targeting OpenLock without blocking the
 * Freezer's general app picker. In the XOS picker, OpenLock is visible even
 * when it is NOT selected, so the picker signature alone is insufficient.
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
        val ownIdentityNodes = nodes.filter { node ->
            val text = node.text?.trim() ?: return@filter false
            text == ownPackage || text.equals(ownLabel, ignoreCase = true)
        }
        if (ownIdentityNodes.isEmpty()) return false

        val normalized = texts.map {
            it.lowercase().replace(Regex("\\s+"), " ").trim()
        }

        // Explicit single-app freeze screens are safe to match when the
        // current window names OpenLock and exposes a freeze action.
        val explicitFreezeAction = normalized.any { text ->
            text in freezeLabels ||
                text.contains("add to freezer") ||
                text.contains("bekukan aplikasi")
        }
        if (explicitFreezeAction) return true

        // XOS flow: "Pilih aplikasi (n/68)" + app tiles + Batal/Oke.
        // OpenLock is always present in this list, so only block when its own
        // accessibility node (or a selected row/container) reports selected.
        val appPicker = normalized.any { text ->
            text.startsWith("pilih aplikasi") || text.startsWith("select apps")
        }
        val confirm = normalized.any { it == "oke" || it == "ok" || it == "done" }
        val cancel = normalized.any { it == "batal" || it == "cancel" }
        val ownAppSelected = ownIdentityNodes.any { node ->
            node.isChecked || node.isSelected || node.insideSelectedContainer
        }
        return appPicker && confirm && cancel && ownAppSelected
    }
}
