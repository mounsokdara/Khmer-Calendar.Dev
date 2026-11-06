package com.mounsokdara.khmercalendar

import android.appwidget.AppWidgetManager
import io.flutter.embedding.android.FlutterActivityLaunchConfigs

class MonthPickActivity : MainActivity() {
    override fun getBackgroundMode(): FlutterActivityLaunchConfigs.BackgroundMode =
        FlutterActivityLaunchConfigs.BackgroundMode.transparent

    override fun getInitialRoute(): String {
        val id = intent.getIntExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, AppWidgetManager.INVALID_APPWIDGET_ID)
        val (year, month) = MonthWidgetProvider.shownOf(this, id)
        return "/widget-pick?id=$id&y=$year&m=$month"
    }
}
