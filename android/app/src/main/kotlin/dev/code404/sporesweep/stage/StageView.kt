package dev.code404.sporesweep.stage

import androidx.compose.foundation.Canvas
import androidx.compose.foundation.gestures.awaitEachGesture
import androidx.compose.foundation.gestures.awaitFirstDown
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableLongStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.runtime.withFrameNanos
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.drawscope.drawIntoCanvas
import androidx.compose.ui.graphics.nativeCanvas
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.layout.onSizeChanged
import androidx.compose.ui.platform.LocalDensity

/** 무대를 화면에 띄운다. 매 프레임 동작을 돌리고 다시 그리며, 손가락 입력을 무대에 넘긴다. */
@Composable
fun StageView(stage: Stage, modifier: Modifier = Modifier) {
    val density = LocalDensity.current.density
    var frame by remember { mutableLongStateOf(0L) }
    LaunchedEffect(stage) {
        var last = 0L
        while (true) {
            withFrameNanos { now ->
                if (last != 0L) stage.update(minOf((now - last) / 1e9, 0.1))
                last = now
                frame += 1
            }
        }
    }
    Canvas(
        modifier
            .onSizeChanged { stage.resize(it.width / density, it.height / density) }
            .pointerInput(stage) {
                awaitEachGesture {
                    val down = awaitFirstDown()
                    stage.touchDown(stage.toStage(down.position.x, down.position.y, density))
                    while (true) {
                        val event = awaitPointerEvent()
                        val change = event.changes.firstOrNull { it.id == down.id } ?: break
                        if (!change.pressed) break
                        stage.touchMove(stage.toStage(change.position.x, change.position.y, density))
                        change.consume()
                    }
                    stage.touchUp()
                }
            },
    ) {
        frame
        drawIntoCanvas { stage.draw(it.nativeCanvas, density) }
    }
}
