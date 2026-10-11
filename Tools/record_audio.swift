// 맥에서 나는 소리를 녹음한다(ScreenCaptureKit). 시뮬레이터의 소리를 영상에 입히는 데 쓴다.
//
// 이 맥의 Xcode에는 시뮬레이터 창을 띄우는 앱이 따로 없어서 창을 녹화할 수 없다. 그래서 화면은
// `simctl io recordVideo`로, 소리는 이 도구로 따로 담은 뒤 `Tools/mux_av.swift`로 합친다.
// 맥에서 나는 소리가 모두 들어가므로 녹음하는 동안 다른 소리를 끈다.
// "화면 및 시스템 오디오 녹음" 권한이 있어야 한다.
// 사용법: record_audio <출력.mp4> <초>   녹음을 시작한 순간에 "START <유닉스 시각>"을 찍는다.
import AVFoundation
import Foundation
import ScreenCaptureKit

let arguments = CommandLine.arguments
guard arguments.count >= 3, let seconds = Double(arguments[2]) else {
    print("usage: record_audio <output.mp4> <seconds>")
    exit(1)
}
let output = URL(fileURLWithPath: arguments[1])
try? FileManager.default.removeItem(at: output)

final class Delegate: NSObject, SCStreamDelegate, SCRecordingOutputDelegate {
    func stream(_ stream: SCStream, didStopWithError error: Error) { print("멈췄다: \(error.localizedDescription)") }
    func recordingOutputDidStartRecording(_ recordingOutput: SCRecordingOutput) {
        print("START \(Date().timeIntervalSince1970)")
        fflush(stdout)
    }
    func recordingOutput(_ recordingOutput: SCRecordingOutput, didFailWithError error: Error) { print("저장하지 못했다: \(error.localizedDescription)") }
}

let delegate = Delegate()
do {
    let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
    guard let display = content.displays.first else {
        print("화면을 찾지 못했다")
        exit(2)
    }
    // 화면은 쓰지 않으므로 아주 작게 담는다.
    let configuration = SCStreamConfiguration()
    configuration.width = 160
    configuration.height = 100
    configuration.minimumFrameInterval = CMTime(value: 1, timescale: 5)
    configuration.capturesAudio = true
    configuration.sampleRate = 48_000
    configuration.channelCount = 2
    let stream = SCStream(filter: SCContentFilter(display: display, excludingWindows: []), configuration: configuration, delegate: delegate)
    let recording = SCRecordingOutputConfiguration()
    recording.outputURL = output
    recording.outputFileType = .mp4
    try stream.addRecordingOutput(SCRecordingOutput(configuration: recording, delegate: delegate))
    try await stream.startCapture()
    try await Task.sleep(for: .seconds(seconds))
    try await stream.stopCapture()
} catch {
    print("녹음하지 못했다: \(error.localizedDescription)")
    exit(3)
}
