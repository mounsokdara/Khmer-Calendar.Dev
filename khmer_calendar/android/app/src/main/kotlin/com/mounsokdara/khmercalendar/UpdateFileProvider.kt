package com.mounsokdara.khmercalendar

import androidx.core.content.FileProvider

/**
 * Serves the APK downloaded by the in-app dev updater to the system installer.
 * A subclass (instead of androidx.core.content.FileProvider itself) so it can never clash with another
 * plugin's provider entry when the manifests are merged.
 */
class UpdateFileProvider : FileProvider()
