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
        try db.remove(id: first.id)
        require(try db.load().map(\.id) == [second.id], "Delete only selected chart")
        let bad = Data("broken JSON".utf8); try bad.write(to: url)
        do { _ = try db.save(chart); fatalError("Must refuse corrupted database") } catch { }
        require(try Data(contentsOf: url) == bad, "Corrupt database must not be overwritten")
        print("Database: 7 checks passed (create/edit/reopen/second/backup/delete/corruption)")
    }
}
