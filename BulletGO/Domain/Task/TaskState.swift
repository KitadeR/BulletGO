import Foundation

nonisolated enum TaskState: String, Hashable, Codable, Sendable {
    case notStarted
    case inProgress
    case completed
    case skipped
    case cancelled
    case needsReview
    case blocked
    case stale
}
