import java.io.File
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
val repositoryRootDir = rootProject.projectDir.parentFile
val releaseKeystorePropertiesCandidates = listOf(
    rootProject.file("key.properties"),
    File(repositoryRootDir, "keys/key.properties")
)
val releaseKeystorePropertiesFile = releaseKeystorePropertiesCandidates.firstOrNull { it.exists() }
if (releaseKeystorePropertiesFile != null) {
    releaseKeystorePropertiesFile.inputStream().use { releaseKeystoreProperties.load(it) }
}

fun releaseSigningValue(name: String): String? =
    releaseKeystoreProperties.getProperty(name)?.takeIf { it.isNotBlank() }

fun releaseSigningFile(path: String): File {
    val requestedFile = File(path)
    if (requestedFile.isAbsolute) {
        return requestedFile
    }

    val propertiesDirectory = releaseKeystorePropertiesFile?.parentFile ?: rootProject.projectDir
    return File(propertiesDirectory, path)
}

val releaseSigningKeys = listOf("storeFile", "storePassword", "keyAlias", "keyPassword")
val hasReleaseSigningProperties = releaseSigningKeys.all { releaseSigningValue(it) != null }
val releaseStoreFile = releaseSigningValue("storeFile")?.let { releaseSigningFile(it) }
val hasReleaseSigning = hasReleaseSigningProperties && releaseStoreFile?.exists() == true

fun releaseSigningFailureMessage(): String {
    val setupHelp =
        "Create android/key.properties from android/key.properties.example, " +
            "or sync keys/key.properties from keys/key.properties.example. " +
            "When using keys/key.properties, storeFile is relative to the keys folder unless absolute."

    return when {
        releaseKeystorePropertiesFile == null ->
            "Release APKs and bundles must use the stable StillPoint signing key. $setupHelp"
        !hasReleaseSigningProperties ->
            "Release signing file ${releaseKeystorePropertiesFile.path} must define ${releaseSigningKeys.joinToString()}. $setupHelp"
        releaseStoreFile?.exists() != true ->
            "Release keystore file was not found at ${releaseStoreFile?.path}. $setupHelp"
        else ->
            "Release APKs and bundles must use the stable StillPoint signing key. $setupHelp"
    }
}

gradle.taskGraph.whenReady(
    closureOf<TaskExecutionGraph> {
        val buildingRelease = allTasks.any { task -> task.name.contains("Release") }
        if (buildingRelease && !hasReleaseSigning) {
            throw GradleException(releaseSigningFailureMessage())
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
                storeFile = releaseStoreFile
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
