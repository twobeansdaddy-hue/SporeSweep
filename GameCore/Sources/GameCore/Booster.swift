import Foundation

/// 시작 부스터(6장). 레벨을 시작하기 전에 고르면 판에 미리 적용된다.
public enum Booster: String, CaseIterable, Hashable, Sendable, Codable {
    /// 제염 빔 하나를 보드에 놓고 시작한다.
    case beam
    /// 중화 폭탄 하나를 보드에 놓고 시작한다.
    case bomb
    /// 정화 코어 하나를 보드에 놓고 시작한다.
    case core
    /// 이동 횟수를 늘리고 시작한다.
    case extraMoves

    /// `extraMoves`가 늘려 주는 이동 횟수.
    public static let extraMoveCount = 5
}

extension GameState {
    /// 고른 부스터를 판에 적용한다. 판을 시작하기 전에 한 번만 부른다.
    ///
    /// 특수 블록은 처음 화면에 보이는 구간의 일반 블록 하나와 바뀐다. 자리는 이 판의 난수로 고르므로,
    /// 같은 레벨에서 같은 부스터를 쓰면 늘 같은 자리에 놓인다. 일반 블록을 종류 없는 특수 블록으로 바꾸는
    /// 것이라 새 매치는 생기지 않는다. 놓을 자리가 없으면 그 부스터는 건너뛴다.
    /// - Returns: 놓인 특수 블록의 자리.
    @discardableResult
    public mutating func apply(_ boosters: [Booster]) -> [Position] {
        var placed: [Position] = []
        // 같은 부스터를 여러 번 골라도 순서와 상관없이 같은 결과가 나오도록 정해진 순서로 적용한다.
        for booster in boosters.sorted(by: { $0.rawValue < $1.rawValue }) {
            if booster == .extraMoves {
                if let moves = movesRemaining {
                    movesRemaining = moves + Booster.extraMoveCount
                }
                continue
            }
            let candidates = board.positions(in: activeRange).filter {
                if case .normal = board[$0] { return true }
                return false
            }
            guard !candidates.isEmpty else { continue }
            let position = candidates[generator.nextInt(below: candidates.count)]
            switch booster {
            case .beam:
                board[position] = .beam(generator.nextInt(below: 2) == 0 ? .horizontal : .vertical)
            case .bomb:
                board[position] = .bomb
            case .core:
                board[position] = .core
            case .extraMoves:
                break
            }
            placed.append(position)
        }
        return placed
    }
}
