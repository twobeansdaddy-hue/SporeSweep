import org.jetbrains.kotlin.gradle.ExperimentalWasmDsl
import org.jetbrains.kotlin.gradle.dsl.JvmTarget

// 규칙, 레벨, 진행. 안드로이드에도 웹에도 기대지 않는 Kotlin이라 안드로이드 앱과 웹판이 함께 쓴다.
// JVM 쪽에서는 맥에서 바로 시험하고, 웹(Wasm) 쪽에서도 같은 기준 기록으로 규칙이 같은지 본다.
plugins {
    kotlin("multiplatform")
}

val levels = rootDir.parentFile.resolve("LevelData/Sources/LevelData/Levels")

// 웹(Wasm)과 mods용(JS) 시험은 Node에서 파일을 바로 읽으므로 위치를 코드로 넘긴다.
val testPaths = layout.buildDirectory.dir("generated/testPaths")
val writeTestPaths = tasks.register("writeTestPaths") {
    val output = testPaths.map { it.file("TestPaths.kt") }
    val levelsPath = levels.absolutePath
    val parityPath = file("src/commonTest/resources/parity").absolutePath
    outputs.file(output)
    inputs.property("paths", levelsPath + parityPath)
    doLast {
        output.get().asFile.writeText(
            "package dev.code404.sporesweep.core\n\n" +
                "internal const val LEVELS_DIRECTORY = \"$levelsPath\"\n" +
                "internal const val PARITY_DIRECTORY = \"$parityPath\"\n",
        )
    }
}
tasks.matching { it.name == "compileTestKotlinWasmJs" || it.name == "compileTestKotlinJs" }.configureEach { dependsOn(writeTestPaths) }

kotlin {
    jvm {
        compilerOptions.jvmTarget.set(JvmTarget.JVM_17)
        testRuns["test"].executionTask.configure {
            useJUnitPlatform()
            testLogging {
                events("failed")
                showStandardStreams = true
                exceptionFormat = org.gradle.api.tasks.testing.logging.TestExceptionFormat.FULL
            }
        }
    }
    // Claude Code의 mods용. mods는 WebAssembly를 쓰지 못해서 순수 자바스크립트로도 만든다(:mod).
    // 시험도 Node에서 같은 기준 기록으로 돌려 mods판의 규칙이 같은지 본다.
    js {
        nodejs { testTask { useMocha { timeout = "600s" } } }
        useEsModules()
    }
    @OptIn(ExperimentalWasmDsl::class)
    wasmJs {
        // 웹판이 쓰므로 브라우저용으로도 만든다. 시험은 기준 기록 파일을 읽어야 해서 Node에서만 돈다.
        browser { testTask { enabled = false } }
        nodejs()
    }

    sourceSets {
        all { languageSettings.optIn("kotlin.time.ExperimentalTime") }
        commonMain.dependencies {
            // 앱도 JSON과 날짜를 쓰므로 그대로 내보낸다.
            api("org.jetbrains.kotlinx:kotlinx-serialization-json:1.10.0")
            api("org.jetbrains.kotlinx:kotlinx-datetime:0.8.0")
        }
        commonTest.dependencies {
            implementation(kotlin("test"))
        }
        // 레벨 JSON은 iOS 판과 같은 파일을 쓴다. 복사하지 않는다.
        jvmTest.get().resources.srcDirs(levels, "src/commonTest/resources")
        wasmJsTest.get().kotlin.srcDir(testPaths)
        jsTest.get().kotlin.srcDir(testPaths)
    }
}
