import LevelData
import SwiftUI

/// 정화한 만큼만 초록으로 돌아오는 지도(8장).
///
/// 포자에 덮인 그림을 깔고, 정화한 자리에만 깨끗한 그림을 가장자리가 번지게 덧그린다.
/// 두 그림은 구도가 같아야 한다. 오염된 그림의 이름은 깨끗한 그림의 이름에 `_polluted`를 붙인 것이다.
struct PurifiedMap: View {
    /// 깨끗한 그림의 이름.
    var image: String
    /// 정화한 자리.
    var patches: [Patch]
    /// 모두 정화했으면 그림 전체가 깨끗하다.
    var isAllClean = false

    /// 정화한 자리 하나.
    struct Patch: Identifiable {
        var id: String
        /// 가운데. 그림의 가로와 세로를 0...1로 본 비율이다.
        var center: Region.Spot
        /// 반지름. 그림의 폭을 1로 본 비율이다.
        var radius: Double
        /// 번진 정도(0...1). 0이면 아직 오염되어 있다.
        var amount: Double = 1
    }

    var body: some View {
        ZStack {
            Image(image + "_polluted")
                .resizable()
                .scaledToFill()
            Image(image)
                .resizable()
                .scaledToFill()
                .mask {
                    GeometryReader { geometry in
                        let size = geometry.size
                        ZStack {
                            Rectangle()
                                .fill(.white)
                                .opacity(isAllClean ? 1 : 0)
                            ForEach(patches) { patch in
                                Blob(seed: patch.id)
                                    .frame(width: patch.radius * size.width * 2, height: patch.radius * size.width * 2)
                                    .scaleEffect(patch.amount)
                                    .position(x: patch.center.x * size.width, y: patch.center.y * size.height)
                            }
                        }
                    }
                }
        }
        .accessibilityHidden(true)
    }

    /// 가장자리가 번지는 울퉁불퉁한 얼룩. 같은 이름이면 늘 같은 모양이다.
    private struct Blob: View {
        var seed: String

        var body: some View {
            GeometryReader { geometry in
                let radius = geometry.size.width / 2
                // 이름에서 뽑은 각도로 작은 원을 둘러 붙여 동그랗지 않게 한다.
                let start = Double(seed.unicodeScalars.reduce(0) { ($0 &* 31 &+ Int($1.value)) % 360 })
                ZStack {
                    lump.frame(width: radius * 1.5, height: radius * 1.5)
                    ForEach(0..<4, id: \.self) { index in
                        let angle = (start + Double(index) * 97) * .pi / 180
                        let size = radius * (0.75 + 0.12 * Double(index % 3))
                        lump
                            .frame(width: size, height: size)
                            .offset(x: cos(angle) * radius * 0.5, y: sin(angle) * radius * 0.5)
                    }
                }
                .frame(width: geometry.size.width, height: geometry.size.height)
            }
        }

        private var lump: some View {
            // 그라디언트의 끝 반지름을 원의 크기에 맞춘다.
            GeometryReader { geometry in
                Circle().fill(
                    RadialGradient(
                        stops: [.init(color: .white, location: 0), .init(color: .white, location: 0.55), .init(color: .clear, location: 1)],
                        center: .center, startRadius: 0, endRadius: geometry.size.width / 2
                    )
                )
            }
        }
    }
}
