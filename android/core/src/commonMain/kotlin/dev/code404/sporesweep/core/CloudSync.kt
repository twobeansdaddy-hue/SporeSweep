package dev.code404.sporesweep.core

import kotlin.time.Clock
import kotlin.time.Instant

/** 클라우드에서 읽은 결과. */
sealed interface CloudRead {
    /** 클라우드에 진행이 있다. */
    class Found(val progress: GameProgress) : CloudRead
    /** 클라우드에 진행이 없다(처음 쓰는 계정이거나 지웠다). 저장된 내용이 정말 비어 있을 때만이다. */
    data object Empty : CloudRead
    /** 로그인하지 않았거나, 연결이 안 되거나, 내용을 읽지 못했다. 지금은 알 수 없으므로 올리지 않는다. */
    data object Unavailable : CloudRead
}

/**
 * 진행을 계정의 클라우드에 둔다(안드로이드는 Play 게임즈의 저장된 게임). 앱을 지우고 다시 설치해도 진행이 돌아온다.
 * 결과는 메인 스레드에서 부른다. 언제 무엇을 올릴지는 [CloudSync]가 정한다.
 */
interface CloudBackend {
    /** 이 기기에서 쓸 수 있는지(설정이 들어 있는지). 아니면 설정 화면에 스위치가 없다. */
    val isAvailable: Boolean
    fun load(done: (CloudRead) -> Unit)

    /**
     * 클라우드의 진행을 읽고, `transform`이 돌려준 진행을 같은 자리에 쓴다. 읽고 쓰는 사이에 다른 기기가 써서 잃지 않게
     * 한 번 연 저장 자리에서 함께 한다. `transform`이 `null`이면 쓰지 않는다. `done`은 썼는지다.
     */
    fun update(transform: (CloudRead) -> GameProgress?, done: (Boolean) -> Unit)

    /** 클라우드의 진행을 지운다. `done`은 지웠는지다. */
    fun clear(done: (Boolean) -> Unit)
}

object NoCloud : CloudBackend {
    override val isAvailable = false
    override fun load(done: (CloudRead) -> Unit) = done(CloudRead.Unavailable)
    override fun update(transform: (CloudRead) -> GameProgress?, done: (Boolean) -> Unit) = done(false)
    override fun clear(done: (Boolean) -> Unit) = done(false)
}

/**
 * 진행을 클라우드에 올리고 내려받는다(iOS 판 CloudSync). 앱을 켤 때 클라우드의 진행을 받아 합치고,
 * 저장할 때마다 클라우드의 진행과 합친 것을 올린다. 다시 설치한 기기가 빈 진행으로 클라우드를 덮어쓰지 않게 [CloudGate]가 막는다.
 *
 * 한 번에 한 가지 일(받기, 올리기, 지우기)만 한다. "처음부터 다시 하기"나 끄기로 세대가 바뀌면 그 전에 시작한 일의 결과는 버린다.
 * 지우기는 하던 일이 끝난 뒤에 하고, 지우지 못하면 지울 때까지 받지도 올리지도 않는다(앱을 다시 켜도 이어서 지운다).
 *
 * @param isEnabled 설정에서 켜 두었는지.
 * @param pendingClear 아직 지우지 못한 "처음부터 다시 하기"가 있는지(앱을 다시 켜도 남게 저장해 둔다).
 * @param now 지금 시각(시험에서 바꾼다).
 */
class CloudSync(
    private val backend: CloudBackend,
    private val isEnabled: () -> Boolean,
    pendingClear: (() -> Boolean)? = null,
    setPendingClear: ((Boolean) -> Unit)? = null,
    private val now: () -> Instant = { Clock.System.now() },
) {
    private var gate: CloudGate? = null
    /** 이 기기의 가장 최근 진행. 올릴 때 클라우드의 진행과 합친다. */
    private var latest: GameProgress? = null
    private var onRemote: ((GameProgress) -> Unit)? = null
    private var busy = false
    /** 일하는 사이에 바뀐 진행이 있어 끝나면 다시 올린다. */
    private var dirty = false
    /** 일하는 사이에 받기를 부탁받았다. */
    private var wantsRefresh = false
    /** 지우기나 끄기로 바뀐다. 그 전에 시작한 일의 결과는 버린다. */
    private var generation = 0

    /** 저장할 곳을 받지 않으면 이 실행 동안만 기억한다. */
    private var clearPendingInMemory = false
    private val pendingClear: () -> Boolean = pendingClear ?: { clearPendingInMemory }
    private val setPendingClear: (Boolean) -> Unit = setPendingClear ?: { clearPendingInMemory = it }

    val isAvailable get() = backend.isAvailable

    /** 앱을 켤 때 부른다. 클라우드의 진행이 오면 `onRemote`로 넘긴다(합치는 것은 부르는 쪽). */
    fun start(local: GameProgress, onRemote: (GameProgress) -> Unit) {
        this.onRemote = onRemote
        gate = CloudGate(local, now())
        latest = local.copy()
        refresh()
    }

    /** 클라우드의 진행을 다시 받는다(앱을 켤 때, 앱으로 돌아왔을 때, 다시 켰을 때). */
    fun refresh() {
        if (!isEnabled() || gate == null) return
        if (pendingClear()) return runClear()
        if (busy) {
            wantsRefresh = true
            return
        }
        busy = true
        val started = generation
        backend.load { read ->
            if (started != generation || !isEnabled()) return@load finished(started)
            when (read) {
                is CloudRead.Found -> {
                    gate?.cloudSeen()
                    onRemote?.invoke(read.progress)
                }
                CloudRead.Empty -> gate?.cloudSeen()
                CloudRead.Unavailable -> {}
            }
            dirty = true
            finished(started)
        }
    }

    /** 진행을 올린다. 다시 설치한 직후라면 클라우드의 진행을 볼 때까지 미룬다. */
    fun push(progress: GameProgress) {
        latest = progress.copy()
        flush()
    }

    private fun flush() {
        val gate = gate ?: return
        if (latest == null || !isEnabled()) return
        if (pendingClear()) return runClear()
        if (busy) {
            dirty = true
            return
        }
        gate.tick(now())
        if (!gate.isOpen) return
        busy = true
        dirty = false
        val started = generation
        backend.update({ read ->
            val local = latest
            when {
                started != generation || !isEnabled() || local == null -> null
                read == CloudRead.Unavailable -> null
                else -> gate.upload(local, (read as? CloudRead.Found)?.progress)
            }
        }) { finished(started) }
    }

    /** 일이 끝났다. 그 일의 결과는 세대를 보고 이미 버렸으므로, 여기서는 미뤄 둔 일만 잇는다. */
    private fun finished(@Suppress("UNUSED_PARAMETER") started: Int) {
        busy = false
        if (pendingClear()) return runClear()
        when {
            wantsRefresh -> {
                wantsRefresh = false
                refresh()
            }
            dirty -> flush()
        }
    }

    /** 끄거나 다시 켰을 때. 끄면 하던 일의 결과를 버리고, 켜면 받아서 합친 뒤 올린다. */
    fun enabledChanged(local: GameProgress) {
        generation += 1
        dirty = false
        wantsRefresh = false
        if (!isEnabled()) return
        latest = local.copy()
        if (!busy) refresh() else wantsRefresh = true
    }

    /** 클라우드의 진행을 지운다("처음부터 다시 하기"). 하던 일이 끝난 뒤 지우고, 지운 뒤에야 새 진행을 올린다. */
    fun clear() {
        generation += 1
        latest = null
        dirty = false
        wantsRefresh = false
        // 클라우드를 비우므로 기다릴 것이 없다. 진행을 읽지 못해 문이 없던 기기도 이제부터 올린다.
        (gate ?: CloudGate(GameProgress(), now()).also { gate = it }).cloudSeen()
        if (!isEnabled()) return
        setPendingClear(true)
        runClear()
    }

    private fun runClear() {
        if (busy || !isEnabled()) return
        busy = true
        backend.clear { ok ->
            busy = false
            if (!ok) return@clear  // 다음 저장이나 앱으로 돌아올 때 다시 지운다.
            setPendingClear(false)
            dirty = false
            if (latest != null) flush()
        }
    }
}
