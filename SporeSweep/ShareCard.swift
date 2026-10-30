import SwiftUI
import UIKit

/// 랜드마크를 다 복원하면 자랑할 수 있는 그림(8장). 오염된 모습과 되살린 모습을 위아래로 놓는다.
///
/// 인스타그램 스토리 크기(1080×1920)로 그려 그대로 올릴 수 있게 한다.
struct ShareCard: View {
    static let size = CGSize(width: 1080, height: 1920)
    /// 받는 곳. 공유하는 글에 붙인다.
    static let storeURL = URL(string: "https://apps.apple.com/app/id6826591259")!

    var art: LandmarkArt
    var landmarkName: String

    var body: some View {
        VStack(spacing: 36) {
            Text("\(landmarkName) 복원 완료!")
                .font(.game(84))
                .foregroundStyle(Palette.star)
                .multilineTextAlignment(.center)
                .minimumScaleFactor(0.5)
                .lineLimit(2)
                .padding(.horizontal, 60)
            panel(restored: [], caption: "포자가 뒤덮은 모습")
            panel(restored: art.partIDs, caption: "내가 되살린 모습")
            HStack(spacing: 28) {
                Image("share_icon")
                    .resizable()
                    .frame(width: 150, height: 150)
                    .clipShape(RoundedRectangle(cornerRadius: 34))
                VStack(alignment: .leading, spacing: 8) {
                    Text("포자 대청소")
                        .font(.game(64))
                    Text("블록을 맞춰 세계의 랜드마크를 되살려요")
                        .font(.game(32, weight: .bold))
                        .foregroundStyle(.white.opacity(0.75))
                }
            }
            .foregroundStyle(.white)
        }
        .frame(width: Self.size.width, height: Self.size.height)
        .background(
            LinearGradient(colors: [Color(red: 0.07, green: 0.06, blue: 0.35), Color(red: 0.32, green: 0.08, blue: 0.62)], startPoint: .top, endPoint: .bottom)
        )
    }

    private func panel(restored: Set<String>, caption: LocalizedStringKey) -> some View {
        LandmarkView(restored: restored, art: art)
            .frame(width: 960, height: 640)
            .clipShape(RoundedRectangle(cornerRadius: 44))
            .overlay(RoundedRectangle(cornerRadius: 44).stroke(.white.opacity(0.25), lineWidth: 6))
            .overlay(alignment: .topLeading) {
                Text(caption)
                    .font(.game(38))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 26)
                    .padding(.vertical, 12)
                    .background(.black.opacity(0.75), in: Capsule())
                    .padding(24)
            }
    }

    /// 그림으로 그린다. 그릴 수 없으면 `nil`이다.
    @MainActor
    static func render(art: LandmarkArt, landmarkName: String) -> UIImage? {
        let renderer = ImageRenderer(content: ShareCard(art: art, landmarkName: landmarkName))
        renderer.scale = 1
        return renderer.uiImage
    }
}

/// 랜드마크를 다 복원한 도시의 자랑 그림과 글을 공유 창으로 보낸다.
@MainActor
enum LandmarkShare {
    static func share(cityID: String, landmarkName: String) {
        guard let art = LandmarkArt.art(for: cityID),
              let image = ShareCard.render(art: art, landmarkName: landmarkName) else { return }
        let text = String(localized: "포자 대청소에서 \(landmarkName)을 되살렸어요! 같이 지구를 청소해요.")
        let controller = UIActivityViewController(activityItems: [image, "\(text)\n\(ShareCard.storeURL.absoluteString)"], applicationActivities: nil)
        guard let scene = UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene }).first,
              var top = scene.keyWindow?.rootViewController else { return }
        while let presented = top.presentedViewController {
            top = presented
        }
        // 아이패드에서는 공유 창이 떠 있을 자리가 있어야 한다.
        controller.popoverPresentationController?.sourceView = top.view
        controller.popoverPresentationController?.sourceRect = CGRect(x: top.view.bounds.midX, y: top.view.bounds.midY, width: 0, height: 0)
        controller.popoverPresentationController?.permittedArrowDirections = []
        top.present(controller, animated: true)
        Tracker.log(.landmarkShare(city: cityID))
    }
}
