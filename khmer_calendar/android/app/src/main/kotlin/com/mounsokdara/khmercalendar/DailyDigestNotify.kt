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
        NotifyKit.ensureChannels(context)
        NotifyKit.setExact(
            context,
            NotifyKit.nextMorning(),
            NotifyKit.broadcastPi(context, DailyNotifyReceiver::class.java, NotifyKit.DAILY_REQ),
        )
    }

    fun cancel(context: Context) {
        NotifyKit.cancelAlarm(
            context,
            NotifyKit.broadcastPi(context, DailyNotifyReceiver::class.java, NotifyKit.DAILY_REQ),
        )
        NotifyKit.cancelNote(context, NotifyKit.DAILY_ID)
    }

    fun show(context: Context) {
        if (!NotifyKit.dailyOn(context)) return
        val iso = WidgetStore.todayIso()
        val payload = WidgetStore.dayPayload(context, iso)
        val km = WidgetStore.lang(context) != "en"
        val title = if (km) "ប្រតិទិនថ្ងៃនេះ" else "Today's calendar"
        val lines = mutableListOf<String>()
        val detail = WidgetStore.dayDetail(context, iso)
        if (detail.isNotEmpty()) lines.add(detail)
        val holiday = payload?.optString("holiday").orEmpty()
        val hkind = payload?.optString("hkind").orEmpty()
        if (holiday.isNotEmpty()) {
            val kind =
                when (hkind) {
                    "religious" -> if (km) "ថ្ងៃបុណ្យសាសនា" else "Religious holiday"
                    "traditional" -> if (km) "ថ្ងៃប្រពៃណីខ្មែរ" else "Khmer tradition"
                    "international" -> if (km) "ព្រឹត្តិការណ៍អន្តរជាតិ" else "International event"
                    else -> if (km) "ថ្ងៃឈប់សម្រាកសាធារណៈ" else "Public holiday"
                }
            lines.add("$kind: $holiday")
        }
        if (payload?.optString("sil") == "1") {
            val moon = payload?.optString("moon").orEmpty()
            val sil = if (km) "ថ្ងៃសីល" else "Silas day"
            lines.add(if (moon.isNotEmpty()) "$sil ($moon)" else sil)
        }
        val body = lines.filter { it.isNotEmpty() }.joinToString("\n").ifEmpty { WidgetStore.title(context) }
        NotifyKit.post(context, NotifyKit.DAILY_ID, NotifyKit.CHANNEL_DAILY, title, body, "day", iso)
    }
}

class DailyNotifyReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (!NotifyKit.dailyOn(context)) {
            DailyDigestNotify.cancel(context)
        } else {
            DailyDigestNotify.show(context)
            DailyDigestNotify.schedule(context)
        }
        TodayWidgetProvider.refreshAll(context)
        MonthWidgetProvider.refreshAll(context)
        WeatherWidgetProvider.refreshAll(context)
    }
}
