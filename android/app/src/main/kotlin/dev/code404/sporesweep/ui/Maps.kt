package dev.code404.sporesweep.ui

import androidx.activity.compose.BackHandler
import androidx.compose.animation.core.Animatable
import androidx.compose.animation.core.FastOutSlowInEasing
import androidx.compose.animation.core.LinearOutSlowInEasing
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.tween
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.aspectRatio
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.requiredSize
import androidx.compose.foundation.layout.safeDrawingPadding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.wrapContentSize
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.selection.selectable
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.KeyboardArrowLeft
import androidx.compose.material.icons.automirrored.filled.KeyboardArrowRight
import androidx.compose.material.icons.filled.Check
import androidx.compose.material.icons.filled.Flight
import androidx.compose.material.icons.filled.Lock
import androidx.compose.material.icons.filled.Place
import androidx.compose.material.icons.filled.Public
import androidx.compose.material3.Icon
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.clipToBounds
import androidx.compose.ui.draw.rotate
import androidx.compose.ui.draw.scale
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.BlendMode
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.CompositingStrategy
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.PathEffect
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.drawscope.DrawScope
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.layout.layout
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.IntOffset
import androidx.compose.ui.unit.IntSize
import androidx.compose.ui.unit.dp
import dev.code404.sporesweep.AppModel
import dev.code404.sporesweep.Assets
import dev.code404.sporesweep.Sound
import dev.code404.sporesweep.board.GameHaptic
import dev.code404.sporesweep.board.GameSound
import dev.code404.sporesweep.core.City
import dev.code404.sporesweep.core.Region
import dev.code404.sporesweep.tr
import kotlinx.coroutines.delay
import kotlin.math.PI
import kotlin.math.abs
import kotlin.math.atan2
import kotlin.math.cos
import kotlin.math.sin

const val FLIGHT_SECONDS = 3.0

/** 정화한 자리 하나. 자리는 그림의 비율, 반지름은 그림의 폭을 1로 본 비율이다. */
data class Patch(val id: String, val center: Region.Spot, val radius: Double, val amount: Double = 1.0)

/** 정화한 만큼만 초록으로 돌아오는 지도(iOS 판 PurifiedMap). 깨끗한 그림을 정화한 자리에만 번지게 덧그린다. */
@Composable
fun PurifiedMap(image: String, patches: List<Patch>, isAllClean: Boolean, modifier: Modifier = Modifier) {
    val polluted = remember(image) { Assets.image(image + "_polluted") }
    val clean = remember(image) { Assets.image(image) }
    Canvas(modifier.graphicsLayer(compositingStrategy = CompositingStrategy.Offscreen)) {
        polluted?.let { drawFill(it) }
        if (clean == null) return@Canvas
        // 깨끗한 그림은 따로 그린 층에서 덩어리 모양만 남긴다.
        drawContext.canvas.saveLayer(androidx.compose.ui.geometry.Rect(Offset.Zero, size), androidx.compose.ui.graphics.Paint())
        if (isAllClean) {
            drawRect(Color.White)
        } else {
            for (patch in patches) blob(patch, size)
        }
        drawFill(clean, BlendMode.SrcIn)
        drawContext.canvas.restore()
    }
}

private fun DrawScope.drawFill(image: androidx.compose.ui.graphics.ImageBitmap, blend: BlendMode = BlendMode.SrcOver) {
    // 비율을 지키며 채운다(scaledToFill).
    val scale = maxOf(size.width / image.width, size.height / image.height)
    val w = image.width * scale
    val h = image.height * scale
    drawImage(
        image, IntOffset.Zero, IntSize(image.width, image.height),
        IntOffset(((size.width - w) / 2).toInt(), ((size.height - h) / 2).toInt()), IntSize(w.toInt(), h.toInt()), blendMode = blend,
    )
}

/** 가장자리가 번지는 울퉁불퉁한 얼룩. 같은 이름이면 늘 같은 모양이다. */
private fun DrawScope.blob(patch: Patch, area: Size) {
    val radius = (patch.radius * area.width * patch.amount).toFloat()
    if (radius <= 0f) return
    val cx = (patch.center.x * area.width).toFloat()
    val cy = (patch.center.y * area.height).toFloat()
    var hash = 0
    for (c in patch.id) hash = (hash * 31 + c.code) % 360
    val start = hash.toDouble()
    fun lump(x: Float, y: Float, diameter: Float) {
        val r = diameter / 2
        drawCircle(
            Brush.radialGradient(0f to Color.White, 0.55f to Color.White, 1f to Color.Transparent, center = Offset(x, y), radius = r),
            radius = r, center = Offset(x, y),
        )
    }
    lump(cx, cy, radius * 1.5f)
    for (index in 0 until 4) {
        val angle = (start + index * 97) * PI / 180
        val d = radius * (0.75f + 0.12f * (index % 3))
        lump(cx + (cos(angle) * radius * 0.5).toFloat(), cy + (sin(angle) * radius * 0.5).toFloat(), d)
    }
}

/** 내용의 가운데를 주어진 자리에 놓는다(SwiftUI의 `.position`). 크기에 제한을 두지 않는다. */
fun Modifier.centerAt(x: Dp, y: Dp): Modifier = layout { measurable, _ ->
    val placeable = measurable.measure(androidx.compose.ui.unit.Constraints())
    layout(0, 0) { placeable.place(x.roundToPx() - placeable.width / 2, y.roundToPx() - placeable.height / 2) }
}

/** 두 자리를 잇는 휘어진 길 위의 한 점과 진행 방향(라디안). 길은 위로 볼록하다. */
fun flightPoint(from: Offset, to: Offset, progress: Float): Pair<Offset, Float> {
    val control = Offset((from.x + to.x) / 2, minOf(from.y, to.y) - abs(to.x - from.x) * 0.45f)
    val t = progress
    val x = (1 - t) * (1 - t) * from.x + 2 * (1 - t) * t * control.x + t * t * to.x
    val y = (1 - t) * (1 - t) * from.y + 2 * (1 - t) * t * control.y + t * t * to.y
    val dx = 2 * (1 - t) * (control.x - from.x) + 2 * t * (to.x - control.x)
    val dy = 2 * (1 - t) * (control.y - from.y) + 2 * t * (to.y - control.y)
    return Offset(x, y) to atan2(dy, dx)
}

/** 비행기가 지나온 길과 비행기. 좌표는 dp다. */
@Composable
fun FlightLayer(from: Offset, to: Offset, progress: Float, arrived: Boolean, lineWidth: Dp, planeSize: Dp) {
    Canvas(Modifier.fillMaxSize()) {
        val path = Path()
        val a = Offset(from.x.dp.toPx(), from.y.dp.toPx())
        val b = Offset(to.x.dp.toPx(), to.y.dp.toPx())
        path.moveTo(a.x, a.y)
        for (step in 1..40) {
            val p = flightPoint(a, b, progress * step / 40).first
            path.lineTo(p.x, p.y)
        }
        drawPath(path, Color.White, style = Stroke(lineWidth.toPx(), cap = StrokeCap.Round, pathEffect = PathEffect.dashPathEffect(floatArrayOf(2.dp.toPx(), (lineWidth * 2.2f).toPx()))))
    }
    if (!arrived) {
        val (point, angle) = flightPoint(from, to, progress)
        val degrees = Math.toDegrees(angle.toDouble()).toFloat()
        val flipped = cos(angle) < 0
        Icon(
            Icons.Filled.Flight, null, tint = Color.White,
            modifier = Modifier.offset((point.x - planeSize.value / 2).dp, (point.y - planeSize.value / 2).dp).size(planeSize)
                .scale(1 + 0.5f * sin(progress * PI).toFloat())
                .rotate(degrees + 90).scale(if (flipped) -1f else 1f, 1f),
        )
    }
}

/** 권역 지도. 권역의 도시를 보여주고, 열린 도시를 누르면 그 도시로 간다(iOS 판 MapView). */
@Composable
fun MapScreen(model: AppModel, region: Region, flight: AppModel.Flight?, onClose: () -> Unit) {
    model.revision
    val progress = remember { Animatable(0f) }
    val spread = remember { Animatable(0f) }
    var arrived by remember { mutableStateOf(false) }
    LaunchedEffect(flight) {
        if (flight == null) return@LaunchedEffect
        delay(500)
        Sound.play(GameSound.RESTORE)
        spread.animateTo(1f, tween(1200, easing = LinearOutSlowInEasing))
        delay(200)
        Sound.play(GameSound.INTRO_ARRIVAL)
        progress.animateTo(1f, tween((FLIGHT_SECONDS * 1000).toInt(), easing = FastOutSlowInEasing))
        Sound.play(GameSound.RESTORE)
        Sound.haptic(GameHaptic.SUCCESS)
        arrived = true
        delay(1300)
        model.select(flight.to)
        onClose()
    }
    BackHandler(flight == null) { onClose() }
    val patches = region.cityIDs.filter { model.hasClearedAllLevels(it) }.mapNotNull { id ->
        region.cityPositions[id]?.let { Patch(id, it, Region.CITY_RADIUS, if (id == flight?.from) spread.value.toDouble() else 1.0) }
    }
    val isAllClean = region.isPlayable && region.cityIDs.all { model.hasClearedAllLevels(it) }
    BoxWithConstraints(Modifier.fillMaxSize().background(Color.Black).clipToBounds()) {
        val width = maxOf(maxHeight * 2 / 3, maxWidth)
        val shift = (maxWidth - width) * region.mapAnchor.toFloat()
        fun place(spot: Region.Spot) = Offset((spot.x * width.value + shift.value).toFloat(), (spot.y * maxHeight.value).toFloat())
        fun point(id: String) = place(region.cityPositions[id] ?: Region.Spot(0.5, 0.5))
        Box(Modifier.wrapContentSize(Alignment.TopStart, unbounded = true).offset(x = shift).requiredSize(width, maxHeight)) {
            PurifiedMap(region.mapImage, patches, isAllClean, Modifier.fillMaxSize())
        }
        if (flight != null) FlightLayer(point(flight.from), point(flight.to), progress.value, arrived, 4.dp, 34.dp)
        for (city in model.cities.filter { it.id in region.cityIDs }) {
            val p = point(city.id)
            CityPin(model, city, flight, arrived, Modifier.centerAt(p.x.dp, p.y.dp), onClose)
        }
        if (flight != null) {
            val city = model.cities.firstOrNull { it.id == flight.to }
            if (city != null) {
                GameText(
                    if (arrived) tr("%@ 도착!", city.name) else tr("다음 목적지는 %@!", city.name), 20f,
                    Modifier.align(Alignment.BottomCenter).padding(bottom = 40.dp).gamePanel(20.dp).padding(horizontal = 20.dp, vertical = 12.dp),
                )
            }
        }
        Box(Modifier.safeDrawingPadding()) {
            GameHeader(
                region.name,
                leading = { if (flight == null) IconButton(Icons.AutoMirrored.Filled.KeyboardArrowLeft, "도시로 돌아가기") { Sound.play(GameSound.TAP); onClose() } },
                trailing = { if (flight == null) IconButton(Icons.Filled.Public, "세계 지도") { Sound.play(GameSound.TAP); model.mapScreen = AppModel.MapScreen.World } },
            )
        }
    }
}

/** 도시 하나의 표시. 열린 도시는 누를 수 있다. */
@Composable
private fun CityPin(model: AppModel, city: City, flight: AppModel.Flight?, arrived: Boolean, modifier: Modifier, onClose: () -> Unit) {
    val isOpen = model.isUnlocked(city.id) && (flight?.to != city.id || arrived)
    val isDone = model.isFullyRestored(city.id)
    val isCurrent = model.city?.id == city.id && flight == null
    val stars = model.stars(city.id)
    val tint = if (!isOpen) GameTint.SLATE else if (isDone) GameTint.GREEN else GameTint.PINK
    val pop by animateFloatAsState(if (flight?.to == city.id && arrived) 1.2f else 1f, label = "pop")
    // SwiftUI는 누를 수 없는 단추를 흐리게 그린다. 같은 모습이 되게 한다.
    Box(modifier.scale(pop).alpha(if (isOpen) 1f else 0.5f)) {
        Column(
            Modifier.selectable(false, enabled = isOpen && flight == null, role = Role.Button) {
                Sound.play(GameSound.TAP)
                model.select(city.id)
                onClose()
            },
            horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(4.dp),
        ) {
            Box(Modifier.padding(bottom = 4.dp).scale(if (isCurrent) 1.15f else 1f).size(44.dp).chunky(tint, radius = 22.dp), contentAlignment = Alignment.Center) {
                Icon(if (!isOpen) Icons.Filled.Lock else if (isDone) Icons.Filled.Check else Icons.Filled.Place, null, tint = Color.White, modifier = Modifier.size(20.dp))
            }
            Column(Modifier.background(Palette.panel.copy(alpha = 0.92f), RoundedCornerShape(50)).padding(horizontal = 10.dp, vertical = 4.dp), horizontalAlignment = Alignment.CenterHorizontally) {
                GameText(city.name, 15f)
                if (isOpen) GameText("★ ${stars.first}/${stars.second}", 11f, color = Palette.star)
            }
        }
    }
}

/** 세계 지도. 권역을 고른다(iOS 판 WorldView). */
@Composable
fun WorldScreen(model: AppModel, flight: AppModel.Flight?, onClose: () -> Unit) {
    model.revision
    val progress = remember { Animatable(0f) }
    val spread = remember { Animatable(0f) }
    var arrived by remember { mutableStateOf(false) }
    val route = flight?.let { f ->
        val from = model.regions.firstOrNull { f.from in it.cityIDs }
        val to = model.regions.firstOrNull { f.to in it.cityIDs }
        if (from != null && to != null) from to to else null
    }
    LaunchedEffect(flight) {
        if (flight == null || route == null) return@LaunchedEffect
        delay(500)
        Sound.play(GameSound.RESTORE)
        spread.animateTo(1f, tween(1200, easing = LinearOutSlowInEasing))
        delay(200)
        Sound.play(GameSound.INTRO_ARRIVAL)
        progress.animateTo(1f, tween((FLIGHT_SECONDS * 1000).toInt(), easing = FastOutSlowInEasing))
        Sound.play(GameSound.RESTORE)
        Sound.haptic(GameHaptic.SUCCESS)
        arrived = true
        delay(1300)
        model.select(flight.to)
        onClose()
    }
    BackHandler(flight == null) { onClose() }

    fun status(region: Region): Int {
        // 0 잠김, 1 준비 중, 2 열림, 3 끝남
        if (route != null && route.second.id == region.id && !arrived) return 0
        if (!model.isUnlockedRegion(region.id)) return 0
        if (!region.isPlayable) return 1
        return if (region.cityIDs.all { model.hasClearedAllLevels(it) }) 3 else 2
    }
    fun tint(status: Int) = when (status) { 2 -> GameTint.PINK; 3 -> GameTint.GREEN; else -> GameTint.SLATE }

    val patches = model.regions.mapNotNull { region ->
        val cleared = region.cityIDs.count { model.hasClearedAllLevels(it) }
        if (cleared == 0) return@mapNotNull null
        val count = region.cityIDs.size.toDouble()
        var share = cleared / count
        if (region.id == route?.first?.id) share -= (1 - spread.value) / count
        Patch(region.id, region.worldSpot, region.worldRadius, 0.4 + 0.6 * share)
    }
    val isAllClean = model.regions.all { r -> r.isPlayable && r.cityIDs.all { model.hasClearedAllLevels(it) } }

    Column(Modifier.fillMaxSize().background(Palette.backdrop).safeDrawingPadding(), verticalArrangement = Arrangement.spacedBy(14.dp)) {
        GameHeader(tr("세계 지도"), leading = { if (flight == null) IconButton(Icons.AutoMirrored.Filled.KeyboardArrowLeft, "도시로 돌아가기") { Sound.play(GameSound.TAP); onClose() } })
        BoxWithConstraints(
            Modifier.padding(horizontal = 16.dp).fillMaxWidth().aspectRatio(1.5f).clip(RoundedCornerShape(18.dp))
                .border(2.dp, Color.White.copy(alpha = 0.14f), RoundedCornerShape(18.dp)),
        ) {
            PurifiedMap("map_world", patches, isAllClean, Modifier.fillMaxSize())
            fun place(region: Region) = Offset((region.worldSpot.x * maxWidth.value).toFloat(), (region.worldSpot.y * maxHeight.value).toFloat())
            model.regions.forEachIndexed { index, region ->
                val p = place(region)
                val s = status(region)
                Box(
                    Modifier.offset((p.x - 12).dp, (p.y - 12).dp).size(24.dp).scale(if (region.id == model.currentRegion?.id) 1.25f else 1f)
                        .background(Brush.verticalGradient(listOf(tint(s).top, tint(s).bottom)), CircleShape).border(2.dp, Color.White, CircleShape),
                    contentAlignment = Alignment.Center,
                ) { GameText("${index + 1}", 13f) }
            }
            if (route != null) FlightLayer(place(route.first), place(route.second), progress.value, arrived, 3.dp, 22.dp)
        }
        if (flight != null && route != null) {
            model.cities.firstOrNull { it.id == flight.to }?.let { city ->
                GameText(
                    if (arrived) tr("%@ 도착!", city.name) else tr("다음 목적지는 %@의 %@!", route.second.name, city.name), 18f,
                    Modifier.align(Alignment.CenterHorizontally).gamePanel(18.dp).padding(horizontal = 18.dp, vertical = 10.dp),
                )
            }
        }
        Column(Modifier.fillMaxWidth().weight(1f).verticalScroll(rememberScrollState()).padding(horizontal = 16.dp).padding(bottom = 16.dp), verticalArrangement = Arrangement.spacedBy(10.dp)) {
            model.regions.forEachIndexed { index, region ->
                val s = status(region)
                val stars = model.starsInRegion(region.id)
                val canOpen = s != 0 && region.mapImage.isNotEmpty()
                val caption = when (s) {
                    0 -> tr("앞 권역을 끝내면 열려요")
                    1 -> tr("준비 중이에요")
                    else -> tr("도시 %lld곳 · ★ %lld/%lld", region.cityIDs.size, stars.first, stars.second)
                }
                Row(
                    Modifier.fillMaxWidth().alpha(if (s == 0) 0.6f else 1f).gamePanel(14.dp)
                        .selectable(false, enabled = canOpen && flight == null, role = Role.Button) {
                            Sound.play(GameSound.TAP)
                            model.mapScreen = AppModel.MapScreen.RegionMap(region.id)
                        }
                        .padding(horizontal = 14.dp, vertical = 10.dp),
                    verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(12.dp),
                ) {
                    Box(Modifier.padding(bottom = 3.dp).size(34.dp).chunky(tint(s), radius = 17.dp, depth = 3.dp), contentAlignment = Alignment.Center) { GameText("${index + 1}", 17f) }
                    Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(2.dp)) {
                        GameText(region.name, 18f, align = TextAlign.Start)
                        GameText(caption, 12f, color = if (s >= 2) Palette.star else Color.White.copy(alpha = 0.6f), align = TextAlign.Start)
                    }
                    Icon(
                        when (s) { 0 -> Icons.Filled.Lock; 3 -> Icons.Filled.Check; else -> Icons.AutoMirrored.Filled.KeyboardArrowRight },
                        null, tint = Color.White.copy(alpha = if (canOpen) 0.9f else 0.45f), modifier = Modifier.size(18.dp),
                    )
                }
            }
        }
    }
}

