// 스프라이트 시트를 칸별로 잘라 배경을 지운 PNG로 저장한다.
//
// ChatGPT가 만든 시트는 배경이 투명하지 않게 나올 때가 있다. 그래서 칸마다 Vision의 피사체 분리로
// 물체만 남기고, 물체에 꼭 맞게 잘라 정사각형 가운데에 놓은 뒤 정해진 크기로 줄인다.
//
// 사용법: swift Tools/cut_sprites.swift <시트.png> <열> <행> <출력 폴더> <크기> <이름1> <이름2> ...
//   이름은 왼쪽 위부터 가로 순서다. 건너뛸 칸은 "-"로 적는다.
import AppKit
import CoreImage
import Vision

let arguments = CommandLine.arguments
guard arguments.count >= 7, let columns = Int(arguments[2]), let rows = Int(arguments[3]), let outputSize = Int(arguments[5]) else {
    print("usage: cut_sprites.swift <sheet.png> <columns> <rows> <output dir> <size> <name>...")
    exit(1)
}
let names = Array(arguments[6...])
let outputDirectory = URL(fileURLWithPath: arguments[4])
guard let sheet = NSImage(contentsOfFile: arguments[1])?.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
    print("시트를 읽지 못했다: \(arguments[1])")
    exit(1)
}
let context = CIContext()
let cellWidth = sheet.width / columns
let cellHeight = sheet.height / rows

/// 불투명한 픽셀을 감싸는 사각형.
func opaqueBounds(of image: CGImage) -> CGRect? {
    let width = image.width, height = image.height
    var pixels = [UInt8](repeating: 0, count: width * height * 4)
    guard let bitmap = CGContext(
        data: &pixels, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4,
        space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    ) else { return nil }
    bitmap.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
    var minX = width, minY = height, maxX = -1, maxY = -1
    for y in 0..<height {
        for x in 0..<width where pixels[(y * width + x) * 4 + 3] > 24 {
            minX = min(minX, x); maxX = max(maxX, x); minY = min(minY, y); maxY = max(maxY, y)
        }
    }
    guard maxX >= minX, maxY >= minY else { return nil }
    return CGRect(x: minX, y: minY, width: maxX - minX + 1, height: maxY - minY + 1)
}

for (index, name) in names.enumerated() where name != "-" {
    let column = index % columns, row = index / columns
    guard row < rows, let cell = sheet.cropping(to: CGRect(x: column * cellWidth, y: row * cellHeight, width: cellWidth, height: cellHeight)) else {
        print("\(name): 칸이 시트 밖이다")
        continue
    }
    // 피사체만 남긴다.
    let request = VNGenerateForegroundInstanceMaskRequest()
    let handler = VNImageRequestHandler(cgImage: cell)
    try handler.perform([request])
    guard let observation = request.results?.first else {
        print("\(name): 물체를 찾지 못했다")
        continue
    }
    let buffer = try observation.generateMaskedImage(ofInstances: observation.allInstances, from: handler, croppedToInstancesExtent: false)
    let masked = CIImage(cvPixelBuffer: buffer)
    guard let cutout = context.createCGImage(masked, from: masked.extent), let bounds = opaqueBounds(of: cutout),
          let tight = cutout.cropping(to: bounds) else {
        print("\(name): 잘라내지 못했다")
        continue
    }
    // 정사각형 가운데에 놓고 가장자리에 4% 여백을 둔다.
    let side = CGFloat(outputSize)
    let scale = side * 0.92 / CGFloat(max(tight.width, tight.height))
    let drawSize = CGSize(width: CGFloat(tight.width) * scale, height: CGFloat(tight.height) * scale)
    guard let canvas = CGContext(
        data: nil, width: outputSize, height: outputSize, bitsPerComponent: 8, bytesPerRow: 0,
        space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    ) else { continue }
    canvas.interpolationQuality = .high
    canvas.draw(tight, in: CGRect(x: (side - drawSize.width) / 2, y: (side - drawSize.height) / 2, width: drawSize.width, height: drawSize.height))
    guard let result = canvas.makeImage(),
          let data = NSBitmapImageRep(cgImage: result).representation(using: .png, properties: [:]) else { continue }
    let url = outputDirectory.appendingPathComponent(name + ".png")
    try data.write(to: url)
    print("\(name): \(observation.allInstances.count)개 물체, 원본 \(tight.width)x\(tight.height) → \(url.lastPathComponent)")
}
