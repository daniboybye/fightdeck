plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.plugin.compose")
}

android {
    namespace = "com.fightdeck.rust"
    compileSdk = 37

    defaultConfig {
        applicationId = "com.fightdeck.rust"
        minSdk = 28
        targetSdk = 37
        versionCode = 1
        versionName = "1.0"
        testInstrumentationRunner = "androidx.test.runner.AndroidJUnitRunner"
    }

    buildTypes {
        release {
            // R8 is on by default: release is the variant that gets measured and the one that
            // would ship. `-PfightdeckMinify=false` turns it off so the shrinker's own
            // contribution can be measured without editing this file — the same reason the
            // feature sets are flavours and not `#if`s.
            val minify = project.findProperty("fightdeckMinify") != "false"
            isMinifyEnabled = minify
            isShrinkResources = minify
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro",
            )
            // Release is what gets measured, so it has to be installable: an unsigned APK
            // cannot be smoke-tested, and a shipped APK carries a signature block anyway.
            signingConfig = signingConfigs.getByName("debug")
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

    // All three UniFFI namespaces call into libfightdeck.so via JNA — must resolve the AAR so
    // libjnidispatch.so ships for every ABI, not the JVM jar that looks on the classpath.
    // Version pinned in versions.lock.toml (android.jna): 5.19.1 is 16 KB aligned.
    implementation("net.java.dev.jna:jna:5.19.1") {
        artifact {
            type = "aar"
        }
    }

    debugImplementation("androidx.compose.ui:ui-tooling")

    testImplementation("junit:junit:4.13.2")
    testImplementation("org.jetbrains.kotlin:kotlin-test-junit:2.4.10")
    testImplementation("org.jetbrains.kotlinx:kotlinx-coroutines-test:1.10.2")
    // The unit tests drive the generated bindings on the JVM. The AAR above carries only the
    // Android dispatch libraries; the plain jar brings the one for the machine running Gradle.
    testImplementation("net.java.dev.jna:jna:5.19.1")
    // android.jar stubs org.json out; the fixtures are JSON.
    testImplementation("org.json:json:20251224")
}

// UniFFI's Kotlin reaches Rust through JNA, which loads a library by name from wherever
// jna.library.path points. So the unit tests need no emulator: the same crates built for the
// host give the bindings a libfightdeck to call, and the tests check the boundary itself —
// money as strings, enums, optionals, typed errors — rather than the rules the Rust tests
// already cover.
val rustSdks = rootProject.file("../sdks")
// Studio does not inherit a shell's PATH, so rustup's default location is tried first.
val cargo = File(System.getProperty("user.home"), ".cargo/bin/cargo")
    .takeIf { it.canExecute() }?.path ?: "cargo"
val buildHostRust = tasks.register<Exec>("buildHostRust") {
    description = "Builds libfightdeck for the host so the JVM unit tests can load it."
    workingDir = rustSdks
    commandLine(cargo, "build", "-p", "fightdeck-android")
}

tasks.withType<Test>().configureEach {
    dependsOn(buildHostRust)
    systemProperty("jna.library.path", File(rustSdks, "target/debug").absolutePath)
    systemProperty("fightdeck.dataset.root", rootProject.file("../../dataset").absolutePath)
    systemProperty("fightdeck.fixtures.root", rootProject.file("../../contract/fixtures").absolutePath)
}

// The apps read the dataset from /data/local/tmp rather than bundling it: 4.7 MB of fixtures
// inside the APK would land in every size measurement. That makes a device stateful, so
// pressing Run in Android Studio on a fresh emulator would otherwise reach
// DatasetLocator.NotFoundException. Every debug build and every install puts it there first,
// and says nothing when no device is attached — a build must not fail for want of an emulator.
val datasetDir = rootProject.file("../../dataset")
// Android Studio and the terminal do not agree on how the SDK is found: Studio writes
// local.properties, a shell exports ANDROID_HOME, and neither is guaranteed to put
// platform-tools on PATH. All three are tried so Run works either way.
val adbExecutable = listOfNotNull(
    rootProject.file("local.properties").takeIf { it.isFile }
        ?.readLines()
        ?.firstOrNull { it.startsWith("sdk.dir=") }
        ?.substringAfter('=')
        ?.trim(),
    System.getenv("ANDROID_HOME"),
    System.getenv("ANDROID_SDK_ROOT"),
).map { File(it, "platform-tools/adb") }.firstOrNull { it.canExecute() }
val remoteDataset = "/data/local/tmp/fightdeck/dataset"

val pushDataset = tasks.register("pushDataset") {
    description = "Copies the repo dataset onto every attached device."
    doLast {
        val adb = adbExecutable
        if (!datasetDir.isDirectory || adb == null) return@doLast
        val serials = ProcessBuilder(adb.path, "devices")
            .redirectErrorStream(true)
            .start()
            .inputStream
            .bufferedReader()
            .readLines()
            .mapNotNull { line ->
                line.split('\t').takeIf { it.size == 2 && it[1].trim() == "device" }?.first()
            }
        serials.forEach { serial ->
            // Removed first: pushing onto a directory that already exists nests it as
            // dataset/dataset, and the app then keeps reading the stale copy one level up.
            ProcessBuilder(adb.path, "-s", serial, "shell", "rm", "-rf", remoteDataset)
                .start()
                .waitFor()
            ProcessBuilder(adb.path, "-s", serial, "push", datasetDir.path, remoteDataset)
                .redirectOutput(ProcessBuilder.Redirect.DISCARD)
                .start()
                .waitFor()
            logger.lifecycle("dataset -> $serial")
        }
    }
}

// Studio's Run does not go through the `install` task — it builds and deploys with its own
// installer — so the packaging tasks are hooked too. Gradle runs a finalizer once per build no
// matter how many tasks name it.
tasks.matching { task ->
    val debugBuild = task.name.endsWith("Debug") &&
        (task.name.startsWith("assemble") || task.name.startsWith("package"))
    debugBuild || task.name.startsWith("install")
}.configureEach {
    finalizedBy(pushDataset)
}
