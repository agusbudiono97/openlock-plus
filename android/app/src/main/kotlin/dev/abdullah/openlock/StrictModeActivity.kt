package dev.abdullah.openlock

import android.app.Activity
import android.os.Bundle
import android.os.CountDownTimer
import android.view.Gravity
import android.view.View
import android.view.WindowManager
import android.widget.LinearLayout
import android.widget.TextView

/**
 * Strict Mode notice. The monitor reopens it whenever a selected target
 * returns to foreground. Android Home/Safe Mode/force-stop remain OS-level
 * escape routes for an ordinary application.
 */
class StrictModeActivity : Activity() {
    private var timer: CountDownTimer? = null
    private lateinit var countdown: TextView

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        window.addFlags(
            WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON or
                WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED
        )
        window.decorView.systemUiVisibility = (
            View.SYSTEM_UI_FLAG_FULLSCREEN or
                View.SYSTEM_UI_FLAG_HIDE_NAVIGATION or
                View.SYSTEM_UI_FLAG_IMMERSIVE_STICKY
            )

        val target = intent.getStringExtra(EXTRA_PACKAGE).orEmpty()
        val label = runCatching {
            packageManager.getApplicationLabel(packageManager.getApplicationInfo(target, 0)).toString()
        }.getOrDefault("Aplikasi ini")

        val root = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.CENTER
            setPadding(48, 48, 48, 48)
            setBackgroundColor(0xFF101820.toInt())
        }
        root.addView(TextView(this).apply {
            text = "MODE KETAT AKTIF"
            textSize = 26f
            setTextColor(0xFFFFFFFF.toInt())
            gravity = Gravity.CENTER
        })
        root.addView(TextView(this).apply {
            text = "$label sedang diblokir sampai waktu perlindungan berakhir."
            textSize = 16f
            setTextColor(0xFFCBD5E1.toInt())
            gravity = Gravity.CENTER
            setPadding(0, 24, 0, 24)
        })
        countdown = TextView(this).apply {
            textSize = 22f
            setTextColor(0xFF5EEAD4.toInt())
            gravity = Gravity.CENTER
        }
        root.addView(countdown)
        setContentView(root)
        updateCountdown()
    }

    override fun onResume() {
        super.onResume()
        hideSystemBars()
    }

    override fun onWindowFocusChanged(hasFocus: Boolean) {
        super.onWindowFocusChanged(hasFocus)
        if (hasFocus) hideSystemBars()
    }

    @Suppress("DEPRECATION")
    private fun hideSystemBars() {
        window.decorView.systemUiVisibility = (
            View.SYSTEM_UI_FLAG_FULLSCREEN or
                View.SYSTEM_UI_FLAG_HIDE_NAVIGATION or
                View.SYSTEM_UI_FLAG_IMMERSIVE_STICKY
            )
    }

    private fun updateCountdown() {
        val end = ConfigStore.get(this).strictModeEndMillis()
        if (end <= 0L) {
            countdown.text = "Perlindungan aktif tanpa batas waktu"
            return
        }
        val remaining = end - System.currentTimeMillis()
        if (remaining <= 0L) {
            finish()
            return
        }
        timer = object : CountDownTimer(remaining, 1000L) {
            override fun onTick(millisUntilFinished: Long) {
                val seconds = millisUntilFinished / 1000L
                val days = seconds / 86_400
                val hours = (seconds % 86_400) / 3_600
                val minutes = (seconds % 3_600) / 60
                val secs = seconds % 60
                countdown.text = if (days > 0) {
                    "Sisa waktu: %d hari %02d:%02d:%02d".format(days, hours, minutes, secs)
                } else if (hours > 0) {
                    "Sisa waktu: %02d:%02d:%02d".format(hours, minutes, secs)
                } else {
                    "Sisa waktu: %02d:%02d".format(minutes, secs)
                }
            }
            override fun onFinish() { finish() }
        }.start()
    }

    override fun onDestroy() {
        timer?.cancel()
        super.onDestroy()
    }

    @Deprecated("Deprecated in Android API; overridden to keep the block screen in place")
    override fun onBackPressed() {
        // No in-app dismissal while Strict Mode is active.
    }

    companion object {
        const val EXTRA_PACKAGE = "strict_mode_package"
    }
}
