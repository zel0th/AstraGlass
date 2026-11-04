import Foundation

struct SavedChart: Codable, Equatable, Sendable {
    var format = "AstraGlass.chart.v1"
    var title: String
    var place: String
    var input: ChartInput

    func validate() throws {
        guard format == "AstraGlass.chart.v1" else { throw CocoaError(.fileReadCorruptFile) }
        try input.validate()
    }
}

struct StoredChart: Codable, Identifiable, Equatable, Sendable {
    let id: UUID
    let createdAt: Date
    var updatedAt: Date
    var chart: SavedChart
}

/// Versioned JSON, atomic replacement and a last-good backup. No personal data
/// is written into the app bundle, project directory or a network service.
struct ChartDatabase {
    struct Document: Codable {
        var format = "AstraGlass.database.v1"
        var charts: [StoredChart] = []
    }
    struct ImportResult: Equatable {
        var added = 0
        var updated = 0
        var unchanged = 0
    }
    let url: URL
    static var defaultURL: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("AstraGlass/charts.json")
    }

    func load() throws -> [StoredChart] {
        guard FileManager.default.fileExists(atPath: url.path) else { return [] }
        return try Self.decode(Data(contentsOf: url))
    }

    private static func decode(_ data: Data) throws -> [StoredChart] {
        let decoder = JSONDecoder(); decoder.dateDecodingStrategy = .iso8601
        let document = try decoder.decode(Document.self, from: data)
        guard document.format == "AstraGlass.database.v1",
              Set(document.charts.map(\.id)).count == document.charts.count else {
            throw CocoaError(.fileReadCorruptFile)
        }
        for item in document.charts { try item.chart.validate() }
        return document.charts.sorted { $0.updatedAt > $1.updatedAt }
    }

    /// Export the same versioned document used on disk, including record identities.
    func export(to destination: URL) throws {
        try Self.encode(load()).write(to: destination, options: .atomic)
    }

    /// Validate the entire incoming file before touching the database. Newer
    /// revisions win; equal/older revisions and repeated imports are harmless.
    @discardableResult
    func importFile(at source: URL) throws -> ImportResult {
        let incoming = try Self.decode(Data(contentsOf: source))
        var records = Dictionary(uniqueKeysWithValues: try load().map { ($0.id, $0) })
        var result = ImportResult()
        for item in incoming {
            if let existing = records[item.id] {
                if item.updatedAt > existing.updatedAt {
                    records[item.id] = item; result.updated += 1
                } else { result.unchanged += 1 }
            } else { records[item.id] = item; result.added += 1 }
        }
        if result.added + result.updated > 0 { try write(Array(records.values)) }
        return result
    }

    @discardableResult
    func save(_ chart: SavedChart, id: UUID? = nil) throws -> StoredChart {
        try chart.validate()
        var charts = try load() // Never silently overwrite an unreadable database.
        let now = Date()
        let old = charts.first { $0.id == id }
        let record = StoredChart(id: old?.id ?? id ?? UUID(), createdAt: old?.createdAt ?? now,
                                 updatedAt: now, chart: chart)
        charts.removeAll { $0.id == record.id }; charts.insert(record, at: 0)
        try write(charts)
        return record
    }

    func remove(id: UUID) throws {
        var charts = try load(); charts.removeAll { $0.id == id }; try write(charts)
    }

    private static func encode(_ charts: [StoredChart]) throws -> Data {
        let encoder = JSONEncoder(); encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        return try encoder.encode(Document(charts: charts.sorted { $0.id.uuidString < $1.id.uuidString }))
    }

    private func write(_ charts: [StoredChart]) throws {
        let data = try Self.encode(charts)
        let directory = url.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        if FileManager.default.fileExists(atPath: url.path) {
            try Data(contentsOf: url).write(to: directory.appendingPathComponent("charts.backup.json"), options: .atomic)
        }
        try data.write(to: url, options: .atomic)
    }
}
