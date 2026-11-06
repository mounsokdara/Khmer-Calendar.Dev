package com.mounsokdara.khmercalendar

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

object DailyDigestNotify {
    fun schedule(context: Context) {
        if (!NotifyKit.dailyOn(context)) {
            cancel(context)
            return
        }
        val app = context.applicationContext
        val am = app.getSystemService(android.app.AlarmManager::class.java) ?: return
        val pi = android.app.PendingIntent.getBroadcast(
            app, 41,
            Intent(app, DailyNotifyReceiver::class.java),
            android.app.PendingIntent.FLAG_UPDATE_CURRENT or android.app.PendingIntent.FLAG_IMMUTABLE
        )
        val cal = java.util.Calendar.getInstance().apply {
            set(java.util.Calendar.HOUR_OF_DAY, 7)
            set(java.util.Calendar.MINUTE, 0)
            set(java.util.Calendar.SECOND, 0)
            set(java.util.Calendar.MILLISECOND, 0)
            if (timeInMillis <= System.currentTimeMillis()) add(java.util.Calendar.DAY_OF_YEAR, 1)
        }
        try {
            am.setAndAllowWhileIdle(android.app.AlarmManager.RTC_WAKEUP, cal.timeInMillis, pi)
        } catch (_: Exception) {
            try {
                am.set(android.app.AlarmManager.RTC_WAKEUP, cal.timeInMillis, pi)
            } catch (_: Exception) {
            }
        }
    }

    fun cancel(context: Context) {
        val app = context.applicationContext
        val am = app.getSystemService(android.app.AlarmManager::class.java) ?: return
        val pi = android.app.PendingIntent.getBroadcast(
            app, 41,
            Intent(app, DailyNotifyReceiver::class.java),
            android.app.PendingIntent.FLAG_UPDATE_CURRENT or android.app.PendingIntent.FLAG_IMMUTABLE
        )
        am.cancel(pi)
    }
}

class DailyNotifyReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (!NotifyKit.dailyOn(context)) {
            return
        }
        // fire the digest then re-schedule for tomorrow
        try {
            NotifyKit.showDaily(context)
        } catch (_: Exception) {
        }
        schedule(context)
    }
}
