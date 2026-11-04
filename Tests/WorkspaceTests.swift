import Foundation

private struct WorkspaceTestFailure: Error, CustomStringConvertible {
    let description: String
}

@main @MainActor
struct WorkspaceTests {
    static func require(_ condition: @autoclosure () -> Bool, _ message: String) throws {
        if !condition() { throw WorkspaceTestFailure(description: message) }
    }

    static func waitUntilFinished(_ running: () -> Bool) async throws {
        let deadline = Date().addingTimeInterval(10)
        while running() {
            guard Date() < deadline else { throw WorkspaceTestFailure(description: "Workspace operation timed out") }
            try await Task.sleep(for: .milliseconds(20))
        }
    }

    static func main() async {
        do {
            let root = URL(fileURLWithPath: CommandLine.arguments.dropFirst().first ?? FileManager.default.currentDirectoryPath)
            let engine = AstrologEngine(executableURL: root.appendingPathComponent("Engine/bin/astrolog"),
                                       resourceURL: root.appendingPathComponent("Upstream/Astrolog"))
            let previousLanguage = UserDefaults.standard.object(forKey: "appLanguage")
            let previousPreferences = UserDefaults.standard.object(forKey: "chartPreferences")
            UserDefaults.standard.set("ru", forKey: "appLanguage")
            UserDefaults.standard.removeObject(forKey: "chartPreferences")
            defer {
                UserDefaults.standard.set(previousLanguage, forKey: "appLanguage")
                UserDefaults.standard.set(previousPreferences, forKey: "chartPreferences")
            }
            let model = WorkspaceModel(engine: engine)
            model.errorMessage = nil // Bundled books are optional in this headless harness.
            var checks: [String] = []

            let savedSecondary = SavedChart(title: "Вторая карта из файла", place: "Катманду",
                                            input: ChartInput(utcOffset: 5.75, longitude: 85.324, latitude: 27.7172))
            let restoredSecondary = try JSONDecoder().decode(SavedChart.self, from: JSONEncoder().encode(savedSecondary))
            let originalPrimary = model.input
            try model.applyChart(restoredSecondary, secondary: true)
            try require(model.secondaryPlace == savedSecondary.place && model.secondaryTitle == savedSecondary.title
                        && model.secondaryInput == savedSecondary.input && model.input == originalPrimary,
                        "Opening a second chart must retain its place and input without changing the first chart")
            try require(model.secondaryDateSummary.contains("UTC+05:45"),
                        "Second chart must show its own fractional UTC offset")
            model.secondaryInput.utcOffset = -3.5
            try require(model.secondaryDateSummary.contains("UTC−03:30"),
                        "Negative fractional UTC offsets must retain both sign and minutes")
            checks.append("Second-chart file import preserves place, title, coordinates and visible UTC offset")

            var invalid = savedSecondary
            invalid.input.day = 32
            do {
                try model.applyChart(invalid)
                throw WorkspaceTestFailure(description: "Invalid imported date was accepted")
            } catch is WorkspaceTestFailure { throw WorkspaceTestFailure(description: "Invalid imported date was accepted") }
            catch { }
            try require(model.input == originalPrimary && model.place == "Москва",
                        "Invalid imported charts must leave existing inputs unchanged")
            invalid = savedSecondary
            invalid.format = "AstraGlass.chart.v999"
            do {
                try model.applyChart(invalid, secondary: true)
                throw WorkspaceTestFailure(description: "Unknown file format was accepted")
            } catch is WorkspaceTestFailure { throw WorkspaceTestFailure(description: "Unknown file format was accepted") }
            catch { }
            try require(model.secondaryInput.utcOffset == -3.5,
                        "Unknown file formats must not overwrite the second chart")
            checks.append("Invalid dates and unsupported chart versions are rejected before modifying workspace data")

            model.secondaryInput.utcOffset = 5.75
            model.runMonthlyTransits()
            try await waitUntilFinished { model.reportIsRunning }
            try require(model.report.contains("Transits during Jan 2000 (ST Zone 5:45E)"),
                        "Monthly transit events must use the second chart's explicit UTC offset")
            try require(model.report.contains("12:00pm (ST Zone 3E)"),
                        "Setting the transit offset must not alter the natal time or offset")
            checks.append("Monthly transits use the secondary UTC offset and preserve natal chart time")

            model.calculate()
            try await waitUntilFinished { model.isCalculating }
            try require(model.snapshot != nil, "Initial chart must finish")
            model.runReport()
            try await waitUntilFinished { model.reportIsRunning }
            try require(!model.report.isEmpty, "Initial report must finish")
            model.renderGraphic()
            try await waitUntilFinished { model.graphicIsRunning }
            try require(model.graphicData != nil, "Initial graphic must finish")

            let renderedName = model.graphicExportName
            model.selectedGraphic = .composite
            try require(model.graphicExportName == renderedName && renderedName == GraphicPreset.natal.title,
                        "Changing the picker must not relabel the existing graphic export")
            checks.append("Graphic export name belongs to rendered preset, not current picker selection")

            model.input.year += 1
            try require(model.snapshot == nil && model.report.isEmpty && model.graphicData == nil && model.graphicImage == nil,
                        "Changed primary input must clear every previous result")
            try require(model.graphicCaption.isEmpty && model.graphicExportName.isEmpty,
                        "Changed primary input must clear graphic provenance")
            checks.append("Primary input changes invalidate chart, report, graphic, and export metadata")

            model.calculate()
            model.runComparison(transit: false)
            model.renderGraphic()
            model.input.year += 1
            try await Task.sleep(for: .milliseconds(250))
            try require(model.snapshot == nil && model.report.isEmpty && model.graphicData == nil,
                        "Canceled jobs must not republish old primary results")
            try require(!model.isCalculating && !model.reportIsRunning && !model.graphicIsRunning,
                        "Invalidated jobs must clear busy states")
            checks.append("Pending primary calculations cannot republish after input changes")

            model.calculate()
            try await waitUntilFinished { model.isCalculating }
            let primaryDay = model.snapshot?.julianDay
            model.runComparison(transit: false)
            model.renderGraphic()
            model.secondaryInput.year += 1
            try await Task.sleep(for: .milliseconds(250))
            try require(model.snapshot?.julianDay == primaryDay && primaryDay != nil,
                        "Secondary input must preserve the independent natal result")
            try require(model.report.isEmpty && model.graphicData == nil && !model.reportIsRunning && !model.graphicIsRunning,
                        "Secondary input must invalidate pending derived outputs")
            checks.append("Secondary changes cancel dependent results while preserving the natal chart")

            model.runReport()
            try await waitUntilFinished { model.reportIsRunning }
            try require(!model.report.isEmpty, "Replacement test needs a prior report")
            model.runReport(options: ["-i", "not-allowed"], name: "Rejected replacement")
            try require(model.report.isEmpty, "Starting replacement must immediately clear the previous report")
            try await waitUntilFinished { model.reportIsRunning }
            try require(model.report.isEmpty && model.errorMessage != nil,
                        "Failed replacement cannot leave prior content under its new title")
            checks.append("Failed replacement reports never expose previous content under a new title")

            model.errorMessage = nil
            model.renderGraphic()
            model.title = "Updated primary title"
            try await Task.sleep(for: .milliseconds(250))
            try require(model.graphicData == nil && model.graphicCaption.isEmpty,
                        "An in-flight graphic cannot acquire a changed primary title")
            model.renderGraphic()
            try await waitUntilFinished { model.graphicIsRunning }
            try require(model.graphicCaption.contains(model.title) && model.graphicCaption.contains(model.secondaryTitle),
                        "Comparison graphic caption must use both captured chart titles")
            model.secondaryTitle = "Updated secondary title"
            try require(model.graphicData == nil && model.graphicCaption.isEmpty,
                        "Changing the secondary title must invalidate prior comparison output")
            checks.append("Graphic captions capture both titles and are invalidated when either changes")

            model.preferences = ChartPreferences(enabledObjects: [1, 2], enabledAspects: [])
            try require(model.snapshot == nil && model.report.isEmpty && model.graphicData == nil,
                        "Preference changes must invalidate all prior results")
            try await waitUntilFinished { model.isCalculating }
            try require(Set(model.displaySnapshot?.positions.map(\.id) ?? []) == [1, 2]
                        && model.displaySnapshot?.aspects.isEmpty == true,
                        "Recalculation and export snapshot must honor selected objects and disabled aspects")
            let restoredPreferences = try JSONDecoder().decode(ChartPreferences.self,
                from: UserDefaults.standard.data(forKey: "chartPreferences")!)
            try require(restoredPreferences == model.preferences, "Preferences must survive relaunch")
            checks.append("Settings invalidate stale results, filter the actual engine snapshot and persist")

            let originalPack = model.interpretationPack
            let originalLibraryCount = model.library?.records.count
            model.errorMessage = nil
            if let unavailable = InterpretationPack.allCases.first(where: { $0.url == nil }) {
                try require(!InterpretationPack.available.contains(unavailable), "Missing collection must not be selectable")
                model.selectInterpretationPack(unavailable)
                try require(model.errorMessage == nil && model.interpretationPack == originalPack
                            && model.library?.records.count == originalLibraryCount,
                            "A stale selection must preserve the current collection without an alert")
            }
            checks.append("Unavailable interpretation collections are absent from the picker and stale selections are harmless")

            let dbFolder = FileManager.default.temporaryDirectory.appendingPathComponent("AstraGlass-workspace-db-" + UUID().uuidString)
            defer { try? FileManager.default.removeItem(at: dbFolder) }
            let dbURL = dbFolder.appendingPathComponent("charts.json")
            let dbModel = WorkspaceModel(engine: engine, databaseURL: dbURL)
            dbModel.creatingChart = true
            try dbModel.commitEditorChart(savedSecondary, secondary: false)
            try require(dbModel.savedCharts.count == 1 && dbModel.currentChartID != nil, "Apply automatically saves a new chart")
            let dbID = dbModel.currentChartID
            dbModel.creatingChart = false
            var edited = savedSecondary; edited.title = "Изменённая сохранённая карта"
            try dbModel.commitEditorChart(edited, secondary: false)
            try require(dbModel.savedCharts.count == 1 && dbModel.currentChartID == dbID, "Edit updates one database record")
            let reopenedModel = WorkspaceModel(engine: engine, databaseURL: dbURL)
            try require(reopenedModel.savedCharts.count == 1, "Database list survives a new workspace")
            reopenedModel.openStoredChart(reopenedModel.savedCharts[0])
            try await waitUntilFinished { reopenedModel.isCalculating }
            try require(reopenedModel.title == edited.title && reopenedModel.input == edited.input && reopenedModel.snapshot != nil, "Reopen restores and calculates persisted input")
            reopenedModel.openStoredChart(reopenedModel.savedCharts[0], secondary: true)
            try require(reopenedModel.secondaryInput == edited.input, "Saved chart can be opened as the second chart")
            checks.append("JSON database autosave, update without duplicates, relaunch, recalculation and second-chart reopen")

            let result: [String: Any] = ["passed": checks.count, "failed": 0, "checks": checks,
                                         "timestamp": ISO8601DateFormatter().string(from: Date())]
            let data = try JSONSerialization.data(withJSONObject: result, options: [.prettyPrinted, .sortedKeys])
            FileHandle.standardOutput.write(data)
            FileHandle.standardOutput.write(Data("\n".utf8))
        } catch {
            FileHandle.standardError.write(Data("FAIL: \(error)\n".utf8))
            exit(1)
        }
    }
}
