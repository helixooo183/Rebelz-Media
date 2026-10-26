import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services")
}

// === Release (upload) imzası =================================================
// Değerler iki kaynaktan okunur; ilk bulunan kullanılır:
//   1) android/key.properties  — yerel makine, .gitignore'da, repoya girmez
//        storeFile=upload-keystore.p12
//        storePassword=***
//        keyAlias=upload
//        keyPassword=***
//   2) ortam değişkenleri — CI (GitHub Actions secrets)
//        KEYSTORE_PATH / KEYSTORE_PASS / KEY_ALIAS / KEY_PASS
// İkisi de yoksa release derlemesi debug anahtarıyla imzalanır; derleme kırılmaz.
// storeFile yolu app modülüne göredir → android/app/upload-keystore.p12
val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    FileInputStream(keystorePropertiesFile).use { keystoreProperties.load(it) }
}

fun signingValue(propertyName: String, envName: String): String? =
    keystoreProperties.getProperty(propertyName) ?: System.getenv(envName)

val uploadStorePath: String? = signingValue("storeFile", "KEYSTORE_PATH")
val uploadStorePassword: String? = signingValue("storePassword", "KEYSTORE_PASS")
val uploadKeyAlias: String? = signingValue("keyAlias", "KEY_ALIAS")
val uploadKeyPassword: String? = signingValue("keyPassword", "KEY_PASS") ?: uploadStorePassword
val uploadStoreFile = uploadStorePath?.let { file(it) }
val hasUploadKey: Boolean = uploadStoreFile != null &&
    uploadStoreFile.exists() &&
    !uploadKeyAlias.isNullOrBlank() &&
    !uploadStorePassword.isNullOrBlank()

println(
    "Release imzası: " + if (hasUploadKey) {
        "upload keystore ($uploadStorePath, alias $uploadKeyAlias)"
    } else {
        "debug keystore (upload anahtarı yok: android/key.properties ya da KEYSTORE_* değişkenleri)"
    },
)

android {
    namespace = "com.rebelz.media"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.rebelz.media"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    // Upload imzası — yalnızca anahtar bulunduğunda tanımlanır.
    signingConfigs {
        if (hasUploadKey) {
            create("release") {
                storeFile = uploadStoreFile
                storePassword = uploadStorePassword
                keyAlias = uploadKeyAlias
                keyPassword = uploadKeyPassword
                storeType = "PKCS12"
            }
        }
    }

    buildTypes {
        release {
            // R8/AGP bellek tüketimini düşürmek için küçültme kapalı
            // (APK biraz daha büyük olur, işlev aynı).
            isMinifyEnabled = false
            isShrinkResources = false
            // Upload anahtarı varsa onunla, yoksa debug anahtarıyla imzala.
            signingConfig = if (hasUploadKey) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
        }
    }
}

flutter {
    source = "../.."
}
