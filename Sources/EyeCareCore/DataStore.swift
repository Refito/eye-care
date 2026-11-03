import Foundation

public struct DataStore {
    public var url: URL
    public init(url: URL) { self.url = url }

    public func load() throws -> CareData {
        guard FileManager.default.fileExists(atPath: url.path) else { return CareData() }
        return try JSONDecoder().decode(CareData.self, from: Data(contentsOf: url))
    }

    public func save(_ data: CareData) throws {
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(data).write(to: url, options: .atomic)
    }
}
