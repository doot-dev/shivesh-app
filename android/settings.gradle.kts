pluginManagement {
    val flutterSdkPath =
        run {
            val properties = java.util.Properties()
            file("local.properties").inputStream().use { properties.load(it) }
            val flutterSdkPath = properties.getProperty("flutter.sdk")
            require(flutterSdkPath != null) { "flutter.sdk not set in local.properties" }
            flutterSdkPath
        }

    includeBuild("$flutterSdkPath/packages/flutter_tools/gradle")

    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
    }
}

plugins {
    id("dev.flutter.flutter-plugin-loader") version "1.0.0"
    // AGP 8.9.x cannot parse a Java 25 version string and dies with a bare
    // `IllegalArgumentException: 25.0.2` during Gradle configuration. 8.13.0 is
    // the first release that handles JDK 25, which is what ships with the
    // current Android Studio JBR. Requires Gradle >= 8.13 (see gradle-wrapper).
    id("com.android.application") version "8.13.0" apply false
    id("org.jetbrains.kotlin.android") version "2.2.21" apply false
    id("com.google.gms.google-services") version "4.4.2" apply false
}

include(":app")
