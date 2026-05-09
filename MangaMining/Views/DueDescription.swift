import Foundation

enum DueDescription {
    /// Renders a `nextReviewAt` date as "X days Y hours" relative to now. Under
    /// 24 hours collapses to "H hours" (or "Less than an hour"). If `date <= now`
    /// returns "Due now". Months/weeks intentionally collapse to days so a
    /// 4-month interval reads as "120 days 0 hours".
    static func string(from date: Date, now: Date = .now) -> String {
        let interval = date.timeIntervalSince(now)
        if interval <= 0 { return "Due now" }
        let totalHours = interval / 3600
        if totalHours < 1 {
            return "Less than an hour"
        }
        if totalHours < 24 {
            let h = Int(totalHours.rounded(.down))
            return "\(h) hour\(h == 1 ? "" : "s")"
        }
        let totalHoursInt = Int(totalHours.rounded(.down))
        let days = totalHoursInt / 24
        let hours = totalHoursInt % 24
        return "\(days) day\(days == 1 ? "" : "s") \(hours) hour\(hours == 1 ? "" : "s")"
    }
}
