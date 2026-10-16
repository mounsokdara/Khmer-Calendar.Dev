package com.mounsokdara.khmercalendar

import android.graphics.drawable.ColorDrawable
import android.os.Bundle

/**
 * Base for the dedicated Flutter screens that run as their own launchable activity. Same native
 * bridge as [MainActivity]; the subclass only picks the Dart route to start on.
 */
open class FlutterPageActivity : MainActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        paintWindow()
        super.onCreate(savedInstanceState)
        paintWindow()
    }

    private fun paintWindow() {
        try {
            val argb = getSharedPreferences("FlutterSharedPreferences", MODE_PRIVATE)
                .getLong("flutter.windowBgArgb", 0L).toInt()
            if (argb != 0) window.setBackgroundDrawable(ColorDrawable(argb))
        } catch (_: Exception) {
        }
    }
}
