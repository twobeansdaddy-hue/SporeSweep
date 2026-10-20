// Claude Code의 mods에서 쓰는 규칙 엔진. :core를 순수 자바스크립트(ES 모듈)로 내보낸다.
// 화면은 mods 쪽(Tools/mod/sporesweep)이 그리고, 여기에는 판을 만들고 수를 두는 함수만 있다.
//
// ./gradlew :mod:modEngine  →  Tools/mod/sporesweep/engine/sporesweep-engine.mjs (esbuild로 한 파일로 묶는다)
plugins {
    kotlin("multiplatform")
}

kotlin {
    js {
        outputModuleName.set("sporesweep-mod")
        nodejs()
        useEsModules()
        binaries.library()
        generateTypeScriptDefinitions()
    }
    sourceSets {
        all {
            languageSettings.optIn("kotlin.time.ExperimentalTime")
            languageSettings.optIn("kotlin.js.ExperimentalJsExport")
        }
        jsMain.dependencies {
            implementation(project(":core"))
        }
    }
}

// 엔진을 한 파일(ES 모듈)로 묶는다. mods는 다른 패키지를 불러올 수 없어서 날짜 라이브러리까지 함께 묶는다.
tasks.register<Exec>("modEngine") {
    dependsOn("compileProductionLibraryKotlinJs")
    val entry = layout.buildDirectory.file("compileSync/js/main/productionLibrary/kotlin/sporesweep-mod.mjs").get().asFile
    val output = layout.buildDirectory.file("engine/sporesweep-engine.mjs").get().asFile
    outputs.file(output)
    environment("NODE_PATH", rootProject.layout.buildDirectory.dir("js/node_modules").get().asFile.path)
    commandLine(
        "npx", "--yes", "esbuild@0.25.10", entry.path, "--bundle", "--format=esm", "--platform=neutral", "--minify",
        "--main-fields=module,main", "--outfile=${output.path}",
    )
}
