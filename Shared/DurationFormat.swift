import Foundation

nonisolated enum DurationFormat {
    /// "5 min", "1 h", "1 h 30 min", "45 s", "2 min 30 s" (units follow the app language).
    static func short(_ seconds: Int) -> String {
        let h = seconds / 3600, m = seconds % 3600 / 60, s = seconds % 60
        var parts: [String] = []
        if h > 0 { parts.append(L("duration.h", String(h))) }
        if m > 0 { parts.append(L("duration.min", String(m))) }
        if s > 0 { parts.append(L("duration.s", String(s))) }
        return parts.isEmpty ? L("duration.s", "0") : parts.joined(separator: " ")
    }

    /// "1:23:45".
    static func clock(_ seconds: TimeInterval) -> String {
        let s = max(0, Int(seconds.rounded(.down)))
        return String(format: "%d:%02d:%02d", s / 3600, s % 3600 / 60, s % 60)
    }
}
