package dev.abdullah.openlock

import android.app.Activity
import android.content.Intent
import android.graphics.Typeface
import android.graphics.drawable.GradientDrawable
import android.os.Bundle
import android.os.CountDownTimer
import android.view.Gravity
import android.view.View
import android.view.WindowManager
import android.widget.ImageView
import android.widget.LinearLayout
import android.widget.TextView

/**
 * Full-screen Strict Mode barrier. It intentionally has no dismiss or unlock
 * action: the monitor reopens it whenever a selected app returns to foreground.
 * Android Home/Safe Mode/force-stop remain OS-level escape routes for ordinary apps.
 */
class StrictModeActivity : Activity() {
    private var timer: CountDownTimer? = null
    private lateinit var countdown: TextView
    private lateinit var targetMessage: TextView

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        window.addFlags(
            WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON or
                WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED
        )
        hideSystemBars()

        val background = 0xFF0B1220.toInt()
        val muted = 0xFFB8C4D6.toInt()
        val accent = 0xFF72E4C2.toInt()
        val root = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.CENTER
            setPadding(dp(28), dp(36), dp(28), dp(36))
            setBackgroundColor(background)
        }

        val brand = TextView(this).apply {
            text = "OPENLOCK"
            textSize = 13f
            letterSpacing = 0.22f
            setTextColor(muted)
            typeface = Typeface.create("sans-serif-medium", Typeface.NORMAL)
            gravity = Gravity.CENTER
        }
        root.addView(brand, centeredParams())

        val emblem = ImageView(this).apply {
            setImageResource(android.R.drawable.ic_lock_lock)
            setColorFilter(background)
            scaleType = ImageView.ScaleType.CENTER_INSIDE
            background = rounded(accent, 28)
            setPadding(dp(28), dp(24), dp(28), dp(24))
        }
        val emblemWrap = LinearLayout(this).apply {
            gravity = Gravity.CENTER
            addView(emblem)
        }
        val emblemParams = centeredParams().apply {
            topMargin = dp(42)
            bottomMargin = dp(28)
        }
        root.addView(emblemWrap, emblemParams)

        val title = TextView(this).apply {
            text = "WAKTUNYA BERHENTI"
            textSize = 25f
            setTextColor(0xFFFFFFFF.toInt())
            typeface = Typeface.create("sans-serif", Typeface.BOLD)
            gravity = Gravity.CENTER
        }
        root.addView(title, centeredParams())

        val subtitle = TextView(this).apply {
            text = "Kamu sedang menjaga komitmenmu. Aplikasi ini belum bisa digunakan."
            textSize = 15f
            setTextColor(muted)
            gravity = Gravity.CENTER
            setLineSpacing(dp(4).toFloat(), 1f)
        }
        root.addView(subtitle, centeredParams().apply {
            topMargin = dp(12)
            bottomMargin = dp(28)
        })

        val card = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.CENTER
            setPadding(dp(22), dp(22), dp(22), dp(22))
            background = rounded(0xFF172337.toInt(), 22)
        }
        val blockedLabel = TextView(this).apply {
            text = "APLIKASI YANG DIBLOKIR"
            textSize = 11f
            letterSpacing = 0.12f
            setTextColor(muted)
            gravity = Gravity.CENTER
        }
        card.addView(blockedLabel, centeredParams())
        targetMessage = TextView(this).apply {
            textSize = 18f
            setTextColor(0xFFFFFFFF.toInt())
            typeface = Typeface.create("sans-serif-medium", Typeface.NORMAL)
            gravity = Gravity.CENTER
            setPadding(0, dp(10), 0, dp(20))
        }
        card.addView(targetMessage, centeredParams())
        countdown = TextView(this).apply {
            textSize = 20f
            setTextColor(accent)
            typeface = Typeface.create("sans-serif-medium", Typeface.BOLD)
            gravity = Gravity.CENTER
        }
        card.addView(countdown, centeredParams())
        root.addView(card, LinearLayout.LayoutParams(
            LinearLayout.LayoutParams.MATCH_PARENT,
            LinearLayout.LayoutParams.WRAP_CONTENT
        ).apply {
            topMargin = dp(8)
        })

        val footer = TextView(this).apply {
            text = "Tetap kuat. Waktu perlindungan akan berakhir sesuai jadwal."
            textSize = 13f
            setTextColor(muted)
            gravity = Gravity.CENTER
        }
        root.addView(footer, centeredParams().apply {
            topMargin = dp(28)
        })

        setContentView(root)
        updateTargetLabel(intent)
        updateCountdown()
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        updateTargetLabel(intent)
    }

    private fun updateTargetLabel(intent: Intent) {
        val target = intent.getStringExtra(EXTRA_PACKAGE).orEmpty()
        val label = runCatching {
            packageManager.getApplicationLabel(
                packageManager.getApplicationInfo(target, 0)
            ).toString()
        }.getOrDefault("Aplikasi ini")
        targetMessage.text = label
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

    private fun dp(value: Int): Int = (value * resources.displayMetrics.density).toInt()

    private fun rounded(color: Int, radius: Int) = GradientDrawable().apply {
        setColor(color)
        cornerRadius = dp(radius).toFloat()
    }

    private fun centeredParams() = LinearLayout.LayoutParams(
        LinearLayout.LayoutParams.MATCH_PARENT,
        LinearLayout.LayoutParams.WRAP_CONTENT
    )

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
