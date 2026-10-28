package dev.code404.sporesweep

import android.app.Activity
import android.util.Log
import com.google.android.gms.games.PlayGames
import com.google.android.gms.games.PlayGamesSdk
import com.google.android.gms.games.SnapshotsClient
import com.google.android.gms.games.snapshot.Snapshot
import com.google.android.gms.games.snapshot.SnapshotMetadataChange
import dev.code404.sporesweep.core.CloudBackend
import dev.code404.sporesweep.core.CloudRead
import dev.code404.sporesweep.core.GameProgress

/**
 * 진행을 Play 게임즈의 저장된 게임에 둔다(클라우드 저장). Play 게임즈 SDK는 이 파일에서만 부른다.
 *
 * 게임즈 서비스 프로젝트 ID는 `config.properties`의 `PLAY_GAMES_APP_ID`다(build.gradle.kts가 매니페스트에 넣는다).
 * 없으면 클라우드 저장이 없다. SDK는 켜지는 순간 스스로 로그인하고(v2), 로그인하지 않은 사람은 기기에만 저장된다.
 * 저장된 게임 하나("progress")에 진행 JSON을 둔다. 두 기기가 동시에 써서 충돌하면 우리 규칙으로 합쳐서 푼다.
 */
object PlayGamesCloud : CloudBackend {
    private const val TAG = "클라우드"
    private const val NAME = "progress"
    /** 충돌을 풀고 다시 여는 가장 많은 횟수. 그래도 충돌이면 이번에는 포기한다. */
    private const val MAX_CONFLICT_RETRIES = 3
    var activity: Activity? = null

    override val isAvailable = BuildConfig.PLAY_GAMES_APP_ID.isNotEmpty()

    fun start(activity: Activity) {
        this.activity = activity
        if (isAvailable) PlayGamesSdk.initialize(activity.applicationContext)
    }

    /** 저장된 게임에서 읽은 것. 비어 있으면 `Empty`, 읽거나 해석하지 못하면 `Unavailable`이다. */
    private fun read(snapshot: Snapshot): CloudRead {
        val bytes = runCatching { snapshot.snapshotContents.readFully() }.getOrNull() ?: return CloudRead.Unavailable
        if (bytes.isEmpty()) return CloudRead.Empty
        return runCatching { CloudRead.Found(GameProgress.fromJson(bytes.decodeToString())) }.getOrDefault(CloudRead.Unavailable)
    }

    /** 로그인했으면 저장된 게임을 연다. 충돌이 있으면 양쪽을 합쳐서 푼 뒤 다시 연다. 열지 못하면 `null`이다. */
    private fun open(done: (Snapshot?) -> Unit, attempt: Int = 0) {
        val activity = activity ?: return done(null)
        PlayGames.getGamesSignInClient(activity).isAuthenticated.addOnCompleteListener { auth ->
            if (!auth.isSuccessful || auth.result?.isAuthenticated != true) {
                log("로그인하지 않음")
                return@addOnCompleteListener done(null)
            }
            val client = PlayGames.getSnapshotsClient(activity)
            client.open(NAME, true, SnapshotsClient.RESOLUTION_POLICY_MANUAL).addOnCompleteListener { task ->
                if (!task.isSuccessful) {
                    log("열지 못함: ${task.exception}")
                    return@addOnCompleteListener done(null)
                }
                val result = task.result
                val conflict = result.conflict ?: return@addOnCompleteListener done(result.data)
                if (attempt >= MAX_CONFLICT_RETRIES) {
                    log("충돌을 풀지 못함")
                    return@addOnCompleteListener done(null)
                }
                // 두 기기가 동시에 썼다. 양쪽을 합쳐 서버 쪽 자리에 써서 푼다. 한쪽이라도 읽지 못하면 풀지 않는다.
                val sides = listOf(read(conflict.snapshot), read(conflict.conflictingSnapshot))
                if (sides.any { it == CloudRead.Unavailable }) {
                    log("충돌한 내용을 읽지 못함")
                    return@addOnCompleteListener done(null)
                }
                val merged = sides.filterIsInstance<CloudRead.Found>().map { it.progress }.reduceOrNull { a, b -> a.merging(b) }
                val snapshot = conflict.snapshot
                if (merged != null && !snapshot.snapshotContents.writeBytes(merged.toJson().encodeToByteArray())) {
                    log("충돌을 푼 내용을 쓰지 못함")
                    return@addOnCompleteListener done(null)
                }
                client.resolveConflict(conflict.conflictId, snapshot).addOnCompleteListener { resolved ->
                    if (resolved.isSuccessful) open(done, attempt + 1) else done(null)
                }
            }
        }
    }

    override fun load(done: (CloudRead) -> Unit) {
        open({ snapshot ->
            if (snapshot == null) return@open done(CloudRead.Unavailable)
            val read = read(snapshot)
            activity?.let { PlayGames.getSnapshotsClient(it).discardAndClose(snapshot) }
            log("받음: $read")
            done(read)
        })
    }

    override fun update(transform: (CloudRead) -> GameProgress?, done: (Boolean) -> Unit) {
        open({ snapshot ->
            val activity = activity
            if (snapshot == null || activity == null) return@open done(false)
            val client = PlayGames.getSnapshotsClient(activity)
            val next = transform(read(snapshot))
            if (next == null) {
                client.discardAndClose(snapshot)
                return@open done(false)
            }
            commit(client, snapshot, next.toJson().encodeToByteArray(), done)
        })
    }

    override fun clear(done: (Boolean) -> Unit) {
        open({ snapshot ->
            val activity = activity
            if (snapshot == null || activity == null) return@open done(false)
            commit(PlayGames.getSnapshotsClient(activity), snapshot, ByteArray(0), done)
        })
    }

    private fun commit(client: SnapshotsClient, snapshot: Snapshot, bytes: ByteArray, done: (Boolean) -> Unit) {
        if (!snapshot.snapshotContents.writeBytes(bytes)) {
            log("쓰지 못함")
            client.discardAndClose(snapshot)
            return done(false)
        }
        client.commitAndClose(snapshot, SnapshotMetadataChange.EMPTY_CHANGE).addOnCompleteListener { task ->
            log(if (task.isSuccessful) "올림 ${bytes.size}바이트" else "올리지 못함: ${task.exception}")
            done(task.isSuccessful)
        }
    }

    private fun log(text: String) {
        if (BuildConfig.DEBUG) Log.i(TAG, text)
    }
}
