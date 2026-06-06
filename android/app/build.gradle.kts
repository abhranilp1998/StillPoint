import org.gradle.api.execution.TaskExecutionGraph
import org.gradle.kotlin.dsl.closureOf
import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val releaseKeystoreProperties = Properties()
val releaseKeystorePropertiesFile = rootProject.file("key.properties")
if (releaseKeystorePropertiesFile.exists()) {
    releaseKeystorePropertiesFile.inputStream().use { releaseKeystoreProperties.load(it) }
}

fun releaseSigningValue(name: String): String? =
    releaseKeystoreProperties.getProperty(name)?.takeIf { it.isNotBlank() }

val releaseSigningKeys = listOf("storeFile", "storePassword", "keyAlias", "keyPassword")
val hasReleaseSigning = releaseSigningKeys.all { releaseSigningValue(it) != null }

gradle.taskGraph.whenReady(
    closureOf<TaskExecutionGraph> {
        val buildingRelease = allTasks.any { task -> task.name.contains("Release") }
        if (buildingRelease && !hasReleaseSigning) {
            throw GradleException(
                "Release APKs must use the stable sideload signing key. " +
                    "Create android/key.properties from android/key.properties.example before building release."
            )
        }
    }
)

android {
    namespace = "com.privatewellness.stillpoint"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        applicationId = "com.privatewellness.stillpoint"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("release") {
            if (hasReleaseSigning) {
                storeFile = file(releaseSigningValue("storeFile")!!)
                storePassword = releaseSigningValue("storePassword")!!
                keyAlias = releaseSigningValue("keyAlias")!!
                keyPassword = releaseSigningValue("keyPassword")!!
            }
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("release")
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.5")
}
