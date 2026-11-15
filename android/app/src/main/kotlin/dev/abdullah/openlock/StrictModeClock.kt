package dev.abdullah.openlock

/**
 * Deadline evaluation for Strict Mode. Within one Android boot, use the
 * monotonic elapsed-realtime clock so changing the wall clock cannot extend or
 * shorten a commitment. After reboot elapsedRealtime resets, so fall back to
 * the persisted wall-clock deadline. A normal app cannot obtain a trusted
 * cross-reboot clock; this fallback is therefore best-effort.
 */
internal object StrictModeClock {
    fun elapsedDeadline(endWallMillis: Long, nowWallMillis: Long, nowElapsedMillis: Long): Long? {
        if (endWallMillis <= 0L) return null
        return nowElapsedMillis + (endWallMillis - nowWallMillis).coerceAtLeast(0L)
    }

    fun isActive(
        enabled: Boolean,
        endWallMillis: Long,
        endElapsedMillis: Long,
        savedBootCount: Int,
        nowWallMillis: Long,
        nowElapsedMillis: Long,
        currentBootCount: Int,
    ): Boolean {
        if (!enabled) return false
        if (endWallMillis == 0L) return true
        if (savedBootCount >= 0 && currentBootCount >= 0 &&
            savedBootCount == currentBootCount && endElapsedMillis > 0L
        ) {
            return nowElapsedMillis < endElapsedMillis
        }
        return nowWallMillis < endWallMillis
    }
}