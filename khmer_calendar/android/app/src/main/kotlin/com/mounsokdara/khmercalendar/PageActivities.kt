package com.mounsokdara.khmercalendar

class DayActivity : FlutterPageActivity() {
    override fun getInitialRoute(): String = "/day"
}

class CalendarActivity : FlutterPageActivity() {
    override fun getInitialRoute(): String = "/calendar"
}

class EventsActivity : FlutterPageActivity() {
    override fun getInitialRoute(): String = "/events"
}

class WeatherActivity : FlutterPageActivity() {
    override fun getInitialRoute(): String = "/weather"
}

class MoreActivity : FlutterPageActivity() {
    override fun getInitialRoute(): String = "/more"
}

class SettingsActivity : FlutterPageActivity() {
    override fun getInitialRoute(): String = "/settings"
}

class NotificationSettingsActivity : FlutterPageActivity() {
    override fun getInitialRoute(): String = "/settings/notifications"
}

class ThemeSettingsActivity : FlutterPageActivity() {
    override fun getInitialRoute(): String = "/settings/theme"
}

class SoundSettingsActivity : FlutterPageActivity() {
    override fun getInitialRoute(): String = "/settings/sounds"
}

class PermissionSettingsActivity : FlutterPageActivity() {
    override fun getInitialRoute(): String = "/settings/privacy"
}

class AboutActivity : FlutterPageActivity() {
    override fun getInitialRoute(): String = "/about"
}

class PrivacyPolicyActivity : FlutterPageActivity() {
    override fun getInitialRoute(): String = "/privacy-policy"
}

class LicensesActivity : FlutterPageActivity() {
    override fun getInitialRoute(): String = "/license"
}

class ToolsActivity : FlutterPageActivity() {
    override fun getInitialRoute(): String = "/tools"
}

class DateCalculatorActivity : FlutterPageActivity() {
    override fun getInitialRoute(): String = "/tools/datecalculator"
}

