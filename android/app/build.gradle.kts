// 안드로이드 앱. 규칙과 진행은 :core에 있고, 그림·소리·레벨은 iOS 판의 폴더에서 빌드할 때 가져온다.
plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.plugin.compose")
}

android {
    namespace = "dev.code404.sporesweep"
    compileSdk {
        version = release(37) { minorApiLevel = 2 }
    }

    defaultConfig {
        applicationId = "dev.code404.sporesweep"
        minSdk = 26
        targetSdk = 36
        versionCode = 1
        versionName = "0.37"
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

    sourceSets["main"].assets.directories.add(layout.buildDirectory.dir("generated/sporeAssets").get().asFile.path)
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
tasks.named("preBuild") { dependsOn(syncSporeAssets) }

dependencies {
    implementation(project(":core"))
    implementation(platform("androidx.compose:compose-bom:2026.09.00"))
    implementation("androidx.compose.ui:ui")
    implementation("androidx.compose.foundation:foundation")
    implementation("androidx.compose.animation:animation")
    implementation("androidx.activity:activity-compose:1.13.0")
    implementation("androidx.core:core-ktx:1.19.1")
}
