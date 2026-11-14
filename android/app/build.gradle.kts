plugins {
    id("com.android.application")
    id("com.google.gms.google-services")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.atharlayanqati.athr"
    compileSdk = 36
    ndkVersion = flutter.ndkVersion

    compileOptions {
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.atharlayanqati.athr"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        // Google Play requires API 36 for new mobile apps (since August 31, 2026).
        targetSdk = 36
        // Uses the version code from pubspec.yaml. When using split APKs, 1000 * ABI_VERSION
        // is added automatically by Flutter. (https://developer.android.com/studio/build/configure-apk-splits#configure-APK-versions)
        // You can force using the value of versionCode by specifying the `-P force-version-code-ignoring-abi=true`
        // flag during build.
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    // Only sign production bundles when the upload key is supplied securely.
    // Never use the Android debug key for a Play Store release.
    val uploadStoreFile = System.getenv("ATHR_UPLOAD_KEYSTORE")
    val uploadStorePassword = System.getenv("ATHR_UPLOAD_STORE_PASSWORD")
    val uploadKeyAlias = System.getenv("ATHR_UPLOAD_KEY_ALIAS")
    val uploadKeyPassword = System.getenv("ATHR_UPLOAD_KEY_PASSWORD")
    val hasUploadSigning = !uploadStoreFile.isNullOrBlank() &&
        !uploadStorePassword.isNullOrBlank() &&
        !uploadKeyAlias.isNullOrBlank() &&
        !uploadKeyPassword.isNullOrBlank()

    if (hasUploadSigning) {
        signingConfigs {
            create("playRelease") {
                storeFile = file(uploadStoreFile!!)
                storePassword = uploadStorePassword
                keyAlias = uploadKeyAlias
                keyPassword = uploadKeyPassword
            }
        }
    }

    buildTypes {
        release {
            if (hasUploadSigning) {
                signingConfig = signingConfigs.getByName("playRelease")
            } else if (System.getenv("ATHR_LOCAL_TEST_SIGNING") == "true") {
                // Sideload testing only; production bundles still require the upload key.
                signingConfig = signingConfigs.getByName("debug")
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

 dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
 }

// Copy the bundled, user-supplied MP3 adhan files into Android raw resources
// so scheduled notifications can use the same sounds as in-app previews.
tasks.register<Copy>("syncAdhanSounds") {
    from(rootProject.file("../assets/adhan")) {
        include("adhan_makkah.mp3", "adhan_afasy.mp3")
    }
    into(layout.projectDirectory.dir("src/main/res/raw"))
}
tasks.named("preBuild") {
    dependsOn("syncAdhanSounds")
}
