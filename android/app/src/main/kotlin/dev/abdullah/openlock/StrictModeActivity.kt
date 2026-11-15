package dev.abdullah.openlock

import android.app.Activity
import android.app.AlertDialog
import android.content.Intent
import android.graphics.Typeface
import android.graphics.drawable.GradientDrawable
import android.os.Bundle
import android.os.CountDownTimer
import android.content.SharedPreferences
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
    private lateinit var attemptCount: TextView
    private lateinit var preferences: SharedPreferences
    private var paletteIndex = 0

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        window.addFlags(
            WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON or
                WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED
        )
        hideSystemBars()

        preferences = getSharedPreferences("strict_block_screen", MODE_PRIVATE)
        paletteIndex = preferences.getInt("palette", 0).coerceIn(0, 2)
        val palette = palettes[paletteIndex]
        val background = palette.background
        val muted = palette.muted
        val accent = palette.accent
        val attempts = preferences.getInt("blocked_attempts", 0) + 1
        preferences.edit().putInt("blocked_attempts", attempts).apply()
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
        attemptCount = TextView(this).apply {
            text = "Percobaan membuka diblokir: $attempts"
            textSize = 12f
            setTextColor(muted)
            gravity = Gravity.CENTER
            setPadding(0, dp(14), 0, 0)
        }
        card.addView(attemptCount, centeredParams())
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
            topMargin = dp(24)
        })

        val actions = LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER
        }
        actions.addView(actionButton("Tutup", background, 0xFFFFFFFF.toInt()) {
            openHome()
        }, LinearLayout.LayoutParams(0, dp(48), 1f).apply { marginEnd = dp(8) })
        actions.addView(actionButton("Sesuaikan", accent, background) {
            showAppearancePicker()
        }, LinearLayout.LayoutParams(0, dp(48), 1f).apply { marginStart = dp(8) })
        root.addView(actions, centeredParams().apply { topMargin = dp(24) })

        setContentView(root)
        emblem.animate().alpha(0.72f).setDuration(650).withEndAction {
            emblem.animate().alpha(1f).setDuration(650).start()
        }.start()
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


    private data class ScreenPalette(val background: Int, val muted: Int, val accent: Int)

    private val palettes = listOf(
        ScreenPalette(0xFF0B1220.toInt(), 0xFFB8C4D6.toInt(), 0xFF72E4C2.toInt()),
        ScreenPalette(0xFF171329.toInt(), 0xFFC8BEDF.toInt(), 0xFFFFC36B.toInt()),
        ScreenPalette(0xFF102321.toInt(), 0xFFB7D5CC.toInt(), 0xFF8CE0B5.toInt()),
    )

    private fun actionButton(label: String, fill: Int, foreground: Int, action: () -> Unit): TextView =
        TextView(this).apply {
            text = label
            textSize = 14f
            gravity = Gravity.CENTER
            setTextColor(foreground)
            typeface = Typeface.create("sans-serif-medium", Typeface.BOLD)
            background = rounded(fill, 14)
            isClickable = true
            isFocusable = true
            setOnClickListener { action() }
        }

    private fun showAppearancePicker() {
        val labels = arrayOf("Malam mint", "Senja amber", "Hutan tenang")
        AlertDialog.Builder(this)
            .setTitle("Sesuaikan tampilan")
            .setSingleChoiceItems(labels, paletteIndex) { dialog, which ->
                paletteIndex = which
                preferences.edit().putInt("palette", which).apply()
                dialog.dismiss()
                recreate()
            }
            .setNegativeButton("Batal", null)
            .show()
    }

    private fun openHome() {
        val intent = Intent(Intent.ACTION_MAIN).apply {
            addCategory(Intent.CATEGORY_HOME)
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        }
        startActivity(intent)
        finish()
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
