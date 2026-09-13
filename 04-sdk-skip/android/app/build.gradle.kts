plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.plugin.compose")
    id("org.jetbrains.kotlin.plugin.serialization")
}

val fightdeckLocalSdk =
    (project.findProperty("fightdeckLocalSdk") as String?)?.toBoolean()
        ?: (System.getenv("FIGHTDECK_LOCAL_SDK") == "1")

val releaseAarDir = rootProject.file("../../tools/out/release/skip")
val skipMavenRepo = rootProject.file("../sdks/out/maven")
val skipSdkVersion = "0.1.0-local"
val useSkipMaven = fightdeckLocalSdk &&
    skipMavenRepo.resolve("fightdeck/skip/FightDeckCoreBinary/$skipSdkVersion").isDirectory

fun skipCoreAars(local: Boolean): Array<File> {
    if (local) {
        val coreOut = rootProject.file("../sdks/core/out")
        return coreOut.listFiles { f -> f.extension == "aar" }?.sortedBy { it.name }?.toTypedArray()
            ?: emptyArray()
    }
    return releaseAarDir.listFiles { f ->
        f.name.startsWith("FightDeckCore") ||
            f.name.startsWith("SkipFoundation") ||
            f.name.startsWith("SkipLib") ||
            f.name.startsWith("SkipUnit")
    }?.sortedBy { it.name }?.toTypedArray() ?: emptyArray()
}

// Only the module's own AAR: the Skip runtime AARs next to it in events/out are the same ones
// core already contributes, and two copies on the classpath is a duplicate-class failure.
fun skipEventsAar(local: Boolean): File? {
    if (local) {
        return rootProject.file("../sdks/events/out/FightDeckEvents-release.aar").takeIf { it.isFile }
    }
    return releaseAarDir.resolve("FightDeckEvents-release.aar").takeIf { it.isFile }
}

fun skipDepositFeatureAars(local: Boolean): Array<File> {
    if (local) {
        val out = rootProject.file("../sdks/deposit/out")
        return arrayOf(
            out.resolve("FightDeckDeposit-release.aar"),
            out.resolve("SkipModel-release.aar"),
            out.resolve("SkipUI-release.aar"),
        ).filter { it.isFile }.toTypedArray()
    }
    return arrayOf(
        releaseAarDir.resolve("FightDeckDeposit-release.aar"),
        releaseAarDir.resolve("SkipModel-release.aar"),
        releaseAarDir.resolve("SkipUI-release.aar"),
    ).filter { it.isFile }.toTypedArray()
}

fun skipBetslipAar(local: Boolean): File? {
    if (local) {
        return rootProject.file("../sdks/betslip/out/FightDeckBetslip-release.aar").takeIf { it.isFile }
    }
    return releaseAarDir.resolve("FightDeckBetslip-release.aar").takeIf { it.isFile }
}

fun skipFighterAar(local: Boolean): File? {
    if (local) {
        return rootProject.file("../sdks/fighter/out/FightDeckFighter-release.aar").takeIf { it.isFile }
    }
    return releaseAarDir.resolve("FightDeckFighter-release.aar").takeIf { it.isFile }
}

android {
    namespace = "com.fightdeck.baseline"
    compileSdk = 37

    defaultConfig {
        // Distinct from the other hosts so all five approaches can be installed side by side.
        applicationId = "com.fightdeck.sdk.skip"
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
}

val demoAssetsDir = layout.projectDirectory.dir("src/main/assets")

val syncDemoAssets = tasks.register<Copy>("syncDemoAssets") {
    from(rootProject.file("../../dataset"))
    from(rootProject.file("../../shared-ui-spec/tokens.json"))
    into(demoAssetsDir)
}

tasks.named("preBuild") {
    dependsOn(syncDemoAssets)
}

dependencies {
    if (useSkipMaven) {
        listOf("runtime", "deposit", "both", "all").forEach { flavor ->
            "${flavor}Implementation"("fightdeck.skip:FightDeckCoreBinary:$skipSdkVersion")
            "${flavor}Implementation"("fightdeck.skip:FightDeckEventsBinary:$skipSdkVersion")
        }
        listOf("deposit", "both", "all").forEach { flavor ->
            "${flavor}Implementation"("fightdeck.skip:FightDeckDepositBinary:$skipSdkVersion")
        }
        listOf("both", "all").forEach { flavor ->
            "${flavor}Implementation"("fightdeck.skip:FightDeckBetslipBinary:$skipSdkVersion")
        }
        "allImplementation"("fightdeck.skip:FightDeckFighterBinary:$skipSdkVersion")
    } else {
        val coreAars = skipCoreAars(fightdeckLocalSdk)
        val eventsAar = skipEventsAar(fightdeckLocalSdk)
        val depositAars = skipDepositFeatureAars(fightdeckLocalSdk)
        val betslipAar = skipBetslipAar(fightdeckLocalSdk)
        val fighterAar = skipFighterAar(fightdeckLocalSdk)

        listOf("runtime", "deposit", "both", "all").forEach { flavor ->
            "${flavor}Implementation"(files(*coreAars))
            eventsAar?.let { "${flavor}Implementation"(files(it)) }
        }
        listOf("deposit", "both", "all").forEach { flavor ->
            "${flavor}Implementation"(files(*depositAars))
        }
        betslipAar?.let { aar ->
            listOf("both", "all").forEach { flavor ->
                "${flavor}Implementation"(files(aar))
            }
        }
        fighterAar?.let { aar ->
            "allImplementation"(files(aar))
        }
    }

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
}

tasks.withType<Test>().configureEach {
    systemProperty("fightdeck.dataset.root", rootProject.file("../../dataset").absolutePath)
    systemProperty("fightdeck.fixtures.root", rootProject.file("../../contract/fixtures").absolutePath)
}
