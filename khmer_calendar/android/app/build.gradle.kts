import com.android.build.gradle.internal.api.ApkVariantOutputImpl

plugins {
    id("com.android.application")
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.mounsokdara.khmercalendar"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "com.mounsokdara.khmercalendar"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    packaging {
        jniLibs {
            // Store the native libraries (libflutter.so, libapp.so, ...) compressed
            // inside the APK instead of raw. Same code, ~half the download size;
            // Android extracts them at install time.
            useLegacyPackaging = true
        }

    // F-Droid: do not embed the Google "Dependency metadata" signing block in the APK
    dependenciesInfo {
        includeInApk = false
        includeInBundle = false
    }
    }

    signingConfigs {
        create("release") {
            // Credentials come from environment variables (GitHub Actions secrets or local shell). Never hardcode.
            val ks = System.getenv("ANDROID_KEYSTORE")
            if (ks != null && file(ks).exists()) {
                storeFile = file(ks)
                storePassword = System.getenv("ANDROID_KEYSTORE_PASSWORD")
                keyAlias = System.getenv("ANDROID_KEY_ALIAS") ?: "com.mounsokdara.khmercalendar"
                keyPassword = System.getenv("ANDROID_KEY_PASSWORD")
            }
        }
    }

    buildTypes {
        release {
            val rel = signingConfigs.findByName("release")
            signingConfig = when {
                rel?.storeFile?.exists() == true -> rel
                // F-Droid builds without our keystore and signs the APK itself (its build sets FDROID_BUILD).
                System.getenv("FDROID_BUILD") != null -> signingConfigs.getByName("debug")
                else -> throw GradleException("Release keystore missing: refusing to sign a release build with the debug key")
            }
        }
    }
}

// Version codes: every package is versionCode * 10 + one digit saying what is inside (F-Droid ABI split).
// The base versionCode always comes from pubspec.yaml (1.0.4+5 -> 5), never from a CI run number.
//   0 universal | 1 arm32 (armeabi-v7a) | 2 arm64 (arm64-v8a) | 3 x64 (x86_64)
//   4 arm32_64 (arm + arm64) | 5 x86_x64 (x86 + x86_64) | 6 x86
val abiCodes = mapOf("armeabi-v7a" to 1, "arm64-v8a" to 2, "x86_64" to 3, "x86" to 6)
val targetPlatformCodes = mapOf(
    setOf("android-arm") to 1,
    setOf("android-arm64") to 2,
    setOf("android-x64") to 3,
    setOf("android-arm", "android-arm64") to 4,
    setOf("android-x86", "android-x64") to 5,
    setOf("android-x86") to 6,
)
// What `flutter build apk --target-platform ...` asked for (absent = the default set = universal).
val builtTargets: Set<String>? = (project.findProperty("target-platform") as String?)
    ?.split(',')?.map { it.trim() }?.filter { it.isNotEmpty() }?.toSet()
android.applicationVariants.configureEach {
    val variant = this
    variant.outputs.forEach { output ->
        val abi = output.filters.find { it.filterType == "ABI" }?.identifier
        // Split build: the ABI of this APK. Fat build: the targets that were requested (none -> universal).
        val code = if (abi != null) abiCodes[abi] else (builtTargets?.let { targetPlatformCodes[it] } ?: 0)
        if (code != null) {
            (output as ApkVariantOutputImpl).versionCodeOverride = variant.versionCode * 10 + code
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}

// F-Droid: no Google libraries. geolocator_android declares Play Services (the app forces the plain
// Android LocationManager, see lib/location.dart) and Flutter's embedding references Play Core
// (only used for Play Store deferred components, which this app does not use).
configurations.configureEach {
    exclude(group = "com.google.android.gms")
    exclude(group = "com.google.android.play")
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
    implementation("androidx.startup:startup-runtime:1.2.0")
}
