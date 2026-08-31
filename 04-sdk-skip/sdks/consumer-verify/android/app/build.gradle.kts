plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.plugin.compose")
}

android {
    namespace = "fightdeck.skip.consumer"
    compileSdk = 37

    defaultConfig {
        applicationId = "fightdeck.skip.consumer"
        minSdk = 28
        targetSdk = 37
        versionCode = 1
        versionName = "1.0"
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    buildFeatures {
        compose = true
    }
}

dependencies {
    val skipVersion = "0.1.0-local"
    implementation("fightdeck.skip:FightDeckCoreBinary:$skipVersion")
    implementation("fightdeck.skip:FightDeckBetslipBinary:$skipVersion")

    implementation(platform("androidx.compose:compose-bom:2026.08.00"))
    implementation("androidx.activity:activity-compose:1.12.2")
    implementation("androidx.compose.ui:ui")
    implementation("androidx.compose.material3:material3")
}
