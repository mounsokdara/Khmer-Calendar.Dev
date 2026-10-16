package com.mounsokdara.khmercalendar

import android.content.Context
import android.content.res.Configuration
import android.graphics.Color
import android.os.Build
import android.widget.RemoteViews
import org.json.JSONObject

/**
 * Material 3 colours for the calendar widgets. The app pushes its own light and dark colour
 * schemes plus its theme mode; on Android 14+ the widget switches light/dark by itself when the
 * app follows the system, earlier versions pick the right set each time the widget is drawn.
 */
object WidgetTheme {
    class Tones(
        val surface: Int,
        val onSurface: Int,
        val onVariant: Int,
        val primary: Int,
        val onPrimary: Int,
        val container: Int,
        val onContainer: Int,
        val publicDay: Int,
        val holiday: Int,
    ) {
        fun dim(): Int = (onSurface and 0x00FFFFFF) or (0x66 shl 24)
    }

    class Palette(val light: Tones, val dark: Tones, val mode: String)

    private val FALLBACK_LIGHT = Tones(
        0xFFF3EDF7.toInt(), 0xFF1D1B20.toInt(), 0xFF49454F.toInt(), 0xFF6750A4.toInt(), 0xFFFFFFFF.toInt(),
        0xFFEADDFF.toInt(), 0xFF21005D.toInt(), 0xFFC62828.toInt(), 0xFF1E88E5.toInt(),
    )
    private val FALLBACK_DARK = Tones(
        0xFF211F26.toInt(), 0xFFE6E0E9.toInt(), 0xFFCAC4D0.toInt(), 0xFFD0BCFF.toInt(), 0xFF381E72.toInt(),
        0xFF4F378B.toInt(), 0xFFEADDFF.toInt(), 0xFFFF8A80.toInt(), 0xFF90CAF9.toInt(),
    )

    private fun parse(raw: String?, fallback: Tones): Tones {
        if (raw.isNullOrEmpty()) return fallback
        return try {
            val j = JSONObject(raw)
            fun c(key: String, def: Int): Int = try { Color.parseColor(j.getString(key)) } catch (_: Exception) { def }
            Tones(
                c("surface", fallback.surface), c("onSurface", fallback.onSurface), c("onVariant", fallback.onVariant),
                c("primary", fallback.primary), c("onPrimary", fallback.onPrimary), c("container", fallback.container),
                c("onContainer", fallback.onContainer), c("public", fallback.publicDay), c("holiday", fallback.holiday),
            )
        } catch (_: Exception) {
            fallback
        }
    }

    fun load(context: Context): Palette {
        val p = WidgetStore.prefs(context)
        return Palette(
            parse(p.getString("wp_light", null), FALLBACK_LIGHT),
            parse(p.getString("wp_dark", null), FALLBACK_DARK),
            p.getString("wp_mode", "system") ?: "system",
        )
    }

    private fun systemNight(context: Context): Boolean =
        (context.resources.configuration.uiMode and Configuration.UI_MODE_NIGHT_MASK) == Configuration.UI_MODE_NIGHT_YES

    private fun current(context: Context, pal: Palette): Tones = when (pal.mode) {
        "light" -> pal.light
        "dark" -> pal.dark
        else -> if (systemNight(context)) pal.dark else pal.light
    }

    private fun pair(pal: Palette, pick: (Tones) -> Int): Pair<Int, Int> = when (pal.mode) {
        "light" -> pick(pal.light) to pick(pal.light)
        "dark" -> pick(pal.dark) to pick(pal.dark)
        else -> pick(pal.light) to pick(pal.dark)
    }

    fun text(context: Context, views: RemoteViews, pal: Palette, id: Int, pick: (Tones) -> Int) {
        if (Build.VERSION.SDK_INT >= 34) {
            val (l, d) = pair(pal, pick)
            views.setColorInt(id, "setTextColor", l, d)
        } else {
            views.setTextColor(id, pick(current(context, pal)))
        }
    }

    fun tint(context: Context, views: RemoteViews, pal: Palette, id: Int, pick: (Tones) -> Int) {
        if (Build.VERSION.SDK_INT >= 34) {
            val (l, d) = pair(pal, pick)
            views.setColorInt(id, "setColorFilter", l, d)
        } else {
            views.setInt(id, "setColorFilter", pick(current(context, pal)))
        }
    }

    private val KHMER_DIGITS = charArrayOf('០', '១', '២', '៣', '៤', '៥', '៦', '៧', '៨', '៩')

    fun khmerNum(n: Int): String = n.toString().map { if (it in '0'..'9') KHMER_DIGITS[it - '0'] else it }.joinToString("")
}
