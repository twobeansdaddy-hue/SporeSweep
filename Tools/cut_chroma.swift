// 초록 단색 배경의 스프라이트 시트를 물체별로 잘라 투명 PNG로 저장한다.
//
// 격자대로 자르지 않는다. ChatGPT가 만든 그림은 물체가 칸을 조금 넘기도 해서, 배경을 지운 뒤
// 이어진 덩어리를 찾고 그 중심이 놓인 칸에 배정한다. 배경은 그림 가장자리에서 이어진 초록만 지우므로
// 물체 안쪽의 초록(불빛 등)은 남는다. 이름 앞에 "+"를 붙이면 물체 안쪽에 갇힌 초록도 지운다(철망의 구멍).
//
// 사용법: swift Tools/cut_chroma.swift <시트.png> <열> <행> <출력 폴더> <크기> <이름>...
//   이름은 왼쪽 위부터 가로 순서다. 건너뛸 칸은 "-"로 적는다.
//   이름 앞에 "="를 붙이면 정사각형에 맞추지 않고 물체에 꼭 맞게 자른다(긴 변이 <크기>가 된다).
import AppKit

let arguments = CommandLine.arguments
guard arguments.count >= 7, let columns = Int(arguments[2]), let rows = Int(arguments[3]), let outputSize = Int(arguments[5]) else {
    print("usage: cut_chroma.swift <sheet.png> <columns> <rows> <output dir> <size> <name>...")
    exit(1)
}
let names = Array(arguments[6...])
guard let sheet = NSImage(contentsOfFile: arguments[1])?.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
    print("시트를 읽지 못했다: \(arguments[1])")
    exit(1)
}
let width = sheet.width, height = sheet.height
var pixels = [UInt8](repeating: 0, count: width * height * 4)
let space = CGColorSpaceCreateDeviceRGB()
let info = CGImageAlphaInfo.premultipliedLast.rawValue
// 비트맵 메모리의 0행이 그림의 맨 위 줄이다.
let bitmap = CGContext(data: &pixels, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4, space: space, bitmapInfo: info)!
bitmap.draw(sheet, in: CGRect(x: 0, y: 0, width: width, height: height))

func isGreen(_ i: Int) -> Bool {
    let r = Double(pixels[i * 4]), g = Double(pixels[i * 4 + 1]), b = Double(pixels[i * 4 + 2])
    return g > 110 && g > r * 1.35 && g > b * 1.35
}

// 1. 가장자리에서 이어진 초록을 배경으로 표시한다.
var background = [Bool](repeating: false, count: width * height)
var stack: [Int] = []
func seed(_ i: Int) {
    if !background[i], isGreen(i) { background[i] = true; stack.append(i) }
}
for x in 0..<width { seed(x); seed((height - 1) * width + x) }
for y in 0..<height { seed(y * width); seed(y * width + width - 1) }
while let i = stack.popLast() {
    let x = i % width, y = i / width
    if x > 0 { seed(i - 1) }
    if x < width - 1 { seed(i + 1) }
    if y > 0 { seed(i - width) }
    if y < height - 1 { seed(i + width) }
}

// 2. 이어진 물체 덩어리를 찾아 중심이 놓인 칸에 배정한다.
var label = [Int32](repeating: -1, count: width * height)
var cellOfLabel: [Int] = []
var count: Int32 = 0
for start in 0..<(width * height) where !background[start] && label[start] < 0 {
    var sumX = 0, sumY = 0, size = 0
    var queue = [start]
    label[start] = count
    while let i = queue.popLast() {
        let x = i % width, y = i / width
        sumX += x; sumY += y; size += 1
        for n in [x > 0 ? i - 1 : -1, x < width - 1 ? i + 1 : -1, y > 0 ? i - width : -1, y < height - 1 ? i + width : -1]
        where n >= 0 && !background[n] && label[n] < 0 {
            label[n] = count
            queue.append(n)
        }
    }
    // 티끌은 버린다.
    let column = min(sumX / size * columns / width, columns - 1), row = min(sumY / size * rows / height, rows - 1)
    cellOfLabel.append(size >= 40 ? row * columns + column : -1)
    count += 1
}

for (cell, rawName) in names.enumerated() where rawName != "-" {
    var name = rawName
    var tight = false, punchHoles = false
    while let first = name.first, "=+".contains(first) {
        if first == "=" { tight = true } else { punchHoles = true }
        name.removeFirst()
    }
    var minX = width, minY = height, maxX = -1, maxY = -1
    for i in 0..<(width * height) where label[i] >= 0 && cellOfLabel[Int(label[i])] == cell {
        let x = i % width, y = i / width
        minX = min(minX, x); maxX = max(maxX, x); minY = min(minY, y); maxY = max(maxY, y)
    }
    guard maxX >= minX else {
        print("\(name): 물체를 찾지 못했다")
        continue
    }
    let w = maxX - minX + 1, h = maxY - minY + 1
    var out = [UInt8](repeating: 0, count: w * h * 4)
    for y in 0..<h {
        for x in 0..<w {
            let i = (minY + y) * width + minX + x
            guard label[i] >= 0, cellOfLabel[Int(label[i])] == cell else { continue }
            if punchHoles, isGreen(i) { continue }
            var r = pixels[i * 4], g = pixels[i * 4 + 1], b = pixels[i * 4 + 2]
            // 배경과 맞닿은 가장자리에 밴 초록을 뺀다.
            var nearBackground = false
            for dy in -2...2 where !nearBackground {
                for dx in -2...2 {
                    let nx = minX + x + dx, ny = minY + y + dy
                    if nx < 0 || ny < 0 || nx >= width || ny >= height { nearBackground = true; break }
                    let n = ny * width + nx
                    if background[n] || (punchHoles && isGreen(n)) { nearBackground = true; break }
                }
            }
            if nearBackground, g > max(r, b) {
                g = max(r, b)
                r = UInt8(Double(r) * 0.8); g = UInt8(Double(g) * 0.8); b = UInt8(Double(b) * 0.8)
            }
            let o = (y * w + x) * 4
            out[o] = r; out[o + 1] = g; out[o + 2] = b; out[o + 3] = 255
        }
    }
    let cut = out.withUnsafeMutableBytes { buffer in
        CGContext(data: buffer.baseAddress, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4, space: space, bitmapInfo: info)!.makeImage()!
    }
    let side = CGFloat(outputSize)
    let scale = side * (tight ? 1 : 0.94) / CGFloat(max(w, h))
    let drawSize = CGSize(width: (CGFloat(w) * scale).rounded(), height: (CGFloat(h) * scale).rounded())
    let canvasSize = tight ? drawSize : CGSize(width: side, height: side)
    let canvas = CGContext(data: nil, width: Int(canvasSize.width), height: Int(canvasSize.height), bitsPerComponent: 8, bytesPerRow: 0, space: space, bitmapInfo: info)!
    canvas.interpolationQuality = .high
    canvas.draw(cut, in: CGRect(x: (canvasSize.width - drawSize.width) / 2, y: (canvasSize.height - drawSize.height) / 2, width: drawSize.width, height: drawSize.height))
    let data = NSBitmapImageRep(cgImage: canvas.makeImage()!).representation(using: .png, properties: [:])!
    try data.write(to: URL(fileURLWithPath: arguments[4]).appendingPathComponent(name + ".png"))
    print("\(name): 원본 \(w)x\(h) (x \(minX)...\(maxX)) → \(Int(canvasSize.width))x\(Int(canvasSize.height))")
}
