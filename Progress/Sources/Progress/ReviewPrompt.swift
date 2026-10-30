import Foundation

/// 별점 창을 언제 띄울지 정한다(8장).
///
/// 랜드마크를 다 복원한 기분 좋은 순간에만 묻는다. 처음, 세 번째, 여섯 번째로 다 복원했을 때 한 번씩이다.
/// 창을 실제로 띄울지는 운영체제가 다시 정한다(iOS와 안드로이드 모두 일 년에 몇 번으로 막는다).
public enum ReviewPrompt {
    /// 다 복원한 랜드마크가 이 수가 되면 묻는다.
    public static let milestones = [1, 3, 6]

    /// - Parameters:
    ///   - completed: 다 복원한 랜드마크 수.
    ///   - askedAt: 지난번에 물었을 때의 수. 물은 적이 없으면 0이다.
    public static func shouldAsk(completed: Int, askedAt: Int) -> Bool {
        milestones.contains(completed) && completed > askedAt
    }
}
