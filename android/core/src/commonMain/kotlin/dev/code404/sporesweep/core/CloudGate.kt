package dev.code404.sporesweep.core

import kotlin.time.Duration.Companion.seconds
import kotlin.time.Instant

/**
 * 클라우드에 진행을 올려도 되는지 정한다(iOS 판 CloudGate).
 *
 * 앱을 지우고 다시 설치하면 이 기기의 진행은 비어 있고, 클라우드의 진행은 조금 뒤에야 내려온다.
 * 그 사이에 빈 진행을 올리면 클라우드의 진행을 덮어쓴다. 그래서 클라우드의 진행을 한 번 보거나
 * 기다릴 만큼 기다리기 전에는 올리지 않고, 올릴 때는 늘 클라우드의 진행과 합친 것을 올린다.
 *
 * @param local 앱을 켤 때 이 기기에 있던 진행.
 * @param startedAt 앱을 켠 때.
 */
class CloudGate(local: GameProgress, private val startedAt: Instant) {
    /** 올려도 되는지. 이미 기록이 있는 기기는 진행을 들고 있으므로 바로 올려도 된다(합쳐서 올리므로 클라우드의 것을 줄이지 않는다). */
    var isOpen = !local.isEmpty
        private set

    /** 클라우드의 진행을 받았거나 클라우드에 진행이 없다는 것을 알았다. */
    fun cloudSeen() {
        isOpen = true
    }

    /** 시간이 지났는지 본다. */
    fun tick(now: Instant) {
        if (now - startedAt >= MAX_WAIT) isOpen = true
    }

    /**
     * 클라우드에 올릴 진행. 닫혀 있거나 클라우드에 이미 같은 것이 있으면 `null`이다.
     * 생명력과 일일 보상은 기기마다 따로라 비교하지 않는다.
     */
    fun upload(local: GameProgress, cloud: GameProgress?): GameProgress? {
        if (!isOpen) return null
        if (cloud == null) return local
        val merged = local.merging(cloud)
        return if (merged.sharesProgress(cloud)) null else merged
    }

    companion object {
        /** 내려오기를 기다리는 가장 긴 시간. 이 뒤에도 소식이 없으면 클라우드에 진행이 없는 것으로 본다. */
        val MAX_WAIT = 60.seconds
    }
}
