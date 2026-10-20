import org.jetbrains.kotlin.gradle.ExperimentalWasmDsl

// 게임 화면. 그리기 엔진, 보드, 메뉴 화면, 앱 상태를 안드로이드 앱과 웹판이 함께 쓴다.
// 플랫폼마다 다른 것(그림 읽기, 소리, 저장, 광고, 기록)은 Platform 뒤에 숨긴다.
plugins {
    kotlin("multiplatform")
    id("com.android.kotlin.multiplatform.library")
    id("org.jetbrains.compose")
    id("org.jetbrains.kotlin.plugin.compose")
}

kotlin {
    androidLibrary {
        namespace = "dev.code404.sporesweep.game"
        compileSdk = 37
        minSdk = 26
    }
    @OptIn(ExperimentalWasmDsl::class)
    wasmJs {
        browser()
    }

    sourceSets {
        all { languageSettings.optIn("kotlin.time.ExperimentalTime") }
        commonMain.dependencies {
            api(project(":core"))
            api("org.jetbrains.compose.runtime:runtime:1.12.1")
            api("org.jetbrains.compose.foundation:foundation:1.12.1")
            api("org.jetbrains.compose.ui:ui:1.12.1")
            api("org.jetbrains.compose.animation:animation:1.12.1")
            api("org.jetbrains.compose.material3:material3:1.9.0")
            api("org.jetbrains.compose.material:material-icons-extended:1.7.3")
        }
        androidMain.dependencies {
            api("androidx.activity:activity-compose:1.13.0")
            api("androidx.core:core-ktx:1.19.1")
        }
    }
}
