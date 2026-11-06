package com.mounsokdara.khmercalendar

import android.content.Context
import androidx.startup.Initializer

class BootInitializer : Initializer<Unit> {
    override fun create(context: Context) {
        BootWork.run(context)
    }

    override fun dependencies(): List<Class<out Initializer<*>>> = emptyList()
}
