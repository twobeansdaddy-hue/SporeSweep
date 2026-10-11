import CoreGraphics
import SpriteKit

/// 효과에 쓰는 빛 그림. 그림 파일 없이 코드로 한 번 그려 두고 색만 입혀 쓴다.
///
/// 단색 네모와 원만으로 그린 효과는 가장자리가 딱딱하다. 가장자리가 번지는 빛을 겹쳐 그려야 화려해 보인다.
@MainActor
enum EffectTexture {
    /// 가운데가 밝고 가장자리로 갈수록 흐려지는 둥근 빛.
    static let glow = make(width: 128, height: 128) { context, size in
        let stops: [(CGFloat, CGFloat)] = [(0, 1), (0.25, 0.75), (0.6, 0.22), (1, 0)]
        radial(in: context, size: size, stops: stops)
    }

    /// 가운데 줄이 밝고 위아래로 흐려지는 띠. 가로로 늘여 빛줄기로 쓴다.
    static let beam = make(width: 8, height: 64) { context, size in
        let colors = [0, 0.35, 1, 1, 0.35, 0].map { white(alpha: $0) } as CFArray
        let locations: [CGFloat] = [0, 0.25, 0.44, 0.56, 0.75, 1]
        guard let gradient = CGGradient(colorsSpace: space, colors: colors, locations: locations) else { return }
        context.drawLinearGradient(gradient, start: .zero, end: CGPoint(x: 0, y: size.height), options: [])
    }

    /// 네 갈래로 뻗는 반짝임.
    static let sparkle = make(width: 128, height: 128) { context, size in
        radial(in: context, size: size, stops: [(0, 0.9), (0.3, 0.25), (0.6, 0)])
        let center = CGPoint(x: size.width / 2, y: size.height / 2)
        let long = size.width / 2
        let short = size.width * 0.045
        let path = CGMutablePath()
        for index in 0..<8 {
            let angle = CGFloat(index) * .pi / 4
            let radius = index.isMultiple(of: 2) ? long : short
            let point = CGPoint(x: center.x + cos(angle) * radius, y: center.y + sin(angle) * radius)
            if index == 0 { path.move(to: point) } else { path.addLine(to: point) }
        }
        path.closeSubpath()
        context.addPath(path)
        context.setFillColor(white(alpha: 1))
        context.fillPath()
    }

    private static let space = CGColorSpaceCreateDeviceRGB()

    private static func white(alpha: CGFloat) -> CGColor {
        CGColor(colorSpace: space, components: [1, 1, 1, alpha]) ?? CGColor(gray: 1, alpha: alpha)
    }

    private static func radial(in context: CGContext, size: CGSize, stops: [(CGFloat, CGFloat)]) {
        let colors = stops.map { white(alpha: $0.1) } as CFArray
        guard let gradient = CGGradient(colorsSpace: space, colors: colors, locations: stops.map(\.0)) else { return }
        let center = CGPoint(x: size.width / 2, y: size.height / 2)
        context.drawRadialGradient(
            gradient, startCenter: center, startRadius: 0, endCenter: center, endRadius: size.width / 2, options: []
        )
    }

    private static func make(width: Int, height: Int, draw: (CGContext, CGSize) -> Void) -> SKTexture {
        guard let context = CGContext(
            data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
            space: space, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return SKTexture() }
        draw(context, CGSize(width: width, height: height))
        return context.makeImage().map(SKTexture.init(cgImage:)) ?? SKTexture()
    }
}
