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

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        try self.init(
            lengthCM: try container.decode(Double.self, forKey: .lengthCM),
            widthCM: try container.decode(Double.self, forKey: .widthCM),
            heightCM: try container.decode(Double.self, forKey: .heightCM)
        )
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(lengthCM, forKey: .lengthCM)
        try container.encode(widthCM, forKey: .widthCM)
        try container.encode(heightCM, forKey: .heightCM)
    }

    private enum CodingKeys: String, CodingKey {
        case lengthCM
        case widthCM
        case heightCM
    }
}
