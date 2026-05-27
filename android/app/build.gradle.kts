plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

import java.io.FileInputStream
import java.util.Properties
import org.gradle.api.GradleException

val keystorePropertiesFile = rootProject.file("key.properties")
val keystoreProperties = Properties()
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

val releaseSigningKeys = listOf("keyAlias", "keyPassword", "storeFile", "storePassword")
val requestedTaskNames = gradle.startParameter.taskNames
val isReleaseTaskRequested = requestedTaskNames.any { taskName ->
    taskName.contains("release", ignoreCase = true) ||
        taskName.contains("bundle", ignoreCase = true) ||
        taskName.contains("publish", ignoreCase = true)
}
val missingReleaseSigningKeys = releaseSigningKeys.filter {
    keystoreProperties.getProperty(it).isNullOrBlank()
}
val releaseStorePath = keystoreProperties.getProperty("storeFile")
val releaseStoreFile = if (releaseStorePath.isNullOrBlank()) {
    null
} else {
    rootProject.file(releaseStorePath)
}
val hasValidReleaseSigning =
    keystorePropertiesFile.exists() &&
        missingReleaseSigningKeys.isEmpty() &&
        releaseStoreFile?.exists() == true

android {
    namespace = "com.rannarjogot.app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.rannarjogot.app"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (hasValidReleaseSigning) {
            create("release") {
                keyAlias = keystoreProperties.getProperty("keyAlias")
                keyPassword = keystoreProperties.getProperty("keyPassword")
                storeFile = releaseStoreFile
                storePassword = keystoreProperties.getProperty("storePassword")
            }
        }
    }

    buildTypes {
        release {
            val releaseSigningConfig = signingConfigs.findByName("release")
            if (releaseSigningConfig != null) {
                signingConfig = releaseSigningConfig
            } else if (isReleaseTaskRequested) {
                val signingError = when {
                    !keystorePropertiesFile.exists() ->
                        "Missing key.properties at ${keystorePropertiesFile.path}."
                    missingReleaseSigningKeys.isNotEmpty() ->
                        "Missing required keys in key.properties: ${missingReleaseSigningKeys.joinToString(", ")}."
                    releaseStoreFile == null ->
                        "Missing storeFile entry in key.properties."
                    !releaseStoreFile.exists() ->
                        "Keystore file not found at ${releaseStoreFile.path}."
                    else ->
                        "Unknown signing configuration issue."
                }

                throw GradleException(
                    "Release signing is required for bundleRelease/appbundle builds. $signingError " +
                        "Create key.properties and point it to a real release keystore."
                )
            }
        }
    }
}

flutter {
    source = "../.."
}
