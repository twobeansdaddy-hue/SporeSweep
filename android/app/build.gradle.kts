// 안드로이드 앱. 규칙과 진행은 :core에 있고, 그림·소리·레벨은 iOS 판의 폴더에서 빌드할 때 가져온다.
import java.util.Properties

plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.plugin.compose")
}

// Firebase 설정 파일이 있을 때만 Firebase를 붙인다. 없으면 기록을 보내지 않을 뿐 앱은 그대로 돈다.
if (file("google-services.json").exists()) apply(plugin = "com.google.gms.google-services")

// 사람마다 다른 값(AdMob ID). android/config.properties에 적는다. 그 파일은 저장소에 올리지 않는다.
// 적지 않으면 구글이 공개한 시험용 ID를 쓴다.
val config = Properties().apply {
    val file = rootProject.file("config.properties")
    if (file.exists()) file.inputStream().use { load(it) }
}
// 출시용 업로드 키. config.properties의 UPLOAD_KEYSTORE에 키 파일 위치를 적고, 비밀번호는 맥 키체인
// (sporesweep-upload-key)이나 환경 변수 UPLOAD_KEY_PASSWORD에 둔다. 없으면 개발용 열쇠로 서명한다.
val uploadKeystore = config.getProperty("UPLOAD_KEYSTORE")?.let { file(it.replaceFirst("~", System.getProperty("user.home"))) }?.takeIf { it.exists() }
val uploadKeyPassword: String? by lazy {
    System.getenv("UPLOAD_KEY_PASSWORD") ?: runCatching {
        val process = ProcessBuilder("security", "find-generic-password", "-a", System.getProperty("user.name"), "-s", "sporesweep-upload-key", "-w")
            .redirectErrorStream(false).start()
        process.inputStream.bufferedReader().readText().trim().takeIf { process.waitFor() == 0 && it.isNotEmpty() }
    }.getOrNull()
}

// 클라우드 저장(Play 게임즈 저장된 게임)의 게임즈 서비스 프로젝트 ID. 없으면 클라우드 저장을 끈다(PlayGamesCloud.kt).
val playGamesAppId = config.getProperty("PLAY_GAMES_APP_ID", "").trim()

val testAdmobAppId = "ca-app-pub-3940256099942544~3347511713"
val testRewardedUnit = "ca-app-pub-3940256099942544/5224354917"

android {
    namespace = "dev.code404.sporesweep"
    compileSdk {
        version = release(37) { minorApiLevel = 2 }
    }

    defaultConfig {
        applicationId = "app.code404.sporesweep"
        minSdk = 26
        targetSdk = 36
        versionCode = 5
        versionName = "0.2"
        manifestPlaceholders["admobAppId"] = config.getProperty("ADMOB_APP_ID", testAdmobAppId)
        buildConfigField("String", "REWARDED_AD_UNIT", "\"${config.getProperty("REWARDED_AD_UNIT_ID", testRewardedUnit)}\"")
        buildConfigField("String", "TEST_REWARDED_AD_UNIT", "\"$testRewardedUnit\"")
        // 출시 빌드는 실제 광고를 쓴다. 내부 테스트용으로 올릴 때는 -PtestAds를 붙여 시험 광고만 나오게 한다.
        buildConfigField("boolean", "TEST_ADS", (project.hasProperty("testAds")).toString())
        buildConfigField("String", "PLAY_GAMES_APP_ID", "\"$playGamesAppId\"")
        resValue("string", "game_services_project_id", playGamesAppId)
    }

    signingConfigs {
        if (uploadKeystore != null && uploadKeyPassword != null) {
            create("upload") {
                storeFile = uploadKeystore
                storePassword = uploadKeyPassword
                keyAlias = config.getProperty("UPLOAD_KEY_ALIAS", "upload")
                keyPassword = uploadKeyPassword
            }
        }
    }

    buildTypes {
        release {
            // 코드와 쓰지 않는 리소스를 줄인다. 앱 용량의 큰 몫이 라이브러리 코드다.
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"), "proguard-rules.pro")
            // 업로드 키가 없는 사람은 맥에서 시험할 수 있게 개발용 열쇠로 서명한다.
            signingConfig = signingConfigs.findByName("upload") ?: signingConfigs.getByName("debug")
        }
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    buildFeatures {
        compose = true
        buildConfig = true
        resValues = true
    }

    sourceSets["main"].assets.directories.add(layout.buildDirectory.dir("generated/androidAssets").get().asFile.path)
}

// iOS 판의 그림, 소리, 레벨, 글꼴, 번역을 앱의 assets로 모은다. 저장소에는 한 벌만 둔다.
val ios = rootDir.parentFile
val syncSporeAssets = tasks.register<Sync>("syncSporeAssets") {
    into(layout.buildDirectory.dir("generated/sporeAssets"))
    // 이미지 세트마다 그림 파일이 하나다. 세트 이름이 그림의 이름이다.
    from(ios.resolve("SporeSweep/Assets.xcassets")) {
        include("*.imageset/*.png", "*.imageset/*.jpg")
        eachFile { path = "images/" + relativePath.segments[0].removeSuffix(".imageset") + "." + name.substringAfterLast('.') }
        includeEmptyDirs = false
    }
    from(ios.resolve("GameScene/Sources/GameScene/Sprites")) { into("sprites") }
    from(ios.resolve("GameScene/Sources/GameScene/Sounds")) { into("sounds") }
    from(ios.resolve("GameScene/Sources/GameScene/Music")) { into("music") }
    from(ios.resolve("LevelData/Sources/LevelData/Levels")) { into("levels") }
    from(ios.resolve("SporeSweep/Fonts")) { include("*.ttf"); into("fonts") }
    from(ios.resolve("SporeSweep/en.lproj/Localizable.strings")) { into("strings"); rename { "en.strings" } }
}
// 그림을 WebP로 줄여 앱에 넣는다. 웹판도 sporeAssets를 쓰므로 원본은 그대로 둔다.
val androidSporeAssets = tasks.register<Exec>("androidSporeAssets") {
    dependsOn(syncSporeAssets)
    val source = layout.buildDirectory.dir("generated/sporeAssets").get().asFile
    val output = layout.buildDirectory.dir("generated/androidAssets").get().asFile
    inputs.dir(source)
    outputs.dir(output)
    commandLine("python3", ios.resolve("Tools/make_android_assets.py").path, source.path, output.path)
}
tasks.named("preBuild") { dependsOn(androidSporeAssets) }

dependencies {
    // 게임 화면과 규칙은 웹판과 함께 쓰는 :game에 있다.
    implementation(project(":game"))
    implementation("com.google.android.gms:play-services-ads:25.5.0")
    implementation("com.google.android.gms:play-services-games-v2:22.1.0")
    implementation(platform("com.google.firebase:firebase-bom:35.0.0"))
    implementation("com.google.firebase:firebase-analytics")
}
