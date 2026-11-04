import Foundation

@main
struct DatabaseTests {
    static func main() throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("AstraGlass-db-test-" + UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: folder) }
        let url = folder.appendingPathComponent("charts.json")
        let db = ChartDatabase(url: url)
        func require(_ result: Bool, _ message: String) { precondition(result, message) }
        require(try db.load().isEmpty, "New database must be empty")
        var chart = SavedChart(title: "Карта с кириллицей", place: "Москва", input: ChartInput())
        let first = try db.save(chart)
        chart.title = "Изменённая карта"; chart.input.sidereal = true
        let updated = try db.save(chart, id: first.id)
        let reloaded = try ChartDatabase(url: url).load()
        require(reloaded.count == 1 && reloaded[0].chart == chart && updated.id == first.id, "Edit and reopen without duplicates")
        let second = try db.save(SavedChart(title: "Вторая карта", place: "Хельсинки", input: ChartInput()))
        require(try db.load().count == 2, "New record has distinct identity")
        let backup = folder.appendingPathComponent("charts.backup.json")
        require(try ChartDatabase(url: backup).load().count == 1, "Backup contains the previous valid state")
        let exported = folder.appendingPathComponent("export.json")
        try db.export(to: exported)
        let imported = ChartDatabase(url: folder.appendingPathComponent("imported/charts.json"))
        require(try imported.importFile(at: exported) == .init(added: 2), "Import all exported records")
        require(try imported.load() == db.load(), "Export/import preserves inputs, UUIDs and timestamps")
        let beforeRepeat = try Data(contentsOf: imported.url)
        require(try imported.importFile(at: exported) == .init(unchanged: 2), "Repeated import does not duplicate records")
        require(try Data(contentsOf: imported.url) == beforeRepeat, "No-op import does not rewrite database")
        var revised = try db.load()
        revised[0].updatedAt = revised[0].updatedAt.addingTimeInterval(60)
        revised[0].chart.title = "Более свежая карта"
        let incoming = folder.appendingPathComponent("incoming.json")
        let encoder = JSONEncoder(); encoder.dateEncodingStrategy = .iso8601
        try encoder.encode(ChartDatabase.Document(charts: revised)).write(to: incoming)
        require(try imported.importFile(at: incoming) == .init(updated: 1, unchanged: 1), "Newer revision updates matching UUID")
        require(try imported.importFile(at: exported) == .init(unchanged: 2), "Older revision cannot overwrite newer one")
        let existing = try imported.save(SavedChart(title: "Только локальная карта", place: "Москва", input: ChartInput()))
        _ = try imported.importFile(at: exported)
        require(try imported.load().contains(where: { $0.id == existing.id }), "Merge preserves records absent from imported file")
        let beforeInvalid = try Data(contentsOf: imported.url)
        let beforeBackup = try Data(contentsOf: imported.url.deletingLastPathComponent().appendingPathComponent("charts.backup.json"))
        var invalid = revised; invalid[0].chart.input.month = 13
        for badData in [Data("broken JSON".utf8), try encoder.encode(ChartDatabase.Document(format: "unknown", charts: revised)),
                        try encoder.encode(ChartDatabase.Document(charts: [revised[0], revised[0]])),
                        try encoder.encode(ChartDatabase.Document(charts: invalid))] {
            try badData.write(to: incoming)
            do { _ = try imported.importFile(at: incoming); fatalError("Invalid import must fail") } catch { }
            require(try Data(contentsOf: imported.url) == beforeInvalid, "Failed import leaves database intact")
            require(try Data(contentsOf: imported.url.deletingLastPathComponent().appendingPathComponent("charts.backup.json")) == beforeBackup, "Failed import preserves backup")
        }
        let empty = ChartDatabase(url: folder.appendingPathComponent("missing.json"))
        try empty.export(to: incoming)
        require(try imported.importFile(at: incoming) == .init(), "Empty database round trip is a no-op")
        try db.remove(id: first.id)
        require(try db.load().map(\.id) == [second.id], "Delete only selected chart")
        let bad = Data("broken JSON".utf8); try bad.write(to: url)
        do { _ = try db.save(chart); fatalError("Must refuse corrupted database") } catch { }
        require(try Data(contentsOf: url) == bad, "Corrupt database must not be overwritten")
        print("Database: CRUD, backup, full round trip, repeat import, newer/older revision merge, local-only records, 4 invalid imports and empty export passed")
    }
}
