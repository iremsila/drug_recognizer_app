plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android") // <- kotlin-android yerine bu
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.example.drug_recogniz_app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = "27.0.12077973"

    defaultConfig {
        applicationId = "com.example.drug_recogniz_app"
        minSdk = flutter.minSdkVersion       // en az 21 olmalı
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        isCoreLibraryDesugaringEnabled = true   // <-- Kotlin DSL
    }

    kotlinOptions {
        jvmTarget = "17"                        // <-- Kotlin DSL (çift tırnak)
    }

    buildTypes {
        release {
            // imza ayarın yoksa debug imzası ile
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

dependencies {
    // Desugaring kütüphanesi (zorunlu)
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.0.4")
    // Kotlin stdlib eklemene gerek yok; plugin sağlıyor
}

flutter {
    source = "../.."
}
