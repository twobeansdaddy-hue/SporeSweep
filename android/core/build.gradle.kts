import org.jetbrains.kotlin.gradle.dsl.JvmTarget

// 규칙, 레벨, 진행. 안드로이드에 기대지 않는 순수 Kotlin이라 맥에서 바로 시험한다.
plugins {
    kotlin("jvm")
}

java {
    sourceCompatibility = JavaVersion.VERSION_17
    targetCompatibility = JavaVersion.VERSION_17
}

kotlin {
    compilerOptions.jvmTarget.set(JvmTarget.JVM_17)
}

dependencies {
    implementation("org.jetbrains.kotlinx:kotlinx-serialization-json:1.10.0")
    testImplementation(kotlin("test"))
}

sourceSets {
    // 레벨 JSON은 iOS 판과 같은 파일을 쓴다. 복사하지 않는다.
    test {
        resources.srcDir("../../LevelData/Sources/LevelData/Levels")
    }
}

tasks.test {
    useJUnitPlatform()
    testLogging {
        events("failed")
        showStandardStreams = true
        exceptionFormat = org.gradle.api.tasks.testing.logging.TestExceptionFormat.FULL
    }
}
