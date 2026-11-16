package dev.abdullah.openlock

/**
 * Recognises the XOS/Android "running apps" panel when it exposes a Stop
 * action for OpenLock. Detection is intentionally based on the same window
 * containing both OpenLock's identity and an explicit stop control.
 */
object RunningAppStopGuard {
    private val stopLabels = setOf(
        "berhenti",
        "stop",
        "force stop",
        "paksa berhenti",
    )

    fun isStopActionForOwnApp(
        nodes: List<ScreenNode>,
        ownLabel: String,
        ownPackage: String,
    ): Boolean {
        val texts = nodes.mapNotNull { it.text?.trim()?.takeIf(String::isNotEmpty) }
        val namesOpenLock = texts.any { text ->
            text == ownPackage || text.equals(ownLabel, ignoreCase = true) ||
                containsWholeLabel(text, ownLabel)
        }
        if (!namesOpenLock) return false

        return texts.any { text ->
            val normalized = text.lowercase().replace(Regex("\\s+"), " ")
            normalized in stopLabels ||
                normalized.contains("force stop") ||
                normalized.contains("paksa berhenti")
        }
    }

    private fun containsWholeLabel(text: String, label: String): Boolean {
        if (label.isBlank()) return false
        val escaped = Regex.escape(label.trim())
        return Regex("(^|[^\\p{L}\\p{N}])$escaped([^\\p{L}\\p{N}]|$)", RegexOption.IGNORE_CASE)
            .containsMatchIn(text)
    }
}
