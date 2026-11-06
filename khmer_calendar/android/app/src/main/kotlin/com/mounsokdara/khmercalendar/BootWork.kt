package com.mounsokdara.khmercalendar

import android.app.NotificationManager
import android.content.Context

object BootWork {
    fun run(context: Context) {
        val app = context.applicationContext
        try {
            app.getSystemService(NotificationManager::class.java)?.cancel(41)
        } catch (_: Exception) {
        }
        try {
            NotifyKit.sync(app)
        } catch (_: Exception) {
        }
        try {
            TodayWidgetProvider.refreshAll(app)
            MonthWidgetProvider.refreshAll(app)
            WeatherWidgetProvider.refreshAll(app)
        } catch (_: Exception) {
        }
    }
}
