package dev.abdullah.openlock

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class StrictModeClockTest {
    @Test fun sameBootUsesMonotonicDeadlineDespiteWallClockChanges() {
        assertTrue(StrictModeClock.isActive(true, 2000L, 20000L, 7, 500L, 19000L, 7))
    }

    @Test fun sameBootExpiresEvenIfWallClockMovesBackward() {
        assertFalse(StrictModeClock.isActive(true, 2000L, 20000L, 7, 500L, 20001L, 7))
    }

    @Test fun afterRebootFallsBackToWallDeadline() {
        assertTrue(StrictModeClock.isActive(true, 2000L, 20000L, 7, 1999L, 100L, 8))
        assertFalse(StrictModeClock.isActive(true, 2000L, 20000L, 7, 2001L, 100L, 8))
    }

    @Test fun indefiniteModeStaysActive() {
        assertTrue(StrictModeClock.isActive(true, 0L, 0L, 7, 9999L, 9999L, 7))
    }

    @Test fun disabledModeIsInactive() {
        assertFalse(StrictModeClock.isActive(false, 0L, 0L, 7, 1L, 1L, 7))
    }

    @Test fun elapsedDeadlineUsesRemainingWallDuration() {
        assertEquals(15000L, StrictModeClock.elapsedDeadline(20000L, 10000L, 5000L))
        assertNull(StrictModeClock.elapsedDeadline(0L, 10000L, 5000L))
    }
    @Test fun remainingTimeUsesMonotonicClockDuringSameBoot() {
        assertEquals(1000L, StrictModeClock.remainingMillis(true, 2000L, 20000L, 7, 500L, 19000L, 7))
        assertEquals(0L, StrictModeClock.remainingMillis(true, 2000L, 20000L, 7, 500L, 20001L, 7))
    }

    @Test fun remainingTimeUsesWallClockAfterReboot() {
        assertEquals(1L, StrictModeClock.remainingMillis(true, 2000L, 20000L, 7, 1999L, 100L, 8))
        assertEquals(0L, StrictModeClock.remainingMillis(true, 2000L, 20000L, 7, 2001L, 100L, 8))
    }

    @Test fun remainingTimeReturnsNullForIndefiniteAndZeroWhenDisabled() {
        assertNull(StrictModeClock.remainingMillis(true, 0L, 0L, 7, 9999L, 9999L, 7))
        assertEquals(0L, StrictModeClock.remainingMillis(false, 0L, 0L, 7, 1L, 1L, 7))
    }

}