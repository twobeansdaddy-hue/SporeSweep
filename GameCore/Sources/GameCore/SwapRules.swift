import Foundation

/// 스왑이 받아들여지지 않는 이유.
public enum SwapRejection: Hashable, Sendable, Codable {
    /// 보드나 활성 구간 밖의 칸을 가리킨다.
    case outOfBounds
    /// 두 칸이 상하좌우로 붙어 있지 않다.
    case notAdjacent
    /// 한쪽 칸이 비어 있다.
    case emptyCell
    /// 교환해도 매치가 생기지 않고 특수 블록도 발동하지 않는다.
    case noMatch
    /// 판이 이미 끝났다.
    case gameOver
    /// 움직일 수 없는 칸이다. 큰 오염 물질, 장애물, 철망에 갇힌 블록이 그렇다.
    case immovable
}

extension Board {
    /// 스왑을 검증한다. 유효하면 `nil`을 반환한다.
    ///
    /// `rows`를 주면 그 행 범위(활성 구간) 안에서만 조작과 매치를 인정한다.
    public func rejection(for swap: Swap, in rows: Range<Int>? = nil) -> SwapRejection? {
        let range = rowRange(rows)
        guard contains(swap.from), contains(swap.to),
              range.contains(swap.from.row), range.contains(swap.to.row)
        else { return .outOfBounds }
        guard swap.isAdjacent else { return .notAdjacent }
        guard let first = self[swap.from], let second = self[swap.to] else { return .emptyCell }
        guard first.isSwappable, second.isSwappable else { return .immovable }
        if first != .material, second != .material {
            // 특수 블록은 아무 블록과 스왑해도 옮겨 간 자리에서 발동한다. 특수 블록끼리는 조합 효과가 난다(4장).
            if first.isSpecial || second.isSpecial {
                return nil
            }
        }
        // 오염 물질과의 스왑도 그 스왑으로 매치가 성립할 때만 허용한다(5장).
        var swapped = self
        swapped.swapAt(swap.from, swap.to)
        guard swapped.hasMatch(at: swap.from, in: range) || swapped.hasMatch(at: swap.to, in: range) else {
            return .noMatch
        }
        return nil
    }

    public func isValid(_ swap: Swap, in rows: Range<Int>? = nil) -> Bool {
        rejection(for: swap, in: rows) == nil
    }

    /// 매치를 만들거나 특수 블록을 발동시키는 스왑을 모두 찾는다.
    ///
    /// 한 쌍은 한 번만 나오고, `from`이 왼쪽 또는 위쪽 칸이다.
    public func possibleMoves(in rows: Range<Int>? = nil) -> [Swap] {
        adjacentPairs(in: rows).filter { isValid($0, in: rows) }
    }

    public func hasPossibleMove(in rows: Range<Int>?) -> Bool {
        adjacentPairs(in: rows).contains { isValid($0, in: rows) }
    }

    public var hasPossibleMove: Bool {
        hasPossibleMove(in: nil)
    }

    /// 붙어 있는 두 칸의 모든 쌍. 각 칸에서 오른쪽과 아래쪽만 본다.
    private func adjacentPairs(in rows: Range<Int>?) -> [Swap] {
        let range = rowRange(rows)
        return positions(in: range).flatMap { from in
            [
                Position(column: from.column + 1, row: from.row),
                Position(column: from.column, row: from.row + 1),
            ]
            .filter { contains($0) && range.contains($0.row) }
            .map { Swap(from: from, to: $0) }
        }
    }
}
