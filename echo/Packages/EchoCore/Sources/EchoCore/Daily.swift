import Foundation

/// Jours du défi. Un jour va de minuit à minuit en heure universelle (UTC), soit 1 h ou 2 h du matin en France :
/// tout le monde a le même défi en même temps, comme le classement quotidien de Game Center (réglé sur 00:00 UTC).
public enum DayKey {
    private static let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }()

    /// « 2026-10-30 ».
    public static func key(for date: Date) -> String {
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
    }

    public static func today(_ now: Date = Date()) -> String { key(for: now) }

    /// Le jour d'avant (« 2026-10-29 » pour « 2026-10-30 »).
    public static func previous(_ day: String) -> String? {
        guard let date = date(of: day), let before = calendar.date(byAdding: .day, value: -1, to: date) else { return nil }
        return key(for: before)
    }

    public static func date(of day: String) -> Date? {
        let parts = day.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3 else { return nil }
        return calendar.date(from: DateComponents(year: parts[0], month: parts[1], day: parts[2]))
    }

    /// Temps restant avant le prochain défi.
    public static func secondsUntilNextDay(_ now: Date = Date()) -> TimeInterval {
        let start = calendar.startOfDay(for: now)
        let next = calendar.date(byAdding: .day, value: 1, to: start) ?? now
        return max(0, next.timeIntervalSince(now))
    }

    /// Graine du défi du jour : la même pour tout le monde ce jour-là.
    public static func dailySeed(_ day: String) -> UInt64 {
        SeededRandom.seed(from: "echo-daily-\(day)")
    }
}
