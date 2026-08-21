plugins {
    id("com.android.library")
}

android {
    namespace = "com.fightdeck.rn.runtime"
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
    implementation("androidx.appcompat:appcompat:1.7.0")
    implementation("com.google.android.material:material:1.12.0")
    implementation("com.facebook.react:react-android")
    implementation("com.facebook.react:hermes-android")
}
