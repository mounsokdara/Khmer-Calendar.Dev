package com.mounsokdara.khmercalendar

import android.app.AlarmManager
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import java.util.Calendar

object NotifyKit {
    const val CHANNEL_DAILY = "khmer_daily"
    const val CHANNEL_SIL = "khmer_sil"
    const val CHANNEL_PUBLIC = "khmer_public"
    const val CHANNEL_RELIGIOUS = "khmer_religious"
    const val CHANNEL_TASKS = "khmer_tasks"
    const val DAILY_ID = 1001
    const val SIL_ID = 1002
    const val PUBLIC_ID = 1003
    const val RELIGIOUS_ID = 1004
    const val DAILY_REQ = 41
    const val SIL_REQ = 42
    const val SIL_ALARM_BASE = 3000
    const val PUBLIC_REQ = 4300
    const val RELIGIOUS_REQ = 5000
    const val LEGACY_RELIGIOUS_REQ = 4400
    const val SHOT_REQ = 6100
    const val CANCEL_FALLBACK = 512

    fun dailyOn(context: Context): Boolean = WidgetStore.dailyOn(context)

    fun silOn(context: Context): Boolean = WidgetStore.silOn(context)

    fun ensureChannels(context: Context) {
        if (Build.VERSION.SDK_INT < 26) return
        val nm = context.getSystemService(NotificationManager::class.java) ?: return
        listOf("khmer_daily_digest", "khmer_reminders", "khmer_holidays", "khmer_events").forEach { id ->
            try {
                nm.deleteNotificationChannel(id)
            } catch (_: Exception) {
            }
        }
        val km = WidgetStore.lang(context) != "en"
        fun ch(id: String, name: String, desc: String, high: Boolean = false) {
            val c =
                NotificationChannel(
                    id,
                    name,
                    if (high) NotificationManager.IMPORTANCE_HIGH else NotificationManager.IMPORTANCE_DEFAULT,
                )
            c.description = desc
            c.enableVibration(true)
            nm.createNotificationChannel(c)
        }
        ch(CHANNEL_DAILY, if (km) "រំលឹកប្រចាំថ្ងៃ" else "Daily reminder", if (km) "ជូនដំណឹងព្រឹកពីប្រតិទិនថ្ងៃនេះ" else "Morning calendar recap")
        ch(CHANNEL_SIL, if (km) "ថ្ងៃសីល" else "Silas days", if (km) "ជូនដំណឹងនៅថ្ងៃសីល" else "Silas day alerts", high = true)
        ch(CHANNEL_PUBLIC, if (km) "ថ្ងៃឈប់សម្រាកសាធារណៈ" else "Public holidays", if (km) "ជូនដំណឹងថ្ងៃឈប់សម្រាកសាធារណៈ" else "Public holiday alerts", high = true)
        ch(CHANNEL_RELIGIOUS, if (km) "ថ្ងៃបុណ្យផ្សេងទៀត" else "Other holidays", if (km) "ជូនដំណឹងថ្ងៃបុណ្យផ្សេងទៀត" else "Other holiday alerts", high = true)
        ch(CHANNEL_TASKS, if (km) "កិច្ចការ" else "Tasks", if (km) "ការរំលឹកកិច្ចការ" else "Task reminders")
    }

    fun post(context: Context, id: Int, channel: String, title: String, body: String, tab: String, date: String?, color: Int? = null) {
        ensureChannels(context)
        val nm = context.getSystemService(NotificationManager::class.java) ?: return
        val builder =
            if (Build.VERSION.SDK_INT >= 26) {
                Notification.Builder(context, channel)
            } else {
                @Suppress("DEPRECATION")
                Notification.Builder(context)
            }
        builder
            .setSmallIcon(R.drawable.ic_stat_notify)
            .setContentTitle(title)
            .setContentText(body)
            .setStyle(Notification.BigTextStyle().bigText(body))
            .setAutoCancel(true)
            .setContentIntent(WidgetStore.launch(context, tab, date))
        if (color != null) {
            builder.setColor(color)
            if (Build.VERSION.SDK_INT >= 26) builder.setColorized(false)
        }
        nm.notify(id, builder.build())
    }

    fun cancelNote(context: Context, id: Int) {
        context.getSystemService(NotificationManager::class.java)?.cancel(id)
        context.getSystemService(NotificationManager::class.java)?.cancel(WidgetStore.NOTIFY_ID)
    }

    fun setExact(context: Context, whenAt: Long, pi: PendingIntent) {
        val am = context.getSystemService(AlarmManager::class.java) ?: return
        try {
            if (Build.VERSION.SDK_INT >= 31 && !am.canScheduleExactAlarms()) {
                am.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, whenAt, pi)
            } else {
                am.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, whenAt, pi)
            }
        } catch (_: Exception) {
            try {
                am.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, whenAt, pi)
            } catch (_: Exception) {
            }
        }
    }

    fun cancelAlarm(context: Context, pi: PendingIntent) {
        context.getSystemService(AlarmManager::class.java)?.cancel(pi)
    }

    fun broadcastPi(context: Context, cls: Class<*>, req: Int): PendingIntent {
        val intent = Intent(context, cls)
        val flags = PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        return PendingIntent.getBroadcast(context, req, intent, flags)
    }

    fun nextMorning(): Long {
        val c = Calendar.getInstance()
        c.set(Calendar.HOUR_OF_DAY, 7)
        c.set(Calendar.MINUTE, 0)
        c.set(Calendar.SECOND, 0)
        c.set(Calendar.MILLISECOND, 0)
        if (c.timeInMillis <= System.currentTimeMillis() + 30_000) c.add(Calendar.DATE, 1)
        return c.timeInMillis
    }

    fun publicOn(context: Context): Boolean = WidgetStore.publicOn(context)

    fun religiousOn(context: Context): Boolean = WidgetStore.religiousOn(context)

    fun millisAt(iso: String, hour: Int, minute: Int = 0): Long? {
        val bits = iso.split("-")
        if (bits.size < 3) return null
        return try {
            val c = Calendar.getInstance()
            c.set(bits[0].toInt(), bits[1].toInt() - 1, bits[2].toInt(), hour, minute, 0)
            c.set(Calendar.MILLISECOND, 0)
            c.timeInMillis
        } catch (_: Exception) {
            null
        }
    }

    fun datedPi(context: Context, cls: Class<*>, req: Int, iso: String): PendingIntent {
        val intent = Intent(context, cls).putExtra("date", iso)
        val flags = PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        return PendingIntent.getBroadcast(context, req, intent, flags)
    }

    fun shotPi(context: Context, cls: Class<*>, req: Int, iso: String, hour: Int, minute: Int): PendingIntent {
        val intent =
            Intent(context, cls)
                .putExtra("date", iso)
                .putExtra("hour", hour)
                .putExtra("minute", minute)
        val flags = PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        return PendingIntent.getBroadcast(context, req, intent, flags)
    }

    private fun existingPi(context: Context, cls: Class<*>, req: Int): PendingIntent? {
        val intent = Intent(context, cls)
        val flags = PendingIntent.FLAG_NO_CREATE or PendingIntent.FLAG_IMMUTABLE
        return PendingIntent.getBroadcast(context, req, intent, flags)
    }

    fun scheduleIsoAlarms(
        context: Context,
        isos: List<String>,
        cls: Class<*>,
        baseReq: Int,
        hour: Int,
        countKey: String,
        extraCancelBases: IntArray = intArrayOf(),
    ) {
        cancelIsoAlarms(context, cls, baseReq, countKey, extraCancelBases)
        val now = System.currentTimeMillis()
        var n = 0
        val seen = HashSet<String>()
        for (iso in isos) {
            if (iso.length < 10 || !seen.add(iso)) continue
            val at = millisAt(iso, hour) ?: continue
            if (at <= now + 30_000) continue
            setExact(context, at, datedPi(context, cls, baseReq + n, iso))
            n++
        }
        WidgetStore.prefs(context).edit().putInt(countKey, n).apply()
    }

    fun cancelIsoAlarms(
        context: Context,
        cls: Class<*>,
        baseReq: Int,
        countKey: String,
        extraCancelBases: IntArray = intArrayOf(),
    ) {
        val stored = WidgetStore.prefs(context).getInt(countKey, CANCEL_FALLBACK)
        fun wipe(base: Int) {
            for (i in 0 until stored) {
                val pi = existingPi(context, cls, base + i) ?: continue
                cancelAlarm(context, pi)
            }
        }
        wipe(baseReq)
        extraCancelBases.forEach(::wipe)
        WidgetStore.prefs(context).edit().remove(countKey).apply()
    }

    fun sync(context: Context) {
        if (dailyOn(context)) DailyDigestNotify.schedule(context) else DailyDigestNotify.cancel(context)
        cancelIsoAlarms(context, SilNotifyReceiver::class.java, SIL_ALARM_BASE, "sil_days_alarm_n")
        cancelAlarm(context, broadcastPi(context, SilNotifyReceiver::class.java, SIL_REQ))
        cancelIsoAlarms(context, PublicHolidayReceiver::class.java, PUBLIC_REQ, "public_hols_alarm_n")
        cancelIsoAlarms(
            context,
            ReligiousHolidayReceiver::class.java,
            RELIGIOUS_REQ,
            "religious_hols_alarm_n",
            intArrayOf(LEGACY_RELIGIOUS_REQ),
        )
        DayShots.schedule(context)
    }
}
