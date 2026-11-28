import Foundation

/// Decides when a widget needs a fresh timeline entry so live elements (clock, countdown,
/// progress) stay current without waking the app.
enum RefreshPlanner {
    /// Entry dates for a design, starting at (or just before) `now`.
    static func entryDates(for design: WidgetDesign?, now: Date) -> [Date] {
        let calendar = Calendar.current
        guard let design else {
            return [now]
        }

        // Clocks: one entry per minute for the next 90 minutes.
        if design.elements.contains(where: { $0.needsMinuteUpdates }) {
            let start = calendar.dateInterval(of: .minute, for: now)?.start ?? now
            return (0..<90).compactMap { calendar.date(byAdding: .minute, value: $0, to: start) }
        }

        // Day progress moves about 1% every 15 minutes. Storage and device stats (battery,
        // network, ...) don't need to be any fresher than that either.
        let usesFrequentRefresh = design.elements.contains {
            $0.kind == .device || $0.kind == .formula
                || ($0.kind == .progress && ($0.progressSource == .day || $0.progressSource == .storage || $0.progressSource == .battery))
        }
        if usesFrequentRefresh {
            let start = calendar.dateInterval(of: .hour, for: now)?.start ?? now
            return (0..<96).compactMap { calendar.date(byAdding: .minute, value: $0 * 15, to: start) }
        }

        // Week / month / year progress: hourly for a day.
        let usesLongProgress = design.elements.contains { $0.kind == .progress && $0.progressSource != .manual }
        if usesLongProgress {
            let start = calendar.dateInterval(of: .hour, for: now)?.start ?? now
            return (0..<24).compactMap { calendar.date(byAdding: .hour, value: $0, to: start) }
        }

        // Everything else only changes at midnight (dates, countdown days).
        var dates: [Date] = [now]
        let midnight = calendar.startOfDay(for: now)
        for offset in 1...7 {
            if let next = calendar.date(byAdding: .day, value: offset, to: midnight) {
                dates.append(next)
            }
        }
        return dates
    }
}
