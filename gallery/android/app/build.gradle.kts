plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val testLabAbi = providers.gradleProperty("mediapipe.testLabAbi").orNull

android {
    namespace = "com.example.mediapipe_gallery"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // The gallery is a sample that is not distributed through a store, so it
        // keeps Flutter's template application ID. The same ID is in the Kotlin
        // package, androidTest, linux/CMakeLists.txt and the tool scripts.
        applicationId = "com.example.mediapipe_gallery"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        // Google's MediaPipe Android libraries need Android 9.
        minSdk = maxOf(28, flutter.minSdkVersion)
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        testInstrumentationRunner = "androidx.test.runner.AndroidJUnitRunner"
        if (testLabAbi != null) {
            require(testLabAbi == "arm64-v8a" || testLabAbi == "armeabi-v7a")
            ndk { abiFilters.clear(); abiFilters.add(testLabAbi) }
        }
    }

    buildTypes {
        release {
            // Debug-key signing on purpose: release builds need no keystore, and
            // the gallery is not distributed through a store.
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

dependencies {
    androidTestImplementation("androidx.test:runner:1.3.0")
    androidTestImplementation("androidx.test:rules:1.2.0")
    androidTestImplementation("androidx.test.espresso:espresso-core:3.3.0")
}
