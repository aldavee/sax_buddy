import java.io.File
import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val keystorePropertiesFile = rootProject.file("key.properties")
val keystoreProperties = Properties()
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

val rawKeystoreEnvPath = System.getenv("ANDROID_KEYSTORE_PATH")?.takeIf { it.isNotBlank() }
val releaseKeystorePath = rawKeystoreEnvPath?.let { raw ->
    val direct = file(raw)
    val fromRoot = rootProject.file(raw)
    val fromRepo = rootProject.projectDir.parentFile?.let { File(it, raw) }
    when {
        direct.exists() -> direct.absolutePath
        fromRoot.exists() -> fromRoot.absolutePath
        fromRepo != null && fromRepo.exists() -> fromRepo.absolutePath
        else -> raw
    }
} ?: keystoreProperties.getProperty("storeFile")?.let { rootProject.file(it).absolutePath }
val releaseKeystorePassword = System.getenv("ANDROID_KEYSTORE_PASSWORD")
    ?: keystoreProperties.getProperty("storePassword")
val releaseKeyAlias = System.getenv("ANDROID_KEY_ALIAS")
    ?: keystoreProperties.getProperty("keyAlias")
val releaseKeyPassword = System.getenv("ANDROID_KEY_PASSWORD")
    ?: keystoreProperties.getProperty("keyPassword")
val hasReleaseSigning =
    !releaseKeystorePath.isNullOrBlank() &&
        !releaseKeystorePassword.isNullOrBlank() &&
        !releaseKeyAlias.isNullOrBlank() &&
        !releaseKeyPassword.isNullOrBlank()

android {
    namespace = "com.aldavelabs.sax_buddy"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "com.aldavelabs.sax_buddy"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (hasReleaseSigning) {
            create("release") {
                storeFile = file(releaseKeystorePath!!)
                storePassword = releaseKeystorePassword
                keyAlias = releaseKeyAlias
                keyPassword = releaseKeyPassword
                enableV1Signing = true
                enableV2Signing = true
                enableV3Signing = true
            }
        }
    }

    buildTypes {
        debug {
            if (hasReleaseSigning) {
                signingConfig = signingConfigs.getByName("release")
            }
        }
        release {
            signingConfig = if (hasReleaseSigning) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
            isMinifyEnabled = false
            isShrinkResources = false
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
