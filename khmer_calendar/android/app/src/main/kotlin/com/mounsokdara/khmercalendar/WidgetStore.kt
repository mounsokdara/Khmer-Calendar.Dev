package com.mounsokdara.khmercalendar

import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import org.json.JSONObject
import java.util.Calendar

object WidgetStore {
    const val PREFS = "khmer_home_widget"
    const val CHANNEL = "khmer_daily"
    const val NOTIFY_ID = 1001

    val WEEKDAYS_KM = arrayOf("អាទិត្យ", "ចន្ទ", "អង្គារ", "ពុធ", "ព្រហស្បតិ៍", "សុក្រ", "សៅរ៍")
    val WEEKDAYS_EN = arrayOf("Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday")
    val WEEK_SHORT_KM = arrayOf("អា", "ច", "អ", "ព", "ព្រ", "សុ", "ស")
    val WEEK_SHORT_EN = arrayOf("Su", "Mo", "Tu", "We", "Th", "Fr", "Sa")
    val MONTHS_KM = arrayOf("មករា", "កុម្ភៈ", "មីនា", "មេសា", "ឧសភា", "មិថុនា", "កក្កដា", "សីហា", "កញ្ញា", "តុលា", "វិច្ឆិកា", "ធ្នូ")
    val MONTHS_EN = arrayOf("January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December")

    fun prefs(context: Context) = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)

    fun todayIso(): String {
        val c = Calendar.getInstance()
        return "%04d-%02d-%02d".format(
            c.get(Calendar.YEAR),
            c.get(Calendar.MONTH) + 1,
            c.get(Calendar.DAY_OF_MONTH),
        )
    }

    fun lang(context: Context) = prefs(context).getString("lang", "km") ?: "km"

    fun weekStartsOn(context: Context) = prefs(context).getInt("weekStartsOn", 1)

    fun title(context: Context) = prefs(context).getString("title", "ប្រតិទិនខ្មែរ") ?: "ប្រតិទិនខ្មែរ"

    fun dayPayload(context: Context, iso: String): JSONObject? {
        val raw = prefs(context).getString("days", null) ?: return null
        return try {
            JSONObject(raw).optJSONObject(iso)
        } catch (_: Exception) {
            null
        }
    }

    fun launch(context: Context, tab: String? = null, date: String? = null): PendingIntent {
        val intent =
            Intent(context, MainActivity::class.java)
                .setFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP)
                .setAction("khmer.OPEN")
        if (tab != null) intent.putExtra("tab", tab)
        if (date != null) intent.putExtra("date", date)
        val flags = PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        val req =
            if (!date.isNullOrEmpty()) {
                date.replace("-", "").toIntOrNull() ?: date.hashCode()
            } else if (!tab.isNullOrEmpty()) {
                100000 + tab.hashCode()
            } else {
                0
            }
        return PendingIntent.getActivity(context, req, intent, flags)
    }

    fun osNotificationsOn(context: Context): Boolean {
        if (Build.VERSION.SDK_INT >= 33) {
            val granted =
                context.checkSelfPermission(android.Manifest.permission.POST_NOTIFICATIONS) ==
                    android.content.pm.PackageManager.PERMISSION_GRANTED
            if (!granted) return false
        }
        val nm = context.getSystemService(android.app.NotificationManager::class.java) ?: return false
        return if (Build.VERSION.SDK_INT >= 24) nm.areNotificationsEnabled() else true
    }

    fun masterNotifyOn(context: Context): Boolean {
        return prefs(context).getBoolean("notifyOn", false) && osNotificationsOn(context)
    }

    fun kindOn(context: Context, key: String, default: Boolean = false): Boolean {
        return masterNotifyOn(context) && prefs(context).getBoolean(key, default)
    }

    fun dailyOn(context: Context) = kindOn(context, "notifyDaily", false)

    fun silOn(context: Context) = kindOn(context, "notifySil", true)

    fun publicOn(context: Context) = kindOn(context, "notifyPublic", true)

    fun othersOn(context: Context): Boolean {
        val p = prefs(context)
        val enabled =
            if (p.contains("notifyOthers")) {
                p.getBoolean("notifyOthers", true)
            } else {
                p.getBoolean("notifyReligious", true)
            }
        return masterNotifyOn(context) && enabled
    }

    fun religiousOn(context: Context) = othersOn(context)

    fun dayDetail(context: Context, iso: String = todayIso()): String {
        val p = dayPayload(context, iso) ?: return ""
        return listOf(
            listOf(p.optString("weekday"), p.optString("gregorian")).filter { it.isNotEmpty() }.joinToString(" · "),
            p.optString("lunar"),
            p.optString("be"),
        ).filter { it.isNotEmpty() }.joinToString("\n")
    }

    fun isSilDay(context: Context, iso: String = todayIso()): Boolean {
        return silIsoList(context).any { it == iso }
    }

    fun silIsoList(context: Context): List<String> {
        val raw = prefs(context).getString("sil_days", "") ?: return emptyList()
        return raw.split(",").map { it.trim() }.filter { it.length >= 10 }
    }
}
