// 시뮬레이터 창을 소리와 함께 녹화한다(ScreenCaptureKit).
//
// `simctl io recordVideo`는 소리를 담지 않는다. 이 도구는 시뮬레이터 앱의 창과 그 앱이 내는 소리를 함께 담는다.
// 터미널(또는 이 도구를 돌리는 앱)에 "화면 및 시스템 오디오 녹음" 권한이 있어야 한다.
// 사용법: swift Tools/record_sim.swift <출력.mp4> <초>
import AVFoundation
import Foundation
import ScreenCaptureKit

let arguments = CommandLine.arguments
guard arguments.count >= 3, let seconds = Double(arguments[2]) else {
    print("usage: record_sim.swift <output.mp4> <seconds>")
    exit(1)
}
let output = URL(fileURLWithPath: arguments[1])
try? FileManager.default.removeItem(at: output)

final class Delegate: NSObject, SCStreamDelegate, SCRecordingOutputDelegate {
    func stream(_ stream: SCStream, didStopWithError error: Error) {
        print("녹화가 멈췄다: \(error.localizedDescription)")
    }
    func recordingOutput(_ recordingOutput: SCRecordingOutput, didFailWithError error: Error) {
        print("저장하지 못했다: \(error.localizedDescription)")
    }
}

let delegate = Delegate()
do {
    let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
    // 시뮬레이터의 기기 창. 가장 큰 창을 고른다.
    let windows = content.windows.filter { $0.owningApplication?.bundleIdentifier == "com.apple.iphonesimulator" && $0.frame.height > 300 }
    guard let window = windows.max(by: { $0.frame.height < $1.frame.height }) else {
        print("시뮬레이터 창을 찾지 못했다. Simulator 앱을 열어 창이 보이게 한다.")
        exit(2)
    }
    let configuration = SCStreamConfiguration()
    configuration.width = Int(window.frame.width * 2)
    configuration.height = Int(window.frame.height * 2)
    configuration.minimumFrameInterval = CMTime(value: 1, timescale: 60)
    configuration.capturesAudio = true
    configuration.sampleRate = 48_000
    configuration.channelCount = 2
    configuration.showsCursor = false
    let stream = SCStream(filter: SCContentFilter(desktopIndependentWindow: window), configuration: configuration, delegate: delegate)
    let recording = SCRecordingOutputConfiguration()
    recording.outputURL = output
    recording.outputFileType = .mp4
    recording.videoCodecType = .h264
    try stream.addRecordingOutput(SCRecordingOutput(configuration: recording, delegate: delegate))
    try await stream.startCapture()
    print("녹화 시작: \(Int(window.frame.width))×\(Int(window.frame.height))")
    try await Task.sleep(for: .seconds(seconds))
    try await stream.stopCapture()
    print("저장: \(output.path)")
} catch {
    print("녹화하지 못했다: \(error.localizedDescription)")
    exit(3)
}
