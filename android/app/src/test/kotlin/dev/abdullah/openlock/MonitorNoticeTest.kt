package dev.abdullah.openlock

import org.junit.Assert.assertEquals
import org.junit.Test

class MonitorNoticeTest {
    @Test fun missingPermissionsTakePriorityOverMonitorFault() {
        assertEquals(
            "Perlindungan OpenLock perlu perhatian" to "Pulihkan akses berikut: Akses penggunaan",
            monitorNotice("Akses penggunaan", true),
        )
    }

    @Test fun pollingFailureIsNotReportedAsHealthyProtection() {
        assertEquals(
            "Pemantauan OpenLock terganggu" to
                "Pemantauan aplikasi mengalami gangguan. Buka OpenLock untuk memeriksa perlindungan.",
            monitorNotice("", true),
        )
    }

    @Test fun healthyMonitorKeepsNormalNotice() {
        assertEquals(
            "OpenLock sedang melindungi aplikasi" to
                "Mode Ketat dan aplikasi terkunci sedang dipantau.",
            monitorNotice("", false),
        )
    }
}
