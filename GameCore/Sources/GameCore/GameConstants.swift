import Foundation

/// DESIGN.md 3장의 보드 규격.
public enum GameConstants {
    /// 가로 칸 수.
    public static let columns = 8
    /// 활성 구간의 행 수. 0단계에서는 보드 전체가 활성 구간이다.
    public static let activeRows = 10
    /// 기본 블록 종류 수.
    public static let blockTypes = 5
    /// 레벨이 지정할 수 있는 블록 종류 수의 범위.
    public static let blockTypeRange = 4...6
    /// 매치가 성립하는 최소 일렬 길이.
    public static let minimumMatchLength = 3
    /// 블록 1개를 제거할 때의 기본 점수(6장). 연쇄 번호를 곱한다.
    public static let scorePerBlock = 10
    /// 연쇄 배수의 상한(6장). 연쇄가 길게 이어져도 이보다 크게 곱하지 않는다.
    public static let maximumChainMultiplier = 3
    /// 클리어했을 때 남은 이동 횟수 1회당 더하는 점수.
    public static let scorePerRemainingMove = 100
    /// 포자 둥지가 슬러지를 뱉는 간격. 둥지가 화면에 있는 동안 이만큼의 턴마다 한 번 뱉는다(7장).
    public static let nestSpitInterval = 3
    /// 화면(활성 구간)의 슬러지가 이만큼이면 더 번지지 않는다(7장). 둥지와 시한 포자가 만드는 슬러지는 세지만 막지 않는다.
    public static let sludgeSpreadLimit = 12
}
