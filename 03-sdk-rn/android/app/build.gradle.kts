plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.plugin.compose")
    id("org.jetbrains.kotlin.plugin.serialization")
    id("com.facebook.react")
}

val rnEntryRoot = rootProject.file("../sdks/core/src/runtime")
val rnActiveEntry = rnEntryRoot.resolve("index.active.js")

react {
    root = file("../../")
    entryFile = rnActiveEntry
    debuggableVariants.set(emptyList())
    autolinkLibrariesWithApp()
}

// Codegen runs here as well as in the runtime library, on the same package.json, because the
// JNI half of the spec has to be compiled into this app's libappmodules.so. The Java half is
// already inside the runtime AAR, and a second copy of the same class would not dex.
val codegenJavaHalf = layout.buildDirectory.dir("generated/source/codegen/java")
tasks.named("generateCodegenArtifactsFromSchema") {
    doLast { codegenJavaHalf.get().asFile.deleteRecursively() }
}

val demoAssetsDir = file("build/generated/demo-assets")

android {
    namespace = "com.fightdeck.baseline"
    compileSdk = 37

    defaultConfig {
        // Distinct from the other hosts so all five approaches can be installed side by side.
        applicationId = "com.fightdeck.sdk.rn"
        minSdk = 28
        targetSdk = 37
        versionCode = 1
        versionName = "1.0"
        testInstrumentationRunner = "androidx.test.runner.AndroidJUnitRunner"
    }

    flavorDimensions += "features"
    productFlavors {
        create("runtime") {
            dimension = "features"
            buildConfigField("String", "FEATURE_MODE", "\"runtime\"")
        }
        create("deposit") {
            dimension = "features"
            buildConfigField("String", "FEATURE_MODE", "\"deposit\"")
        }
        create("both") {
            dimension = "features"
            buildConfigField("String", "FEATURE_MODE", "\"both\"")
        }
        create("all") {
            dimension = "features"
            isDefault = true
            buildConfigField("String", "FEATURE_MODE", "\"all\"")
        }
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
        buildConfig = true
    }

    testOptions {
        unitTests.isIncludeAndroidResources = true
    }

    sourceSets {
        getByName("main") {
            assets.srcDir(demoAssetsDir)
        }
    }
}

fun syncRnEntry(flavor: String) {
    val source = when (flavor) {
        "runtime" -> rnEntryRoot.resolve("index.runtime.js")
        "deposit" -> rnEntryRoot.resolve("index.deposit.js")
        "both" -> rnEntryRoot.resolve("index.js")
        else -> rnEntryRoot.resolve("index.all.js")
    }
    source.copyTo(rnActiveEntry, overwrite = true)
}

androidComponents {
    onVariants { variant ->
        val flavor = variant.productFlavors.firstOrNull { it.first == "features" }?.second ?: "both"
        val capitalized = variant.name.replaceFirstChar { if (it.isLowerCase()) it.titlecase() else it.toString() }
        tasks.register("syncRnEntry$capitalized") {
            doLast { syncRnEntry(flavor) }
        }
        tasks.matching { it.name == "createBundle${capitalized}JsAndAssets" }.configureEach {
            dependsOn("syncRnEntry$capitalized")
        }
    }
}

val syncDemoAssets = tasks.register<Copy>("syncDemoAssets") {
    from(rootProject.file("../../dataset"))
    from(rootProject.file("../../shared-ui-spec/tokens.json"))
    into(demoAssetsDir)
}

tasks.named("preBuild") {
    dependsOn(syncDemoAssets)
}

dependencies {
    val sdkRoot = rootProject.file("../sdks")
    val rnRuntime = files(sdkRoot.resolve("core/out/FightDeckRNRuntime.aar"))
    val depositSdk = files(sdkRoot.resolve("deposit/out/DepositSDK.aar"))
    val betslipSdk = files(sdkRoot.resolve("betslip/out/BetslipSDK.aar"))
    val fighterSdk = files(sdkRoot.resolve("fighter/out/FighterSDK.aar"))

    listOf("runtime", "deposit", "both", "all").forEach { flavor ->
        "${flavor}Implementation"(rnRuntime)
    }
    listOf("deposit", "both", "all").forEach { flavor ->
        "${flavor}Implementation"(depositSdk)
    }
    listOf("both", "all").forEach { flavor ->
        "${flavor}Implementation"(betslipSdk)
    }
    "allImplementation"(fighterSdk)

    listOf("runtime", "deposit", "both", "all").forEach { flavor ->
        "${flavor}Implementation"("com.facebook.react:react-android")
        "${flavor}Implementation"("com.facebook.react:hermes-android")
    }

    val composeBom = platform("androidx.compose:compose-bom:2026.08.00")
    implementation(composeBom)
    androidTestImplementation(composeBom)

    implementation("com.google.android.material:material:1.12.0")

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
    debugImplementation("androidx.compose.ui:ui-test-manifest")

    androidTestImplementation(composeBom)
    androidTestImplementation("androidx.compose.ui:ui-test-junit4")
    androidTestImplementation("androidx.test.uiautomator:uiautomator:2.3.0")
    androidTestImplementation("androidx.test.ext:junit:1.2.1")
    androidTestImplementation("androidx.test:runner:1.6.1")
    androidTestImplementation("androidx.test.espresso:espresso-core:3.7.0")

    testImplementation("junit:junit:4.13.2")
    testImplementation("org.jetbrains.kotlin:kotlin-test-junit:2.4.10")
    testImplementation("org.jetbrains.kotlinx:kotlinx-coroutines-test:1.10.2")
}

tasks.withType<Test>().configureEach {
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
