package dev.code404.sporesweep

import android.app.Activity
import android.content.Intent
import android.graphics.Bitmap
import androidx.compose.ui.graphics.ImageBitmap
import androidx.compose.ui.graphics.asAndroidBitmap
import androidx.core.content.FileProvider
import com.google.android.play.core.review.ReviewManagerFactory
import java.io.File

/** 자랑 그림 공유와 별점 창(DESIGN.md 8장). 게임 코드는 Platform.share와 Platform.requestReview로 부른다. */
object Sharing {
    /** Play 스토어의 앱 페이지. 공유하는 글에 붙인다. */
    const val STORE_URL = "https://play.google.com/store/apps/details?id=app.code404.sporesweep"

    /**
     * 그림을 캐시 폴더에 PNG로 쓰고 공유 창을 띄운다. 공유마다 새 파일을 써서, 앞서 받은 앱이 늦게 읽어도 다른 그림을 받지 않게 한다.
     * 쓰지 못하면(저장 공간 부족 등) 공유하지 않는다.
     */
    fun share(activity: Activity, image: ImageBitmap, text: String) {
        val folder = File(activity.cacheDir, "share").apply { mkdirs() }
        // 한 시간 지난 그림은 지운다. 받은 앱은 그 안에 다 읽었다.
        folder.listFiles()?.filter { System.currentTimeMillis() - it.lastModified() > 60 * 60 * 1000 }?.forEach { it.delete() }
        val file = File(folder, "share_card_${System.currentTimeMillis()}.png")
        val written = runCatching {
            file.outputStream().use { image.asAndroidBitmap().compress(Bitmap.CompressFormat.PNG, 100, it) }
        }.getOrDefault(false)
        if (!written) {
            file.delete()
            android.util.Log.w("공유", "자랑 그림을 쓰지 못함")
            return
        }
        val uri = FileProvider.getUriForFile(activity, "${activity.packageName}.share", file)
        val intent = Intent(Intent.ACTION_SEND).apply {
            type = "image/png"
            putExtra(Intent.EXTRA_STREAM, uri)
            putExtra(Intent.EXTRA_TEXT, text)
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
        }
        activity.startActivity(Intent.createChooser(intent, null))
    }

    /** Play 인앱 리뷰 창을 부탁한다. 띄울지와 몇 번까지인지는 Play가 정하고, 결과는 알려 주지 않는다. */
    fun requestReview(activity: Activity) {
        val manager = ReviewManagerFactory.create(activity)
        manager.requestReviewFlow().addOnCompleteListener { task ->
            if (task.isSuccessful) manager.launchReviewFlow(activity, task.result)
        }
    }
}
