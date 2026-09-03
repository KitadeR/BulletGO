import Foundation

nonisolated enum BundleResource {
    static func jsonData(
        named name: String,
        in bundle: Bundle,
        subdirectories: [String]
    ) throws -> Data {
        let subdirectoryURLs = subdirectories.compactMap { subdirectory in
            bundle.url(forResource: name, withExtension: "json", subdirectory: subdirectory)
        }
        let candidates = subdirectoryURLs + [bundle.url(forResource: name, withExtension: "json")].compactMap { $0 }
        guard let url = candidates.first else {
            throw EngineError.missingResource(name)
        }
        return try Data(contentsOf: url)
    }
}
