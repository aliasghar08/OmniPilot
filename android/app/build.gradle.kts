import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    // START: FlutterFire Configuration
    id("com.google.gms.google-services")
    // END: FlutterFire Configuration
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// ============================================================================
// QUANTUM FORGE / OMNIPILOT ANTI-REPUBLISHING & RELEASE SIGNATURE LOCK
// Copyright (c) 2026 Ali Asghar <aliasgharinnocent@yahoo.com>. All Rights Reserved.
// Blocks unauthorized Play Store / production release bundles (assembleRelease /
// bundleRelease) unless the owner's private signing keystore (`key.properties`)
// is present and verified.
// ============================================================================
val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
val hasOwnerReleaseKeystore = keystorePropertiesFile.exists()
if (hasOwnerReleaseKeystore) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

gradle.taskGraph.whenReady {
    val requestedTasks = gradle.startParameter.taskNames.map { it.lowercase() }
    val isStorePublishTask = requestedTasks.any { task ->
        task.contains("bundle") || (task.contains("publish") && !task.contains("local"))
    }
    if (isStorePublishTask && !hasOwnerReleaseKeystore) {
        throw GradleException(
            """
            ================================================================================
            SECURITY & DMCA OWNERSHIP LOCK — UNAUTHORIZED RELEASE STORE PUBLISH BLOCKED
            ================================================================================
            OmniPilot is the proprietary intellectual property of:
              Owner : Ali Asghar
              Email : aliasgharinnocent@yahoo.com
              Notice: DMCA Protected · All Commercial & Store Distribution Rights Reserved

            Production store release bundles (bundleRelease / publish) require the owner's
            private hardware-backed signing keystore (`android/key.properties`).
            Unauthorized Play Store / App Store publishing is strictly prohibited.
            ================================================================================
            """.trimIndent()
        )
    }
}

android {
    namespace = "com.attendancecopilot.attendance_copilot"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "com.attendancecopilot.attendance_copilot"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (hasOwnerReleaseKeystore) {
            create("release") {
                keyAlias = keystoreProperties.getProperty("keyAlias")
                keyPassword = keystoreProperties.getProperty("keyPassword")
                storeFile = keystoreProperties.getProperty("storeFile")?.let { file(it) }
                storePassword = keystoreProperties.getProperty("storePassword")
            }
        }
    }

    buildTypes {
        release {
            signingConfig = if (hasOwnerReleaseKeystore) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
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
