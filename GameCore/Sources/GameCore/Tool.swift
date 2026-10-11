/// 판을 하는 중에 쓰는 아이템(6장). 이동 횟수를 쓰지 않는다.
public enum Tool: String, CaseIterable, Sendable, Codable {
    /// 정화 망치. 고른 칸 하나를 부순다. 장애물이면 한 번 때린 것으로 친다.
    case hammer
    /// 자리 바꾸기. 붙어 있는 두 블록을 매치가 되지 않아도 바꾼다.
    case swap
    /// 섞기. 보드의 일반 블록을 다시 섞는다.
    case shuffle
}
