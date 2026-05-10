plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val jobHunterKeystorePassword: String? = System.getenv("JOB_HUNTER_KEYSTORE_PASSWORD")
val jobHunterKeyPassword: String? = System.getenv("JOB_HUNTER_KEY_PASSWORD") ?: jobHunterKeystorePassword

android {
    namespace = "com.vinoth.jobhunter"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        isCoreLibraryDesugaringEnabled = true
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        applicationId = "com.vinoth.jobhunter"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("release") {
            if (jobHunterKeystorePassword != null) {
                keyAlias = "job-hunter"
                storeFile = file("job-hunter.keystore")
                storePassword = jobHunterKeystorePassword
                keyPassword = jobHunterKeyPassword
            }
        }
    }

    buildTypes {
        release {
            signingConfig = if (jobHunterKeystorePassword != null) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
        }
        debug {
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}
