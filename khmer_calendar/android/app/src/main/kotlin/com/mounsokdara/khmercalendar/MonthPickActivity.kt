package com.mounsokdara.khmercalendar

import android.appwidget.AppWidgetManager
import io.flutter.embedding.android.FlutterActivityLaunchConfigs

/**
 * Floating month/year picker for the month widget: the app's own Dart scroll picker shown in a
 * transparent activity over the home screen. Not launchable: no intent filter and not exported,
 * it is only opened by tapping the widget header.
 */
class MonthPickActivity : MainActivity() {
    override fun getBackgroundMode(): FlutterActivityLaunchConfigs.BackgroundMode =
        FlutterActivityLaunchConfigs.BackgroundMode.transparent

    override fun getInitialRoute(): String {
        val id = intent.getIntExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, AppWidgetManager.INVALID_APPWIDGET_ID)
        val (year, month) = MonthWidgetProvider.shownOf(this, id)
        return "/widget-pick?id=$id&y=$year&m=$month"
    }
}
