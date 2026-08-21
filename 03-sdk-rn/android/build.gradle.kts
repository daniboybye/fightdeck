import com.android.build.api.dsl.LibraryExtension

extra["minSdkVersion"] = 28
extra["minSdk"] = 28
extra["compileSdkVersion"] = 37
extra["targetSdkVersion"] = 37

plugins {
    id("com.android.application") version "9.3.1" apply false
    id("org.jetbrains.kotlin.android") version "2.4.10" apply false
    id("org.jetbrains.kotlin.plugin.compose") version "2.4.10" apply false
    id("org.jetbrains.kotlin.plugin.serialization") version "2.4.10" apply false
    id("com.facebook.react") apply false
}

subprojects {
    plugins.withId("com.android.library") {
        extensions.configure<LibraryExtension> {
            compileSdk = 37
            defaultConfig {
                minSdk = maxOf(minSdk ?: 24, 24)
            }
        }
    }
}
