import Foundation

nonisolated struct BaggageDimensions: Hashable, Codable, Sendable {
    let lengthCM: Double
    let widthCM: Double
    let heightCM: Double

    var totalCM: Double { lengthCM + widthCM + heightCM }

    init(lengthCM: Double, widthCM: Double, heightCM: Double) throws {
        guard lengthCM > 0, widthCM > 0, heightCM > 0 else {
            throw DomainError.invalidBaggageDimension
        }
        self.lengthCM = lengthCM
        self.widthCM = widthCM
        self.heightCM = heightCM
    }
}
