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

// Per-ABI version codes (F-Droid ABI split): armeabi-v7a -> 1, arm64-v8a -> 2, x86_64 -> 3,
// and 0 for the universal APK, so every build of one version has a distinct, ordered code.
val abiCodes = mapOf("armeabi-v7a" to 1, "arm64-v8a" to 2, "x86_64" to 3)
android.applicationVariants.configureEach {
    val variant = this
    variant.outputs.forEach { output ->
        val abi = output.filters.find { it.filterType == "ABI" }?.identifier
        val abiVersionCode = if (abi == null) 0 else abiCodes[abi]
        if (abiVersionCode != null) {
            (output as ApkVariantOutputImpl).versionCodeOverride = variant.versionCode * 10 + abiVersionCode
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
