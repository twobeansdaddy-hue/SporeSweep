import org.jetbrains.kotlin.gradle.ExperimentalWasmDsl

// 웹판(Kotlin/Wasm). 게임은 :game을 그대로 쓰고, 여기에는 웹에서 파일을 받고 소리를 내고 저장하는 일만 있다.
//
// ./gradlew :web:webSite  →  build/site에 올릴 파일이 모인다(Cloudflare Pages에 그대로 올린다).
// ./gradlew :web:wasmJsBrowserDevelopmentRun  →  내 컴퓨터에서 띄워 본다(그림 파일은 webAssets를 먼저).
plugins {
    kotlin("multiplatform")
    id("org.jetbrains.compose")
    id("org.jetbrains.kotlin.plugin.compose")
}

kotlin {
    @OptIn(ExperimentalWasmDsl::class)
    wasmJs {
        outputModuleName.set("sporesweep")
        browser {
            commonWebpackConfig { outputFileName = "sporesweep.js" }
        }
        binaries.executable()
    }

    sourceSets {
        all { languageSettings.optIn("kotlin.time.ExperimentalTime") }
        wasmJsMain.dependencies {
            implementation(project(":game"))
            implementation("org.jetbrains.kotlinx:kotlinx-browser:0.5.0")
        }
    }
}

// 그림을 WebP로 줄이고 글 파일을 묶는다. 안드로이드 빌드가 iOS 폴더에서 모은 파일을 쓴다.
val webAssets = tasks.register<Exec>("webAssets") {
    dependsOn(":app:syncSporeAssets")
    val source = project(":app").layout.buildDirectory.dir("generated/sporeAssets").get().asFile
    val landmarks = project(":app").file("src/main/assets/landmarks.json")
    val output = layout.buildDirectory.dir("webAssets").get().asFile
    inputs.dir(source)
    inputs.file(landmarks)
    outputs.dir(output)
    commandLine("python3", rootDir.parentFile.resolve("Tools/make_web_assets.py").path, source.path, landmarks.path, output.path)
}

// 올릴 파일을 한곳에 모은다: 빌드한 웹 앱과 그림·소리.
tasks.register<Sync>("webSite") {
    dependsOn("wasmJsBrowserDistribution", webAssets)
    from(layout.buildDirectory.dir("dist/wasmJs/productionExecutable"))
    from(layout.buildDirectory.dir("webAssets"))
    into(layout.buildDirectory.dir("site"))
}
