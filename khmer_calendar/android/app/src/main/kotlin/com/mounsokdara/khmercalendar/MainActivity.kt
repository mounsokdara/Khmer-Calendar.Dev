package com.mounsokdara.khmercalendar

import android.app.AlarmManager
import android.app.NotificationManager
import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.os.PowerManager
import android.os.VibrationEffect
import android.os.Vibrator
import android.os.VibratorManager
import android.provider.Settings
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.Executors

open class MainActivity : FlutterActivity() {
    private var pending: MethodChannel.Result? = null
    private var pendingCode = 0
    private var channel: MethodChannel? = null

    // Widget data, alarm scheduling and widget redraws are slow (big prefs commit, hundreds of
    // AlarmManager calls, bitmap decoding). Keep them off the UI thread, one job at a time and in order.
    private val worker = Executors.newSingleThreadExecutor()

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
        NotifyKit.ensureChannels(this)
        channel?.setMethodCallHandler { call, result ->
            when (call.method) {
                "setFlags" -> {
                    val bg = call.argument<Boolean>("background") ?: false
                    val auto = call.argument<Boolean>("autoLaunch") ?: false
                    getSharedPreferences(BootReceiver.PREFS, Context.MODE_PRIVATE)
                        .edit().putBoolean("background", bg).putBoolean("autoLaunch", auto).apply()
                    result.success(true)
                }
                "checkStatus" -> result.success(statusMap())
                "isHapticFeedbackEnabled" -> result.success(isHapticFeedbackEnabled())
                "vibrate" -> {
                    vibrate(call.argument<Int>("duration") ?: 8, call.argument<Int>("amplitude") ?: 40)
                    result.success(true)
                }
                "isIgnoringBattery" -> result.success(isIgnoringBattery())
                "requestBatteryExemption" -> requestBatteryExemption(result)
                "requestExactAlarm" -> requestExactAlarm(result)
                "openAutoStart" -> openAutoStart(result)
                "openAppSettings" -> startOrFail(result, REQ_SETTINGS, Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS).setData(Uri.parse("package:$packageName")))
                "openLocationSettings" -> startOrFail(result, REQ_LOCATION, Intent(Settings.ACTION_LOCATION_SOURCE_SETTINGS))
                "updateWidget" -> {
                    val args = call.arguments
                    worker.execute {
                        try {
                            saveWidget(args)
                            TodayWidgetProvider.refreshAll(this)
                            MonthWidgetProvider.refreshAll(this)
                            WeatherWidgetProvider.refreshAll(this)
                        } catch (_: Throwable) {
                        }
                        runOnUiThread {
                            try { result.success(true) } catch (_: Throwable) {}
                        }
                    }
                }
                "pinWidget" -> result.success(pinWidget(call.argument<String>("kind")))
                "getLaunch" -> result.success(launchMap(intent))
                else -> result.notImplemented()
            }
        }
    }

    private fun isHapticFeedbackEnabled(): Boolean = try {
        Settings.System.getInt(contentResolver, Settings.System.HAPTIC_FEEDBACK_ENABLED, 0) != 0
    } catch (_: Settings.SettingNotFoundException) {
        false
    }

    private fun vibrate(duration: Int, amplitude: Int) {
        try {
            val v: Vibrator? = if (Build.VERSION.SDK_INT >= 31) {
                getSystemService(VibratorManager::class.java)?.defaultVibrator
            } else {
                @Suppress("DEPRECATION")
                getSystemService(Context.VIBRATOR_SERVICE) as? Vibrator
            }
            if (v == null || !v.hasVibrator()) return
            if (Build.VERSION.SDK_INT >= 26) {
                val amp = if (v.hasAmplitudeControl()) amplitude.coerceIn(1, 255) else VibrationEffect.DEFAULT_AMPLITUDE
                v.vibrate(VibrationEffect.createOneShot(duration.toLong(), amp))
            } else {
                @Suppress("DEPRECATION")
                v.vibrate(duration.toLong())
            }
        } catch (_: Throwable) {
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        channel?.invokeMethod("open", launchMap(intent))
    }

    private fun launchMap(src: Intent?): HashMap<String, String> {
        val tab = src?.getStringExtra("tab") ?: ""
        val date = src?.getStringExtra("date") ?: ""
        return hashMapOf("tab" to tab, "date" to date)
    }

    private fun saveWidget(args: Any?) {
        val map = args as? Map<*, *> ?: return
        val ed = getSharedPreferences(WidgetStore.PREFS, Context.MODE_PRIVATE).edit()
        fun putStr(key: String) { (map[key] as? String)?.let { ed.putString(key, it) } }
        listOf("iso", "day", "weekday", "lunar", "holiday", "title", "days", "marks", "names", "lang", "wx_city", "wx_city_en", "wx_temp", "wx_high", "wx_low", "wx_label", "wx_label_en", "wx_list", "sil_days", "public_hols", "religious_hols", "notify_items").forEach { putStr(it) }
        (map["weekStartsOn"] as? Number)?.let { ed.putInt("weekStartsOn", it.toInt()) }
        (map["wx_index"] as? Number)?.let { ed.putInt("wx_index", it.toInt()) }
        (map["notifyOn"] as? Boolean)?.let { ed.putBoolean("notifyOn", it) }
        (map["notifyDaily"] as? Boolean)?.let { ed.putBoolean("notifyDaily", it) }
        (map["notifySil"] as? Boolean)?.let { ed.putBoolean("notifySil", it) }
        (map["notifyPublic"] as? Boolean)?.let { ed.putBoolean("notifyPublic", it) }
        (map["notifyOthers"] as? Boolean)?.let { ed.putBoolean("notifyOthers", it) }
        (map["notifyReligious"] as? Boolean)?.let { ed.putBoolean("notifyReligious", it) }
        (map["notifyTasks"] as? Boolean)?.let { ed.putBoolean("notifyTasks", it) }
        ed.commit()
        // Weather-only updates carry no notification data; rescheduling every alarm for them is wasted work.
        val touchesNotify = map.containsKey("notify_items") || map.containsKey("notifyOn")
        if (touchesNotify) NotifyKit.sync(this)
    }

    override fun onDestroy() {
        worker.shutdown()
        super.onDestroy()
    }

    private fun pinWidget(kind: String?): Boolean {
        if (Build.VERSION.SDK_INT < 26) return false
        val mgr = getSystemService(AppWidgetManager::class.java) ?: return false
        if (!mgr.isRequestPinAppWidgetSupported) return false
        val cls = when (kind) { "month" -> MonthWidgetProvider::class.java; "weather" -> WeatherWidgetProvider::class.java; else -> TodayWidgetProvider::class.java }
        return try { mgr.requestPinAppWidget(ComponentName(this, cls), null, null); true } catch (_: Exception) { false }
    }

    @Deprecated("Deprecated in Java")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        @Suppress("DEPRECATION") super.onActivityResult(requestCode, resultCode, data)
        if (requestCode != pendingCode) return
        val r = pending ?: return
        pending = null
        pendingCode = 0
        when (requestCode) { REQ_BATTERY -> r.success(isIgnoringBattery()); REQ_EXACT -> r.success(canExactAlarms()); REQ_AUTOSTART -> r.success(true); else -> r.success(true) }
    }

    private fun statusMap(): HashMap<String, Boolean> = hashMapOf("notify" to notificationsEnabled(), "battery" to isIgnoringBattery(), "exactAlarm" to canExactAlarms(), "oemAutoStart" to hasOemAutoStartScreen())

    private fun notificationsEnabled(): Boolean {
        if (Build.VERSION.SDK_INT >= 33 && ContextCompat.checkSelfPermission(this, android.Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED) return false
        if (Build.VERSION.SDK_INT >= 24) return getSystemService(NotificationManager::class.java)?.areNotificationsEnabled() ?: false
        return true
    }
    private fun isIgnoringBattery(): Boolean { if (Build.VERSION.SDK_INT < 23) return true; return getSystemService(PowerManager::class.java)?.isIgnoringBatteryOptimizations(packageName) ?: true }
    private fun canExactAlarms(): Boolean { if (Build.VERSION.SDK_INT < 31) return true; return getSystemService(AlarmManager::class.java)?.canScheduleExactAlarms() ?: false }
    private fun hasOemAutoStartScreen(): Boolean {
        val maker = Build.MANUFACTURER.lowercase(); val brand = Build.BRAND.lowercase()
        return listOf("xiaomi", "redmi", "poco", "blackshark", "huawei", "honor", "oppo", "realme", "vivo", "iqoo", "oneplus", "letv", "asus", "transsion", "tecno", "infinix", "itel", "meizu", "lenovo", "zte", "nubia", "samsung").any { maker.contains(it) || brand.contains(it) }
    }
    private fun requestBatteryExemption(result: MethodChannel.Result) { if (isIgnoringBattery()) { result.success(true); return }; startOrFail(result, REQ_BATTERY, Intent(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS).setData(Uri.parse("package:$packageName"))) }
    private fun requestExactAlarm(result: MethodChannel.Result) { if (canExactAlarms() || Build.VERSION.SDK_INT < 31) { result.success(true); return }; startOrFail(result, REQ_EXACT, Intent(Settings.ACTION_REQUEST_SCHEDULE_EXACT_ALARM).setData(Uri.parse("package:$packageName"))) }
    private fun openAutoStart(result: MethodChannel.Result) {
        val tries = listOf(
            ComponentName("com.miui.securitycenter", "com.miui.permcenter.autostart.AutoStartManagementActivity"), ComponentName("com.miui.securitycenter", "com.miui.powercenter.PowerSettings"),
            ComponentName("com.huawei.systemmanager", "com.huawei.systemmanager.startupmgr.ui.StartupNormalAppListActivity"), ComponentName("com.huawei.systemmanager", "com.huawei.systemmanager.optimize.process.ProtectActivity"), ComponentName("com.huawei.systemmanager", "com.huawei.systemmanager.appcontrol.activity.StartupAppControlActivity"), ComponentName("com.hihonor.systemmanager", "com.hihonor.systemmanager.startupmgr.ui.StartupNormalAppListActivity"), ComponentName("com.coloros.safecenter", "com.coloros.safecenter.permission.startup.StartupAppListActivity"), ComponentName("com.coloros.safecenter", "com.coloros.safecenter.startupapp.StartupAppListActivity"), ComponentName("com.coloros.oppoguardelf", "com.coloros.powermanager.fuelgaue.PowerUsageModelActivity"), ComponentName("com.oppo.safe", "com.oppo.safe.permission.startup.StartupAppListActivity"), ComponentName("com.iqoo.secure", "com.iqoo.secure.ui.phoneoptimize.AddWhiteListActivity"), ComponentName("com.iqoo.secure", "com.iqoo.secure.ui.phoneoptimize.BgStartUpManager"), ComponentName("com.vivo.permissionmanager", "com.vivo.permissionmanager.activity.BgStartUpManagerActivity"), ComponentName("com.samsung.android.lool", "com.samsung.android.sm.battery.ui.BatteryActivity"), ComponentName("com.samsung.android.sm", "com.samsung.android.sm.ui.battery.BatteryActivity"), ComponentName("com.oneplus.security", "com.oneplus.security.chainlaunch.view.ChainLaunchAppListActivity"), ComponentName("com.letv.android.letvsafe", "com.letv.android.letvsafe.AutobootManageActivity"), ComponentName("com.asus.mobilemanager", "com.asus.mobilemanager.autostart.AutoStartActivity"), ComponentName("com.transsion.phonemanager", "com.transsion.phonemanager.startup.StartupAppListActivity"), ComponentName("com.transsion.phonemaster", "com.cyin.himgr.autostart.AutoStartActivity"), ComponentName("com.evenwell.powersaving.g3", "com.evenwell.powersaving.g3.exception.PowerSaverExceptionActivity")
        )
        for (c in tries) { val intent = Intent().setComponent(c); if (intent.resolveActivity(packageManager) == null) continue; if (tryStart(result, REQ_AUTOSTART, intent)) return }
        startOrFail(result, REQ_AUTOSTART, Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS).setData(Uri.parse("package:$packageName")))
    }
    private fun startOrFail(result: MethodChannel.Result, code: Int, intent: Intent) { if (!tryStart(result, code, intent)) result.success(false) }
    private fun tryStart(result: MethodChannel.Result, code: Int, intent: Intent): Boolean = try { pending?.success(false); pending = result; pendingCode = code; @Suppress("DEPRECATION") startActivityForResult(intent, code); true } catch (_: Exception) { pending = null; pendingCode = 0; false }

    companion object { const val CHANNEL = "khmer.permissions"; private const val REQ_BATTERY = 7101; private const val REQ_EXACT = 7103; private const val REQ_AUTOSTART = 7104; private const val REQ_SETTINGS = 7105; private const val REQ_LOCATION = 7106 }
}
