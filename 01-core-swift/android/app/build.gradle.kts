plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.plugin.compose")
    id("org.jetbrains.kotlin.plugin.serialization")
}

android {
    namespace = "com.fightdeck.swiftcore"
    compileSdk = 37

    defaultConfig {
        applicationId = "com.fightdeck.coreswift"
        minSdk = 28
        targetSdk = 37
        versionCode = 1
        versionName = "1.0"
        testInstrumentationRunner = "androidx.test.runner.AndroidJUnitRunner"
    }

    buildTypes {
        release {
            isMinifyEnabled = false
        }
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    buildFeatures {
        compose = true
    }

    testOptions {
        unitTests.isIncludeAndroidResources = true
    }
}

dependencies {
    // The cross-compiled Swift core: jni/<abi>/libfightcore.so plus libSwiftJava.so and the
    // Swift runtime closure, classes.jar with the jextract JNI bindings, and the
    // org.swift.swiftkit.core runtime in libs/. Build it with
    // `swiftly run ./build-aar.sh +6.3.3` in sdks/core; it is not a committed artifact.
    val fightCoreAar = rootProject.file("../sdks/core/out/fightcore.aar")
    require(fightCoreAar.exists()) {
        "Missing $fightCoreAar — run `swiftly run ./build-aar.sh +6.3.3` in 01-core-swift/sdks/core"
    }
    implementation(files(fightCoreAar))

    val composeBom = platform("androidx.compose:compose-bom:2026.08.00")
    implementation(composeBom)
    androidTestImplementation(composeBom)

    implementation("androidx.core:core-ktx:1.17.0")
    implementation("androidx.activity:activity-compose:1.12.2")
    implementation("androidx.lifecycle:lifecycle-runtime-compose:2.10.0")
    implementation("androidx.lifecycle:lifecycle-viewmodel-compose:2.10.0")
    implementation("androidx.navigation:navigation-compose:2.9.7")
    implementation("androidx.compose.ui:ui")
    implementation("androidx.compose.ui:ui-tooling-preview")
    implementation("androidx.compose.material3:material3")
    implementation("androidx.compose.material3:material3-adaptive-navigation-suite")
    implementation("androidx.compose.animation:animation")
    implementation("androidx.compose.material:material-icons-extended")

    implementation("io.coil-kt.coil3:coil-compose:3.3.0")
    implementation("io.coil-kt.coil3:coil-network-okhttp:3.3.0")

    implementation("org.jetbrains.kotlinx:kotlinx-serialization-json:1.9.0")

    debugImplementation("androidx.compose.ui:ui-tooling")

    testImplementation("junit:junit:4.13.2")
    testImplementation("org.jetbrains.kotlin:kotlin-test-junit:2.4.10")
    testImplementation("org.jetbrains.kotlinx:kotlinx-coroutines-test:1.10.2")

    // The fixtures moved from unit tests to instrumented tests when the Kotlin port was
    // deleted: a JVM on macOS cannot dlopen an Android ELF, so the only place the Swift
    // core can be asserted against the contract is a device or emulator.
    androidTestImplementation("androidx.test.ext:junit:1.3.0")
    androidTestImplementation("androidx.test:runner:1.7.0")
    androidTestImplementation("org.jetbrains.kotlin:kotlin-test-junit:2.4.10")
}

tasks.withType<Test>().configureEach {
    systemProperty("fightdeck.dataset.root", rootProject.file("../../dataset").absolutePath)
    systemProperty("fightdeck.fixtures.root", rootProject.file("../../contract/fixtures").absolutePath)
}
