import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Upload key for Google Play: android/key.properties (local) or the CI secrets
// ANDROID_KEYSTORE_PATH / ANDROID_KEYSTORE_PASSWORD / ANDROID_KEY_ALIAS / ANDROID_KEY_PASSWORD.
val keyProps = Properties().apply {
    val f = rootProject.file("key.properties")
    if (f.exists()) f.inputStream().use { load(it) }
}
fun signing(name: String, env: String): String? = keyProps.getProperty(name) ?: System.getenv(env)
val storePath = signing("storeFile", "ANDROID_KEYSTORE_PATH")

android {
    namespace = "com.chagil.kahol_yavan_radio_app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // The id of the existing app on Google Play, so this version replaces it.
        applicationId = "com.chagil.kahol_yavan_radio_app"
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

    signingConfigs {
        if (storePath != null) {
            create("upload") {
                storeFile = file(storePath)
                storePassword = signing("storePassword", "ANDROID_KEYSTORE_PASSWORD")
                keyAlias = signing("keyAlias", "ANDROID_KEY_ALIAS")
                keyPassword = signing("keyPassword", "ANDROID_KEY_PASSWORD")
            }
        }
    }

    buildTypes {
        release {
            // Without the upload key (a local test build) the debug key is used; Google Play rejects that.
            signingConfig = signingConfigs.findByName("upload") ?: signingConfigs.getByName("debug")
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

// Push notifications: only when the Firebase file is there (the app works without it).
if (file("google-services.json").exists()) {
    apply(plugin = "com.google.gms.google-services")
}
