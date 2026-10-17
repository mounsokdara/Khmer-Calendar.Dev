package com.mounsokdara.khmercalendar

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.view.View
import android.widget.RemoteViews
import java.util.Calendar

class TodayWidgetProvider : AppWidgetProvider() {
    override fun onUpdate(context: Context, appWidgetManager: AppWidgetManager, appWidgetIds: IntArray) {
        val views = build(context)
        for (id in appWidgetIds) {
            appWidgetManager.updateAppWidget(id, views)
        }
    }

    override fun onReceive(context: Context, intent: Intent) {
        super.onReceive(context, intent)
        val action = intent.action ?: return
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
        const val PREFS = "khmer_home_widget"
        private val WEEKDAYS_KM = arrayOf("អាទិត្យ", "ចន្ទ", "អង្គារ", "ពុធ", "ព្រហស្បតិ៍", "សុក្រ", "សៅរ៍")
        private val WEEKDAYS_EN = arrayOf("Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday")

        fun refreshAll(context: Context) {
            val mgr = AppWidgetManager.getInstance(context)
            val ids = mgr.getAppWidgetIds(ComponentName(context, TodayWidgetProvider::class.java))
            if (ids.isEmpty()) return
            val views = build(context)
            for (id in ids) mgr.updateAppWidget(id, views)
        }

        private fun todayIso(): String {
            val c = Calendar.getInstance()
            return "%04d-%02d-%02d".format(
                c.get(Calendar.YEAR),
                c.get(Calendar.MONTH) + 1,
                c.get(Calendar.DAY_OF_MONTH),
            )
        }

        private fun build(context: Context): RemoteViews {
            val views = RemoteViews(context.packageName, R.layout.khmer_today_widget)
            val cal = Calendar.getInstance()
            val day = cal.get(Calendar.DAY_OF_MONTH).toString()
            val wIndex = cal.get(Calendar.DAY_OF_WEEK) - 1
            val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            val iso = prefs.getString("iso", "") ?: ""
            val fresh = iso == todayIso()
            val weekday =
                if (fresh) {
                    prefs.getString("weekday", "") ?: WEEKDAYS_KM[wIndex]
                } else {
                    WEEKDAYS_KM.getOrElse(wIndex) { WEEKDAYS_EN[wIndex] }
                }
            val lunar = if (fresh) prefs.getString("lunar", "") ?: "" else ""
            val holiday = if (fresh) prefs.getString("holiday", "") ?: "" else ""
            val title = prefs.getString("title", null) ?: "ប្រតិទិនខ្មែរ"

            views.setTextViewText(R.id.widget_title, title)
            views.setTextViewText(R.id.widget_day, if (fresh && !prefs.getString("day", "").isNullOrEmpty()) prefs.getString("day", day) else day)
            views.setTextViewText(R.id.widget_weekday, weekday)
            if (lunar.isNotEmpty()) {
                views.setViewVisibility(R.id.widget_lunar, View.VISIBLE)
                views.setTextViewText(R.id.widget_lunar, lunar)
            } else {
                views.setViewVisibility(R.id.widget_lunar, View.GONE)
            }
            if (holiday.isNotEmpty()) {
                views.setViewVisibility(R.id.widget_holiday, View.VISIBLE)
                views.setTextViewText(R.id.widget_holiday, holiday)
            } else {
                views.setViewVisibility(R.id.widget_holiday, View.GONE)
            }

            val greg = if (fresh) prefs.getString("gregorian", "") ?: "" else ""
            if (greg.isNotEmpty()) {
                views.setViewVisibility(R.id.widget_greg, View.VISIBLE)
                views.setTextViewText(R.id.widget_greg, greg)
            } else {
                views.setViewVisibility(R.id.widget_greg, View.GONE)
            }

            val pal = WidgetTheme.load(context)
            val holidayIsPublic = prefs.getString("hkind", "") == "public"
            WidgetTheme.tint(context, views, pal, R.id.widget_bg) { it.surface }
            WidgetTheme.text(context, views, pal, R.id.widget_title) { it.onVariant }
            WidgetTheme.text(context, views, pal, R.id.widget_day) { it.primary }
            WidgetTheme.text(context, views, pal, R.id.widget_weekday) { it.onSurface }
            WidgetTheme.text(context, views, pal, R.id.widget_greg) { it.onSurface }
            WidgetTheme.text(context, views, pal, R.id.widget_lunar) { it.onVariant }
            WidgetTheme.text(context, views, pal, R.id.widget_holiday) { if (holidayIsPublic) it.publicDay else it.holiday }

            views.setOnClickPendingIntent(R.id.widget_root, WidgetStore.launch(context, "today"))
            return views
        }
    }
}
