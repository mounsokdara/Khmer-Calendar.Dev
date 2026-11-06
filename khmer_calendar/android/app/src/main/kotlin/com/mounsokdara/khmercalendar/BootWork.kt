package com.mounsokdara.khmercalendar

import android.app.NotificationManager
import android.content.Context

object BootWork {
    fun run(context: Context) {
        val app = context.applicationContext
        try {
            NotifyKit.ensureChannels(app)
            SilNotify.rearm(app)
            HolidayNotifies.rearm(app)
            DailyDigestNotify.schedule(app)
            MonthWidgetProvider.refreshAll(app)
        } catch (e: Exception) {
            // never crash the process on boot / startup
        }
    }
}
