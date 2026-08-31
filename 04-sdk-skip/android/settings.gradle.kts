pluginManagement {
    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
    }
}

dependencyResolutionManagement {
    repositoriesMode.set(RepositoriesMode.FAIL_ON_PROJECT_REPOS)
    repositories {
        google()
        mavenCentral()
        val skipMaven = file("../sdks/out/maven")
        if (skipMaven.isDirectory) {
            maven { url = uri(skipMaven) }
        }
        val releaseMaven = file("../../tools/out/release/skip/maven")
        if (releaseMaven.isDirectory) {
            maven { url = uri(releaseMaven) }
        }
    }
}

rootProject.name = "FightDeckNative"
include(":app")
