import Foundation

nonisolated struct TaskDependency: Hashable, Codable, Sendable {
    var path: DomainPath
    var requiredTaskID: TaskID?
}
