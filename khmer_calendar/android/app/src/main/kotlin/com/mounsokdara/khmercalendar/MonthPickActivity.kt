package com.mounsokdara.khmercalendar

import android.app.Activity
import android.appwidget.AppWidgetManager
import android.graphics.Color
import android.graphics.drawable.ColorDrawable
import android.graphics.drawable.GradientDrawable
import android.os.Build
import android.os.Bundle
import android.view.Gravity
import android.view.ViewGroup
import android.widget.Button
import android.widget.FrameLayout
import android.widget.LinearLayout
import android.widget.NumberPicker
import java.util.Calendar

/**
 * Floating month/year wheel picker for the month widget (replaces the old arrow buttons).
 * Not launchable: no intent filter and not exported, it is only opened by the widget header.
 * The widget redraws each time a wheel settles, so the change shows behind the popup.
 */
class MonthPickActivity : Activity() {
    private var widgetId = AppWidgetManager.INVALID_APPWIDGET_ID
    private lateinit var monthPicker: NumberPicker
    private lateinit var yearPicker: NumberPicker

    override fun onCreate(savedInstanceState: Bundle?) {
        val tones = WidgetTheme.current(this, WidgetTheme.load(this))
        setTheme(if (isDark(tones.surface)) R.style.MonthPickDark else R.style.MonthPickLight)
        super.onCreate(savedInstanceState)
        widgetId = intent.getIntExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, AppWidgetManager.INVALID_APPWIDGET_ID)
        setFinishOnTouchOutside(true)

        val km = WidgetStore.lang(this) != "en"
        val monthNames = if (km) WidgetStore.MONTHS_KM else WidgetStore.MONTHS_EN
        val yearLabels = Array(YEAR_MAX - YEAR_MIN + 1) {
            val y = YEAR_MIN + it
            if (km) WidgetTheme.khmerNum(y) else y.toString()
        }
        val (y0, m0) = MonthWidgetProvider.shownOf(this, widgetId)

        monthPicker = picker(0, 11, monthNames, (m0 - 1).coerceIn(0, 11), wrap = true, color = tones.onSurface)
        yearPicker = picker(0, YEAR_MAX - YEAR_MIN, yearLabels, (y0 - YEAR_MIN).coerceIn(0, YEAR_MAX - YEAR_MIN), wrap = false, color = tones.onSurface)

        val wheels = LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER
            addView(monthPicker, LinearLayout.LayoutParams(0, ViewGroup.LayoutParams.WRAP_CONTENT, 1f))
            addView(yearPicker, LinearLayout.LayoutParams(0, ViewGroup.LayoutParams.WRAP_CONTENT, 1f))
        }

        val today = Button(this, null, android.R.attr.borderlessButtonStyle).apply {
            text = if (km) "ថ្ងៃនេះ" else "Today"
            setTextColor(tones.primary)
            setOnClickListener {
                val now = Calendar.getInstance()
                monthPicker.value = now.get(Calendar.MONTH)
                yearPicker.value = (now.get(Calendar.YEAR) - YEAR_MIN).coerceIn(0, YEAR_MAX - YEAR_MIN)
                pushToWidget()
            }
        }
        val done = Button(this, null, android.R.attr.borderlessButtonStyle).apply {
            text = if (km) "រួចរាល់" else "Done"
            setTextColor(tones.primary)
            setOnClickListener {
                pushToWidget()
                finish()
            }
        }
        val buttons = LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.END
            addView(today)
            addView(done)
        }

        val card = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            val pad = dp(16)
            setPadding(pad, dp(12), pad, dp(8))
            background = GradientDrawable().apply {
                setColor(tones.surface)
                cornerRadius = dp(28).toFloat()
            }
            addView(wheels)
            addView(buttons)
        }
        val root = FrameLayout(this).apply {
            val m = dp(12)
            setPadding(m, m, m, m)
            addView(card, FrameLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT))
        }
        setContentView(root)
        window.setBackgroundDrawable(ColorDrawable(Color.TRANSPARENT))
        window.setLayout(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT)
        window.setGravity(Gravity.BOTTOM)
    }

    private fun picker(min: Int, max: Int, labels: Array<String>, value: Int, wrap: Boolean, color: Int): NumberPicker =
        NumberPicker(this).apply {
            descendantFocusability = ViewGroup.FOCUS_BLOCK_DESCENDANTS
            minValue = min
            maxValue = max
            displayedValues = labels
            this.value = value
            wrapSelectorWheel = wrap
            if (Build.VERSION.SDK_INT >= 29) {
                setTextColor(color)
                setTextSize(dp(20).toFloat())
            }
            setOnScrollListener { _, state ->
                if (state == NumberPicker.OnScrollListener.SCROLL_STATE_IDLE) pushToWidget()
            }
        }

    private fun pushToWidget() {
        MonthWidgetProvider.setShown(this, widgetId, YEAR_MIN + yearPicker.value, monthPicker.value + 1)
    }

    override fun onPause() {
        if (::monthPicker.isInitialized) pushToWidget()
        super.onPause()
    }

    private fun dp(v: Int): Int = (v * resources.displayMetrics.density).toInt()

    private fun isDark(argb: Int): Boolean {
        val lum = (Color.red(argb) * 299 + Color.green(argb) * 587 + Color.blue(argb) * 114) / 1000
        return lum < 128
    }

    private companion object {
        const val YEAR_MIN = 1900
        const val YEAR_MAX = 2100
    }
}
