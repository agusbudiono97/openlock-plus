package dev.abdullah.openlock

import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class BootReceiverTest {
    @Test fun restoresMonitorForStrictModeWithoutPin() {
        assertTrue(shouldRestoreMonitor(hasStrictModeWork = true, hasPinProtectedWork = false))
    }

    @Test fun restoresMonitorForPinProtectedAppsOrSchedules() {
        assertTrue(shouldRestoreMonitor(hasStrictModeWork = false, hasPinProtectedWork = true))
    }

    @Test fun skipsRestoreWhenThereIsNoProtectedWork() {
        assertFalse(shouldRestoreMonitor(hasStrictModeWork = false, hasPinProtectedWork = false))
    }

    @Test fun restoresMonitorWhenBothProtectionModesNeedIt() {
        assertTrue(shouldRestoreMonitor(hasStrictModeWork = true, hasPinProtectedWork = true))
    }
}
