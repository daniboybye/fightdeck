pluginManagement {
    includeBuild("../node_modules/@react-native/gradle-plugin")
    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
    }
}

plugins {
    id("com.facebook.react.settings")
}

extensions.configure<com.facebook.react.ReactSettingsExtension> {
    autolinkLibrariesFromCommand()
}

dependencyResolutionManagement {
    repositoriesMode.set(RepositoriesMode.PREFER_PROJECT)
    repositories {
        google()
        mavenCentral()
    }
}

rootProject.name = "FightDeckRN"
include(":app")
include(":fightdeck-rn-runtime")
project(":fightdeck-rn-runtime").projectDir = file("../sdks/core/android/runtime")
include(":deposit-sdk")
project(":deposit-sdk").projectDir = file("../sdks/deposit/android")
include(":betslip-sdk")
project(":betslip-sdk").projectDir = file("../sdks/betslip/android")
include(":fighter-sdk")
project(":fighter-sdk").projectDir = file("../sdks/fighter/android")
includeBuild("../node_modules/@react-native/gradle-plugin")
