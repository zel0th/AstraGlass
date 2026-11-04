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
    let url: URL
    static var defaultURL: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("AstraGlass/charts.json")
    }

    func load() throws -> [StoredChart] {
        guard FileManager.default.fileExists(atPath: url.path) else { return [] }
        let data = try Data(contentsOf: url)
        let decoder = JSONDecoder(); decoder.dateDecodingStrategy = .iso8601
        let document = try decoder.decode(Document.self, from: data)
        guard document.format == "AstraGlass.database.v1",
              Set(document.charts.map(\.id)).count == document.charts.count else {
            throw CocoaError(.fileReadCorruptFile)
        }
        for item in document.charts { try item.chart.validate() }
        return document.charts.sorted { $0.updatedAt > $1.updatedAt }
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

    private func write(_ charts: [StoredChart]) throws {
        let encoder = JSONEncoder(); encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        let data = try encoder.encode(Document(charts: charts))
        let directory = url.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        if FileManager.default.fileExists(atPath: url.path) {
            try Data(contentsOf: url).write(to: directory.appendingPathComponent("charts.backup.json"), options: .atomic)
        }
        try data.write(to: url, options: .atomic)
    }
}
