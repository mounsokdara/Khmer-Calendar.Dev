package com.mounsokdara.khmercalendar

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.text.SpannableString
import android.text.Spanned
import android.text.style.AbsoluteSizeSpan
import android.view.View
import android.widget.RemoteViews
import org.json.JSONObject
import java.util.Calendar

class MonthWidgetProvider : AppWidgetProvider() {
    override fun onUpdate(context: Context, appWidgetManager: AppWidgetManager, appWidgetIds: IntArray) {
        for (id in appWidgetIds) {
            appWidgetManager.updateAppWidget(id, build(context, id))
        }
    }

    override fun onReceive(context: Context, intent: Intent) {
        super.onReceive(context, intent)
        val action = intent.action ?: return
        if (action == ACTION_SHIFT) {
            val widgetId = intent.getIntExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, AppWidgetManager.INVALID_APPWIDGET_ID)
            val unit = intent.getStringExtra(EXTRA_UNIT) ?: "month"
            val dir = intent.getIntExtra(EXTRA_DIR, 0)
            if (unit == "today") goToday(context, widgetId) else shift(context, widgetId, unit, dir)
            if (widgetId != AppWidgetManager.INVALID_APPWIDGET_ID) {
                AppWidgetManager.getInstance(context).updateAppWidget(widgetId, build(context, widgetId))
            } else {
                refreshAll(context)
            }
            return
        }
        if (action == Intent.ACTION_DATE_CHANGED ||
            action == Intent.ACTION_TIMEZONE_CHANGED ||
            action == Intent.ACTION_TIME_CHANGED ||
            action == Intent.ACTION_BOOT_COMPLETED ||
            action == AppWidgetManager.ACTION_APPWIDGET_UPDATE
        ) {
            refreshAll(context)
        }
    }

    companion object {
        const val ACTION_SHIFT = "com.mounsokdara.khmercalendar.MONTH_SHIFT"
        const val EXTRA_UNIT = "unit"
        const val EXTRA_DIR = "dir"

        fun refreshAll(context: Context) {
            val mgr = AppWidgetManager.getInstance(context)
            val ids = mgr.getAppWidgetIds(ComponentName(context, MonthWidgetProvider::class.java))
            for (id in ids) mgr.updateAppWidget(id, build(context, id))
        }

        fun shownOf(context: Context, widgetId: Int): Pair<Int, Int> = shown(context, widgetId)

        /** Used by [MonthPickActivity]: jump this widget to [year]/[month] and redraw it. */
        fun setShown(context: Context, widgetId: Int, year: Int, month: Int) {
            if (widgetId == AppWidgetManager.INVALID_APPWIDGET_ID) return
            WidgetStore.prefs(context).edit()
                .putInt("month_y_$widgetId", year)
                .putInt("month_m_$widgetId", month)
                .apply()
            AppWidgetManager.getInstance(context).updateAppWidget(widgetId, build(context, widgetId))
        }

        private fun pickPi(context: Context, widgetId: Int): PendingIntent {
            val intent =
                Intent(context, MonthPickActivity::class.java)
                    .putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, widgetId)
                    .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP)
            val flags = PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            return PendingIntent.getActivity(context, 7 + widgetId * 10, intent, flags)
        }

        private fun shown(context: Context, widgetId: Int): Pair<Int, Int> {
            val p = WidgetStore.prefs(context)
            val now = Calendar.getInstance()
            val y = p.getInt("month_y_$widgetId", now.get(Calendar.YEAR))
            val m = p.getInt("month_m_$widgetId", now.get(Calendar.MONTH) + 1)
            return y to m
        }

        private fun goToday(context: Context, widgetId: Int) {
            if (widgetId == AppWidgetManager.INVALID_APPWIDGET_ID) return
            val now = Calendar.getInstance()
            WidgetStore.prefs(context).edit()
                .putInt("month_y_$widgetId", now.get(Calendar.YEAR))
                .putInt("month_m_$widgetId", now.get(Calendar.MONTH) + 1)
                .apply()
        }

        private fun shift(context: Context, widgetId: Int, unit: String, dir: Int) {
            if (widgetId == AppWidgetManager.INVALID_APPWIDGET_ID) return
            val (y0, m0) = shown(context, widgetId)
            val cal = Calendar.getInstance()
            cal.set(Calendar.DAY_OF_MONTH, 1)
            cal.set(Calendar.YEAR, y0)
            cal.set(Calendar.MONTH, m0 - 1)
            if (unit == "year") cal.add(Calendar.YEAR, dir) else cal.add(Calendar.MONTH, dir)
            WidgetStore.prefs(context).edit()
                .putInt("month_y_$widgetId", cal.get(Calendar.YEAR))
                .putInt("month_m_$widgetId", cal.get(Calendar.MONTH) + 1)
                .apply()
        }

        private fun shiftPi(context: Context, widgetId: Int, unit: String, dir: Int, req: Int): PendingIntent {
            val intent =
                Intent(context, MonthWidgetProvider::class.java)
                    .setAction(ACTION_SHIFT)
                    .putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, widgetId)
                    .putExtra(EXTRA_UNIT, unit)
                    .putExtra(EXTRA_DIR, dir)
            val flags = PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            return PendingIntent.getBroadcast(context, req + widgetId * 10, intent, flags)
        }

        private fun gridStart(year: Int, month: Int, weekStartsOn: Int): Calendar {
            val first = Calendar.getInstance()
            first.set(Calendar.YEAR, year)
            first.set(Calendar.MONTH, month - 1)
            first.set(Calendar.DAY_OF_MONTH, 1)
            first.set(Calendar.HOUR_OF_DAY, 0)
            first.set(Calendar.MINUTE, 0)
            first.set(Calendar.SECOND, 0)
            first.set(Calendar.MILLISECOND, 0)
            val firstDow = first.get(Calendar.DAY_OF_WEEK) - 1
            val offset = (firstDow - weekStartsOn + 7) % 7
            first.add(Calendar.DATE, -offset)
            return first
        }

        private fun isoOf(cal: Calendar): String {
            return "%04d-%02d-%02d".format(
                cal.get(Calendar.YEAR),
                cal.get(Calendar.MONTH) + 1,
                cal.get(Calendar.DAY_OF_MONTH),
            )
        }

        private fun marks(context: Context): JSONObject {
            val raw = WidgetStore.prefs(context).getString("marks", null) ?: return JSONObject()
            return try {
                JSONObject(raw)
            } catch (_: Exception) {
                JSONObject()
            }
        }

        private fun names(context: Context): JSONObject {
            val raw = WidgetStore.prefs(context).getString("names", null) ?: return JSONObject()
            return try {
                JSONObject(raw)
            } catch (_: Exception) {
                JSONObject()
            }
        }

        private fun cellId(context: Context, i: Int): Int {
            return context.resources.getIdentifier("cell_$i", "id", context.packageName)
        }

        private fun silId(context: Context, i: Int): Int {
            return context.resources.getIdentifier("sil_$i", "id", context.packageName)
        }

        private fun headId(context: Context, i: Int): Int {
            return context.resources.getIdentifier("head_$i", "id", context.packageName)
        }

        private fun ringId(context: Context, i: Int): Int {
            return context.resources.getIdentifier("ring_$i", "id", context.packageName)
        }

        private val HEAD_KM = arrayOf("អាទិត្យ", "ចន្ទ", "អង្គារ", "ពុធ", "ព្រហ.", "សុក្រ", "សៅរ៍")
        private val HEAD_EN = arrayOf("Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat")

        private fun monthSub(context: Context, year: Int, month: Int): String {
            val raw = WidgetStore.prefs(context).getString("month_info", null) ?: return ""
            return try {
                JSONObject(raw).optString("%04d-%02d".format(year, month), "")
            } catch (_: Exception) {
                ""
            }
        }

        private fun cellLabel(num: String, name: String): CharSequence {
            if (name.isEmpty()) return num
            val s = SpannableString("$num\n$name")
            s.setSpan(AbsoluteSizeSpan(8, true), num.length + 1, s.length, Spanned.SPAN_EXCLUSIVE_EXCLUSIVE)
            return s
        }

        private fun build(context: Context, widgetId: Int): RemoteViews {
            val views = RemoteViews(context.packageName, R.layout.khmer_month_widget)
            val lang = WidgetStore.lang(context)
            val weekStart = WidgetStore.weekStartsOn(context)
            val (year, month) = shown(context, widgetId)
            val months = if (lang == "en") WidgetStore.MONTHS_EN else WidgetStore.MONTHS_KM
            val short = if (lang == "en") HEAD_EN else HEAD_KM
            val markMap = marks(context)
            val nameMap = names(context)
            val pal = WidgetTheme.load(context)
            WidgetTheme.tint(context, views, pal, R.id.month_bg) { it.surface }
            WidgetTheme.text(context, views, pal, R.id.month_today) { it.primary }
            WidgetTheme.text(context, views, pal, R.id.month_name) { it.onSurface }
            WidgetTheme.text(context, views, pal, R.id.month_sub) { it.onVariant }
            val monthName = months[(month - 1).coerceIn(0, 11)]
            views.setTextViewText(
                R.id.month_name,
                if (lang == "en") "$monthName $year" else "$monthName គ.ស ${WidgetTheme.khmerNum(year)}",
            )
            views.setTextViewText(R.id.month_sub, monthSub(context, year, month))
            views.setTextViewText(R.id.month_today, if (lang == "en") "Today" else "ថ្ងៃនេះ")
            val today = Calendar.getInstance()
            val onThisMonth =
                year == today.get(Calendar.YEAR) && month == today.get(Calendar.MONTH) + 1
            views.setViewVisibility(R.id.month_today, if (onThisMonth) View.GONE else View.VISIBLE)
            for (i in 0 until 7) {
                val idx = (weekStart + i) % 7
                views.setTextViewText(headId(context, i), short[idx])
                WidgetTheme.text(context, views, pal, headId(context, i)) { it.onVariant }
            }
            val start = gridStart(year, month, weekStart)
            for (i in 0 until 42) {
                val d = start.clone() as Calendar
                d.add(Calendar.DATE, i)
                val inMonth = d.get(Calendar.MONTH) == month - 1
                val isToday =
                    d.get(Calendar.YEAR) == today.get(Calendar.YEAR) &&
                        d.get(Calendar.MONTH) == today.get(Calendar.MONTH) &&
                        d.get(Calendar.DAY_OF_MONTH) == today.get(Calendar.DAY_OF_MONTH)
                val flags = markMap.optString(isoOf(d), "")
                val sunday = d.get(Calendar.DAY_OF_WEEK) == Calendar.SUNDAY
                val id = cellId(context, i)
                val dayNum = d.get(Calendar.DAY_OF_MONTH)
                val name = if (inMonth) nameMap.optString(isoOf(d), "") else ""
                views.setTextViewText(id, cellLabel(if (lang == "en") dayNum.toString() else WidgetTheme.khmerNum(dayNum), name))
                views.setInt(id, "setMaxLines", 3)
                val ring = ringId(context, i)
                views.setViewVisibility(ring, if (isToday) View.VISIBLE else View.GONE)
                if (isToday) WidgetTheme.tint(context, views, pal, ring) { it.primary }
                val pick: (WidgetTheme.Tones) -> Int =
                    when {
                        !inMonth -> { t -> t.dim() }
                        flags.contains('p') || sunday -> { t -> t.publicDay }
                        flags.contains('h') -> { t -> t.holiday }
                        else -> { t -> t.onSurface }
                    }
                WidgetTheme.text(context, views, pal, id, pick)
                views.setViewVisibility(
                    silId(context, i),
                    if (inMonth && flags.contains('s')) View.VISIBLE else View.GONE,
                )
                views.setOnClickPendingIntent(
                    id,
                    WidgetStore.launch(context, "today", isoOf(d)),
                )
            }
            views.setOnClickPendingIntent(R.id.month_today, shiftPi(context, widgetId, "today", 0, 5))
            val openCalendar = WidgetStore.launch(context, "calendar")
            views.setOnClickPendingIntent(R.id.month_root, openCalendar)
            val pick = pickPi(context, widgetId)
            views.setOnClickPendingIntent(R.id.month_name, pick)
            views.setOnClickPendingIntent(R.id.month_sub, pick)
            return views
        }
    }
}
