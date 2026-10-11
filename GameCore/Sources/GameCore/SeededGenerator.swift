import Foundation

/// 시드로 초기화하는 난수 생성기(SplitMix64).
///
/// 게임 규칙은 이 생성기 하나만 쓴다. 표준 라이브러리의 `random(in:using:)`은
/// 버전에 따라 구현이 바뀔 수 있으므로 범위 추출도 여기서 직접 한다.
public struct SeededGenerator: RandomNumberGenerator, Hashable, Sendable, Codable {
    private var state: UInt64

    public init(seed: UInt64) {
        state = seed
    }

    public mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }

    /// `0..<upperBound`에서 균등하게 하나를 뽑는다.
    public mutating func nextInt(below upperBound: Int) -> Int {
        precondition(upperBound > 0, "upperBound는 1 이상이어야 한다")
        let bound = UInt64(upperBound)
        let limit = UInt64.max - UInt64.max % bound
        var value = next()
        while value >= limit {
            value = next()
        }
        return Int(value % bound)
    }
}
