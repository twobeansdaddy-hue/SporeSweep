// 홍보 영상을 조립한다. 편집 내용을 적은 JSON을 받아 세로 영상(1080×1920) 한 편을 만든다.
//
// 바탕에는 플레이 영상의 토막을 이어 깔고, 그 위에 그림(자막, 전후 비교, 끝 화면)을 시간에 맞춰 얹는다.
// 그림은 `Tools/make_promos.py`가 만든다.
// 사용법: promo_render <편집.json>
import AVFoundation
import AppKit
import Foundation
import QuartzCore

struct Edit: Decodable {
    var output: String
    var duration: Double
    var segments: [Segment]
    var audio: [Sound]
    var layers: [Layer]

    struct Segment: Decodable {
        var src: String
        /// 원본에서 가져올 곳과 길이, 놓을 곳(초).
        var start: Double
        var at: Double
        var dur: Double
        /// 확대 배율과 화면 가운데에 둘 원본의 자리(0...1).
        var zoomFrom: Double?
        var zoomTo: Double?
        var focus: [Double]?
        /// 이 토막의 소리도 쓸지와 크기.
        var volume: Float?
    }

    struct Sound: Decodable {
        var src: String
        var start: Double
        var at: Double
        var dur: Double
        var volume: Float
    }

    struct Layer: Decodable {
        var image: String
        var at: Double
        var dur: Double
        /// 왼쪽 위를 기준으로 한 자리와 크기.
        var frame: [Double]
        var fadeIn: Double?
        var fadeOut: Double?
        /// 튀어나오듯 나타난다.
        var pop: Bool?
        /// 나타나 있는 동안 천천히 커지는 배율.
        var scaleFrom: Double?
        var scaleTo: Double?
        /// 왼쪽에서 오른쪽으로 닦아 내듯 드러나는 시간.
        var wipe: Double?
    }
}

let size = CGSize(width: 1080, height: 1920)
let edit = try JSONDecoder().decode(Edit.self, from: Data(contentsOf: URL(fileURLWithPath: CommandLine.arguments[1])))
let total = edit.duration
func time(_ seconds: Double) -> CMTime { CMTime(seconds: seconds, preferredTimescale: 600) }

let composition = AVMutableComposition()
let videoTrack = composition.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid)!
let layerInstruction = AVMutableVideoCompositionLayerInstruction(assetTrack: videoTrack)
var mixes: [AVMutableAudioMixInputParameters] = []

func addSound(_ asset: AVURLAsset, start: Double, at: Double, dur: Double, volume: Float) async throws {
    guard let source = try await asset.loadTracks(withMediaType: .audio).first else { return }
    let track = composition.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid)!
    try track.insertTimeRange(CMTimeRange(start: time(start), duration: time(dur)), of: source, at: time(at))
    let parameters = AVMutableAudioMixInputParameters(track: track)
    parameters.setVolume(volume, at: .zero)
    // 토막의 끝에서 짧게 줄여 끊기는 소리가 나지 않게 한다.
    parameters.setVolumeRamp(fromStartVolume: volume, toEndVolume: 0, timeRange: CMTimeRange(start: time(at + dur - 0.25), duration: time(0.25)))
    mixes.append(parameters)
}

for segment in edit.segments {
    let asset = AVURLAsset(url: URL(fileURLWithPath: segment.src))
    guard let source = try await asset.loadTracks(withMediaType: .video).first else { continue }
    try videoTrack.insertTimeRange(CMTimeRange(start: time(segment.start), duration: time(segment.dur)), of: source, at: time(segment.at))
    let natural = try await source.load(.naturalSize)
    // 화면을 꽉 채우고, 원본의 `focus` 자리가 화면 가운데에 오게 한다. 가장자리가 비지 않게 자른다.
    func transform(zoom: Double) -> CGAffineTransform {
        let scale = max(size.width / natural.width, size.height / natural.height) * zoom
        let focus = segment.focus ?? [0.5, 0.47]
        let tx = min(0, max(size.width - natural.width * scale, size.width / 2 - focus[0] * natural.width * scale))
        let ty = min(0, max(size.height - natural.height * scale, size.height / 2 - focus[1] * natural.height * scale))
        return CGAffineTransform(a: scale, b: 0, c: 0, d: scale, tx: tx, ty: ty)
    }
    let range = CMTimeRange(start: time(segment.at), duration: time(segment.dur))
    layerInstruction.setTransformRamp(
        fromStart: transform(zoom: segment.zoomFrom ?? 1), toEnd: transform(zoom: segment.zoomTo ?? segment.zoomFrom ?? 1), timeRange: range
    )
    if let volume = segment.volume, volume > 0 {
        try await addSound(asset, start: segment.start, at: segment.at, dur: segment.dur, volume: volume)
    }
}
for sound in edit.audio {
    try await addSound(AVURLAsset(url: URL(fileURLWithPath: sound.src)), start: sound.start, at: sound.at, dur: sound.dur, volume: sound.volume)
}

// 그림을 얹는다. 애니메이션은 영상 전체 길이에 걸친 키프레임 하나로 적는다.
let parent = CALayer()
parent.frame = CGRect(origin: .zero, size: size)
let videoLayer = CALayer()
videoLayer.frame = parent.frame
parent.addSublayer(videoLayer)

func keyframes(_ path: String, _ points: [(Double, Double)]) -> CAKeyframeAnimation {
    let animation = CAKeyframeAnimation(keyPath: path)
    var sorted = [(0.0, points.first!.1)] + points + [(total, points.last!.1)]
    // 시각이 뒤로 가지 않게 다듬는다.
    for index in 1..<sorted.count where sorted[index].0 < sorted[index - 1].0 { sorted[index].0 = sorted[index - 1].0 }
    animation.values = sorted.map(\.1)
    animation.keyTimes = sorted.map { NSNumber(value: min(max($0.0 / total, 0), 1)) }
    animation.duration = total
    animation.beginTime = AVCoreAnimationBeginTimeAtZero
    animation.isRemovedOnCompletion = false
    animation.fillMode = .both
    return animation
}

for item in edit.layers {
    guard let image = NSImage(contentsOfFile: item.image)?.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
        print("그림을 읽지 못했다: \(item.image)")
        continue
    }
    let layer = CALayer()
    let frame = CGRect(x: item.frame[0], y: size.height - item.frame[1] - item.frame[3], width: item.frame[2], height: item.frame[3])
    layer.frame = frame
    layer.contents = image
    layer.contentsGravity = .resizeAspectFill
    layer.opacity = 0
    let end = item.at + item.dur
    let fadeIn = item.fadeIn ?? 0.001, fadeOut = item.fadeOut ?? 0.001
    // 영상의 첫 순간부터 보이는 그림은 처음부터 불투명하게 둔다.
    let rise: [(Double, Double)] = item.at <= 0 ? [(0, 1)] : [(item.at, 0), (item.at + fadeIn, 1)]
    layer.add(keyframes("opacity", rise + [(end - fadeOut, 1), (end, 0)]), forKey: "opacity")
    if item.pop == true {
        layer.add(keyframes("transform.scale", [(item.at, 0.3), (item.at + 0.13, 1.18), (item.at + 0.22, 1)]), forKey: "pop")
    } else if let from = item.scaleFrom, let to = item.scaleTo {
        layer.add(keyframes("transform.scale", [(item.at, from), (end, to)]), forKey: "scale")
    }
    if let wipe = item.wipe {
        let mask = CALayer()
        mask.backgroundColor = NSColor.black.cgColor
        mask.anchorPoint = CGPoint(x: 0, y: 0)
        mask.frame = CGRect(x: 0, y: 0, width: 0, height: frame.height)
        mask.add(keyframes("bounds.size.width", [(item.at, 0), (item.at + wipe, Double(frame.width))]), forKey: "wipe")
        layer.mask = mask
    }
    parent.addSublayer(layer)
}

let instruction = AVMutableVideoCompositionInstruction()
instruction.timeRange = CMTimeRange(start: .zero, duration: time(total))
instruction.layerInstructions = [layerInstruction]
let videoComposition = AVMutableVideoComposition()
videoComposition.renderSize = size
videoComposition.frameDuration = CMTime(value: 1, timescale: 30)
videoComposition.instructions = [instruction]
videoComposition.animationTool = AVVideoCompositionCoreAnimationTool(postProcessingAsVideoLayer: videoLayer, in: parent)
let mix = AVMutableAudioMix()
mix.inputParameters = mixes

let output = URL(fileURLWithPath: edit.output)
try? FileManager.default.removeItem(at: output)
guard let export = AVAssetExportSession(asset: composition, presetName: AVAssetExportPresetHighestQuality) else { exit(2) }
export.videoComposition = videoComposition
export.audioMix = mix
export.timeRange = CMTimeRange(start: .zero, duration: time(total))
try await export.export(to: output, as: .mp4)
print("저장: \(output.lastPathComponent)")
