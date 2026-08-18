import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// The Google Services plugin is only applied when a real google-services.json
// is present, so a fresh clone (without Firebase credentials) still builds.
if (file("google-services.json").exists()) {
    apply(plugin = "com.google.gms.google-services")
}

// Upload-key material is kept out of version control. When android/key.properties
// is absent (a fresh clone, or CI without secrets) the release build falls back to
// the debug key so `flutter build --release` still runs locally.
val keystoreProperties = Properties().apply {
    val file = rootProject.file("key.properties")
    if (file.exists()) file.inputStream().use { load(it) }
}
val hasUploadKey = keystoreProperties.getProperty("storeFile")?.let {
    rootProject.file(it).exists()
} ?: false

android {
    namespace = "bc.greenfggames.towerbuilder"
    // TZ §6 pins targetSdk = 35 / minSdk = 30; compileSdk stays high for plugin
    // compatibility (see .cursor/rules/gray_part_pitfalls.md §2).
    compileSdk = 37
    ndkVersion = flutter.ndkVersion

    compileOptions {
        // Required by flutter_local_notifications 22.x (uses java.time.*).
        // See .cursor/rules/gray_part_pitfalls.md §5.
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "bc.greenfggames.towerbuilder"
        minSdk = 30
        targetSdk = 35
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        resourceConfigurations += listOf("en")
    }

    signingConfigs {
        if (hasUploadKey) {
            create("upload") {
                keyAlias = keystoreProperties.getProperty("keyAlias")
                keyPassword = keystoreProperties.getProperty("keyPassword")
                storeFile = rootProject.file(keystoreProperties.getProperty("storeFile"))
                storePassword = keystoreProperties.getProperty("storePassword")
            }
        }
    }

    buildTypes {
        release {
            signingConfig = if (hasUploadKey) {
                signingConfigs.getByName("upload")
            } else {
                signingConfigs.getByName("debug")
            }
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro",
            )
        }
        // No debug applicationIdSuffix: the Firebase `google-services.json`
        // only registers `bc.greenfggames.towerbuilder`, and the Google
        // Services plugin fails the build when the debug variant lands on
        // a package name it does not know. If a separate debug client is
        // ever needed, add one in the Firebase console and reintroduce
        // the suffix here.
    }

    packaging {
        resources {
            excludes += setOf("META-INF/AL2.0", "META-INF/LGPL2.1")
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
    // Play Store Install Referrer — local IPC, no internet required.
    // Used by ReferrerScout to classify paid vs organic installs offline.
    implementation("com.android.installreferrer:installreferrer:2.2")
    // Coroutines for the suspendCancellableCoroutine bridge in ReferrerScout.
    implementation("org.jetbrains.kotlinx:kotlinx-coroutines-android:1.9.0")
}

flutter {
    source = "../.."
}
