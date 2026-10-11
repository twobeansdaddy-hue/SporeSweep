// 영상 파일의 화면과 다른 파일의 소리를 합친다.
// 사용법: mux_av <화면.mp4> <소리.mp4> <소리에서 건너뛸 초> <출력.mp4>
import AVFoundation
import Foundation

let arguments = CommandLine.arguments
guard arguments.count >= 5, let skip = Double(arguments[3]) else {
    print("usage: mux_av <video.mp4> <audio.mp4> <audio offset seconds> <output.mp4>")
    exit(1)
}
let video = AVURLAsset(url: URL(fileURLWithPath: arguments[1]))
let audio = AVURLAsset(url: URL(fileURLWithPath: arguments[2]))
let output = URL(fileURLWithPath: arguments[4])
try? FileManager.default.removeItem(at: output)

do {
    let composition = AVMutableComposition()
    guard let videoTrack = try await video.loadTracks(withMediaType: .video).first,
          let audioTrack = try await audio.loadTracks(withMediaType: .audio).first else {
        print("화면이나 소리가 없다")
        exit(2)
    }
    let duration = try await video.load(.duration)
    let audioDuration = try await audio.load(.duration)
    let start = CMTime(seconds: max(skip, 0), preferredTimescale: 600)
    let length = min(duration, audioDuration - start)
    let target = composition.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid)!
    try target.insertTimeRange(CMTimeRange(start: .zero, duration: duration), of: videoTrack, at: .zero)
    target.preferredTransform = try await videoTrack.load(.preferredTransform)
    let sound = composition.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid)!
    try sound.insertTimeRange(CMTimeRange(start: start, duration: length), of: audioTrack, at: .zero)
    guard let export = AVAssetExportSession(asset: composition, presetName: AVAssetExportPresetMediumQuality) else { exit(3) }
    try await export.export(to: output, as: .mp4)
    print("저장: \(output.lastPathComponent) \(duration.seconds)초")
} catch {
    print("합치지 못했다: \(error.localizedDescription)")
    exit(4)
}
