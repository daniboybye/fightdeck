plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.plugin.compose")
    id("org.jetbrains.kotlin.plugin.serialization")
    id("com.facebook.react")
}

val fightdeckLocalSdk =
    (project.findProperty("fightdeckLocalSdk") as String?)?.toBoolean()
        ?: (System.getenv("FIGHTDECK_LOCAL_SDK") == "1")

val releaseAarDir = rootProject.file("../../tools/out/release/rn")
val rnEntryRoot = rootProject.file("../sdks/core/src/runtime")
val rnActiveEntry = rnEntryRoot.resolve("index.active.js")

react {
    root = file("../../")
    entryFile = rnActiveEntry
    debuggableVariants.set(emptyList())
    autolinkLibrariesWithApp()
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
            isMinifyEnabled = false
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
    val rnRuntime = if (fightdeckLocalSdk) project(":fightdeck-rn-runtime") else files(releaseAarDir.resolve("FightDeckRNRuntime.aar"))
    val depositSdk = if (fightdeckLocalSdk) project(":deposit-sdk") else files(releaseAarDir.resolve("DepositSDK.aar"))
    val betslipSdk = if (fightdeckLocalSdk) project(":betslip-sdk") else files(releaseAarDir.resolve("BetslipSDK.aar"))
    val fighterSdk = if (fightdeckLocalSdk) project(":fighter-sdk") else files(releaseAarDir.resolve("FighterSDK.aar"))

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

    if (fightdeckLocalSdk) {
        listOf("runtime", "deposit", "both", "all").forEach { flavor ->
            "${flavor}Implementation"("com.facebook.react:react-android")
            "${flavor}Implementation"("com.facebook.react:hermes-android")
        }
    } else {
        listOf("runtime", "deposit", "both", "all").forEach { flavor ->
            "${flavor}Implementation"("com.facebook.react:react-android")
            "${flavor}Implementation"("com.facebook.react:hermes-android")
        }
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
