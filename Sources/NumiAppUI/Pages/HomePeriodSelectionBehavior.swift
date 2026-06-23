import Foundation

public enum HomePeriodSelectionBehavior {
    public static func anchorDate(
        currentPeriod: HomePeriod,
        selectedPeriod: HomePeriod,
        currentAnchorDate: Date,
        now: Date = Date()
    ) -> Date {
        guard currentPeriod != selectedPeriod else {
            return currentAnchorDate
        }

        // 切换时间粒度时重锚到当前时间，避免从旧的月初/历史周继续推导出错误区间。
        return now
    }
}
