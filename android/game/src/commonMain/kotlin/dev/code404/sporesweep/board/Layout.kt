package dev.code404.sporesweep.board

import dev.code404.sporesweep.core.GameConstants
import dev.code404.sporesweep.core.Position
import dev.code404.sporesweep.stage.SPoint
import dev.code404.sporesweep.stage.SRect

// iOS 판 BoardLayout.swift, SceneLayout.swift를 옮긴 것이다. 좌표는 y가 위쪽인 dp다.

/** 화면 크기로 계산한 보드 배치. */
class BoardLayout(container: SRect, val columns: Int = GameConstants.COLUMNS, val rows: Int = GameConstants.ACTIVE_ROWS) {
    companion object {
        const val MAXIMUM_CELL_SIZE = 72f
        const val MARGIN = 8f
    }

    val cellSize: Float
    val frame: SRect

    init {
        val width = maxOf(container.width - 2 * MARGIN, 0f)
        val height = maxOf(container.height - 2 * MARGIN, 0f)
        cellSize = minOf(width / columns, height / rows, MAXIMUM_CELL_SIZE)
        val w = cellSize * columns
        val h = cellSize * rows
        frame = SRect(container.midX - w / 2, container.midY - h / 2, w, h)
    }

    /** 칸의 중심. 보드 밖의 행과 열도 같은 격자로 계산한다. */
    fun center(position: Position) = SPoint(
        frame.minX + (position.column + 0.5f) * cellSize,
        frame.maxY - (position.row + 0.5f) * cellSize,
    )

    /** 점이 놓인 칸. 보드 밖이면 `null`이다. */
    fun position(point: SPoint): Position? {
        if (cellSize <= 0 || !frame.contains(point)) return null
        val column = minOf(((point.x - frame.minX) / cellSize).toInt(), columns - 1)
        val row = minOf(((frame.maxY - point.y) / cellSize).toInt(), rows - 1)
        return Position(column, row)
    }
}

/** 씬 전체의 배치. 보드 위에 정보 줄과 대기 물질 띠, 오른쪽에 미니맵, 아래에 수거함. */
class SceneLayout(width: Float, height: Float, columns: Int = GameConstants.COLUMNS, rows: Int = GameConstants.ACTIVE_ROWS) {
    companion object {
        const val HUD_HEIGHT = 60f
        const val QUEUE_HEIGHT = 22f
        const val CONTAINER_HEIGHT = 40f
        const val CONTAINER_GROWTH = 60f
        const val MINIMAP_WIDTH = 10f
        const val MINIMAP_GAP = 6f
    }

    val board: BoardLayout
    val hudFrame: SRect
    val queueFrame: SRect
    val minimapFrame: SRect
    val containerFrame: SRect

    init {
        val area = SRect(
            0f, CONTAINER_HEIGHT,
            maxOf(width - MINIMAP_WIDTH - MINIMAP_GAP, 0f),
            maxOf(height - HUD_HEIGHT - QUEUE_HEIGHT - CONTAINER_HEIGHT, 0f),
        )
        // 보드를 위로 붙이고 남는 높이는 수거함을 키우는 데 쓴다.
        val fitted = BoardLayout(area, columns, rows).frame
        val slack = maxOf(area.height - fitted.height, 0f)
        val containerHeight = CONTAINER_HEIGHT + minOf(slack, CONTAINER_GROWTH)
        board = BoardLayout(SRect(area.minX, area.maxY - fitted.height, area.width, fitted.height), columns, rows)
        val frame = board.frame
        queueFrame = SRect(frame.minX, frame.maxY + 2, frame.width, QUEUE_HEIGHT - 2)
        hudFrame = SRect(frame.minX, queueFrame.maxY + 4, frame.width, HUD_HEIGHT - 8)
        minimapFrame = SRect(frame.maxX + MINIMAP_GAP, frame.minY, MINIMAP_WIDTH, frame.height)
        containerFrame = SRect(frame.minX, frame.minY - containerHeight + 4, frame.width, containerHeight - 8)
    }
}
