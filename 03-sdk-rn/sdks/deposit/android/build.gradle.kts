plugins {
    id("com.android.library")
}

android {
    namespace = "com.fightdeck.sdk.deposit"
    compileSdk = 37

    defaultConfig {
        minSdk = 28
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }
}

dependencies {
    implementation(project(":fightdeck-rn-runtime"))
}
