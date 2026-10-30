import groovy.json.JsonOutput
import groovy.json.JsonSlurper

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Developer/deployment configuration is compiled into Android builds, including
// ordinary IDE / `flutter run` launches without Dart defines. Keep the local JSON untracked.
val algorithmConfig = rootProject.file("../config/algorithm.local.json")
val localAlgorithmOrigin = if (algorithmConfig.isFile) {
    val values = JsonSlurper().parse(algorithmConfig) as Map<*, *>
    (values["API_BASE_URL"] ?: values["ALGORITHM_BASE_URL"] ?: "").toString().trim()
} else ""
val algorithmOrigin = providers.environmentVariable("API_BASE_URL").orNull?.trim()
    ?.takeIf { it.isNotEmpty() } ?: localAlgorithmOrigin

android {
    namespace = "com.guitarpal.guitar_pal"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion
    buildFeatures { buildConfig = true }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "com.guitarpal.guitar_pal"
        buildConfigField("String", "ALGORITHM_API_BASE_URL", JsonOutput.toJson(algorithmOrigin))
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        // Uses the version code from pubspec.yaml. When using split APKs, 1000 * ABI_VERSION
        // is added automatically by Flutter. (https://developer.android.com/studio/build/configure-apk-splits#configure-APK-versions)
        // You can force using the value of versionCode by specifying the `-P force-version-code-ignoring-abi=true`
        // flag during build.
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
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
