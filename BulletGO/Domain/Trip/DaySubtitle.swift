import Foundation

nonisolated struct DaySubtitle: Hashable, Codable, Sendable {
    var date: LocalDate
    var text: String
}

extension Trip {
    nonisolated func daySubtitle(on date: LocalDate) -> String? {
        guard let text = daySubtitles.first(where: { $0.date == date })?.text else {
            return nil
        }
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    nonisolated mutating func setDaySubtitle(_ text: String?, on date: LocalDate) {
        daySubtitles.removeAll { $0.date == date }
        let trimmed = text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !trimmed.isEmpty else { return }
        daySubtitles.append(DaySubtitle(date: date, text: trimmed))
        daySubtitles.sort { $0.date < $1.date }
    }
}
