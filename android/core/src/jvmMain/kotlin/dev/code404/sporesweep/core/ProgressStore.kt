package dev.code404.sporesweep.core

import java.io.File
import java.nio.file.Files
import java.nio.file.StandardCopyOption

/** 진행 상황을 JSON 파일로 기기에 저장한다. */
class ProgressStore(val file: File) {
    /** 파일이 없으면 빈 진행이다. 깨진 파일은 덮어쓰지 않도록 예외를 던진다. */
    fun load(): GameProgress = if (!file.exists()) GameProgress() else GameProgress.fromJson(file.readText())

    /** 쓰는 도중에 앱이 꺼져도 이전 파일이 깨지지 않게 다른 파일에 쓴 뒤 바꿔 넣는다. */
    fun save(progress: GameProgress) {
        file.parentFile?.mkdirs()
        val temporary = File(file.parentFile, file.name + ".tmp")
        temporary.writeText(progress.toJson())
        Files.move(temporary.toPath(), file.toPath(), StandardCopyOption.REPLACE_EXISTING, StandardCopyOption.ATOMIC_MOVE)
    }

    fun reset() {
        if (file.exists()) file.delete()
    }
}
