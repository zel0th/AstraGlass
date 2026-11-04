import Foundation
import SwiftUI
import AppKit
import UniformTypeIdentifiers

@MainActor
final class WorkspaceModel: ObservableObject {
    @Published var title = L10n.text("Пример · 1 января 2000") {
        didSet { if title != oldValue { invalidateDerivedResults() } }
    }
    @Published var place = L10n.text("Москва") {
        didSet { if place != oldValue { invalidateDerivedResults() } }
    }
    @Published var input = ChartInput() {
        didSet { if input != oldValue { invalidateChart(); invalidateDerivedResults() } }
    }
    @Published var secondaryInput = ChartInput(year: 2000, month: 6, day: 1) {
        didSet { if secondaryInput != oldValue { invalidateDerivedResults() } }
    }
    @Published var secondaryTitle = L10n.text("Вторая карта") {
        didSet { if secondaryTitle != oldValue { invalidateDerivedResults() } }
    }
    @Published var secondaryPlace = L10n.text("Москва") {
        didSet { if secondaryPlace != oldValue { invalidateDerivedResults() } }
    }
    @Published var snapshot: ChartSnapshot?
    @Published var selectedPlanet = 1
    @Published var selectedAspect: ChartAspect?
    @Published var selectedSign: Int?
    @Published var selectedHouse: Int?
    @Published var selectedRecord: InterpretationRecord?
    @Published var section: AppSection? = .chart
    @Published var library: InterpretationLibrary?
    @Published private(set) var interpretationPack: InterpretationPack = .podvodny
    @Published private(set) var savedCharts: [StoredChart] = []
    private(set) var currentChartID: UUID?
    private var secondaryChartID: UUID?
    private let chartDatabase: ChartDatabase
    @Published var isCalculating = false
    @Published var errorMessage: String?
    @Published var databaseNotice: String?
    @Published var comparison: ComparisonSnapshot?
    @Published var comparisonPlanet: Int?
    @Published var comparisonSecondarySelected = false
    @Published var comparisonAspect: ChartAspect?
    @Published var report = ""
    @Published var reportTitle = L10n.text("Положения планет")
    @Published var reportIsRunning = false
    @Published var showEditor = false
    @Published var editingSecondary = false
    @Published var creatingChart = false
    @Published var showInspector = true
    @Published var lastCalculation: Double = 0
    @Published var selectedReport = ReportPreset.positions
    @Published var expertOptions = "-v -g -a"
    @Published var librarySearch = ""
    @Published var libraryCategory = "Все"
    @Published var selectedGraphic = GraphicPreset.natal
    @Published var graphicImage: NSImage?
    @Published var graphicData: Data?
    @Published var graphicIsRunning = false
    @Published var graphicCaption = ""
    private(set) var graphicExportName = ""
    @Published var preferences: ChartPreferences = WorkspaceModel.loadPreferences() {
        didSet {
            guard preferences != oldValue else { return }
            if let data = try? JSONEncoder().encode(preferences) { UserDefaults.standard.set(data, forKey: "chartPreferences") }
            invalidateDerivedResults()
            calculate()
        }
    }
    private static func loadPreferences() -> ChartPreferences {
        guard let data = UserDefaults.standard.data(forKey: "chartPreferences"),
              let value = try? JSONDecoder().decode(ChartPreferences.self, from: data) else { return .defaults }
        return value.normalized
    }
    let engine: AstrologEngine
    private var calculationTask: Task<Void, Never>?
    private var reportTask: Task<Void, Never>?
    private var graphicTask: Task<Void, Never>?

    init(engine: AstrologEngine = AstrologEngine(), databaseURL: URL = ChartDatabase.defaultURL) {
        self.engine = engine
        self.chartDatabase = ChartDatabase(url: databaseURL)
        let preferred = InterpretationPack(rawValue: UserDefaults.standard.string(forKey: "interpretationPack") ?? "podvodny") ?? .podvodny
        interpretationPack = InterpretationPack.available.contains(preferred) ? preferred : (InterpretationPack.available.first ?? .podvodny)
        do { library = try InterpretationLibrary.load(interpretationPack) }
        catch InterpretationError.missingCorpus {
            // The public distribution intentionally starts without private books.
            // The inspector and settings already explain how to import them.
            library = nil
        }
        catch { errorMessage = L10n.text("Не удалось открыть тексты: ", "Unable to open texts: ") + error.localizedDescription }
        reloadCharts()
        AppProfiler.startIfRequested()
    }

    var displaySnapshot: ChartSnapshot? {
        guard let snapshot else { return nil }
        return ChartSnapshot(engine: snapshot.engine, julianDay: snapshot.julianDay,
            positions: snapshot.positions.filter { preferences.enabledObjects.contains($0.id) },
            houseCusps: snapshot.houseCusps,
            aspects: snapshot.aspects.filter { preferences.enabledAspects.contains($0.kind) && preferences.enabledObjects.contains($0.first) && preferences.enabledObjects.contains($0.second) },
            unavailableObjects: snapshot.unavailableObjects.filter { preferences.enabledObjects.contains($0) }, rawReport: snapshot.rawReport)
    }
    var unavailableObjectNames: [String] { displaySnapshot?.unavailableObjects.map { AstroStyle.name($0) } ?? [] }
    var selectedPosition: PlanetPosition? { snapshot?.positions.first { $0.id == selectedPlanet } }
    var mainPlanets: [PlanetPosition] { snapshot?.positions.filter { (1...10).contains($0.id) } ?? [] }
    var comparisonIsVisible: Bool {
        (section == .relationships && comparison?.transit == false) || (section == .transits && comparison?.transit == true)
    }
    var comparisonPosition: PlanetPosition? {
        guard comparisonIsVisible, let id = comparisonPlanet else { return nil }
        return (comparisonSecondarySelected ? comparison?.secondary : comparison?.primary)?.positions.first { $0.id == id }
    }
    func selectComparisonPlanet(_ id: Int, secondary: Bool) {
        comparisonPlanet = id; comparisonSecondarySelected = secondary; comparisonAspect = nil
        selectedSign = nil; selectedHouse = nil; showInspector = true
    }
    func selectComparisonAspect(_ aspect: ChartAspect) {
        comparisonAspect = aspect; comparisonPlanet = nil; selectedSign = nil; selectedHouse = nil; showInspector = true
    }
    func selectComparisonHouse(_ house: Int) {
        selectedHouse = house; selectedSign = nil; comparisonPlanet = nil; comparisonAspect = nil; showInspector = true
    }
    func selectComparisonSign(_ sign: Int) {
        selectedSign = sign; selectedHouse = nil; comparisonPlanet = nil; comparisonAspect = nil; showInspector = true
    }
    var inspectorCusps: [Double]? { comparisonIsVisible ? comparison?.primary.houseCusps : snapshot?.houseCusps }
    var relevantPassages: [InterpretationRecord] {
        guard let library else { return [] }
        if let selectedRecord, section == .library { return [selectedRecord] }
        if let selectedSign { return library.forSign(index: selectedSign) }
        if let house = selectedHouse, let cusps = inspectorCusps, cusps.indices.contains(house - 1) { return library.forHouse(number: house, sign: AstroStyle.sign(cusps[house - 1])) }
        if comparisonIsVisible {
            if let aspect = comparisonAspect { return library.forAspect(first: aspect.first, second: aspect.second, angle: aspect.angle) }
            if let planet = comparisonPosition { return library.forPlanet(id: planet.id, sign: planet.sign, house: planet.house) }
            return []
        }
        if let selectedAspect { return library.forAspect(first: selectedAspect.first, second: selectedAspect.second, angle: selectedAspect.angle) }
        guard let p = selectedPosition else { return [] }
        return library.forPlanet(id: p.id, sign: p.sign, house: p.house)
    }
    var dateSummary: String { Self.dateSummary(for: input) }
    var secondaryDateSummary: String { Self.dateSummary(for: secondaryInput) }
    private static func dateSummary(for input: ChartInput) -> String {
        let offsetMinutes = Int((abs(input.utcOffset) * 60).rounded())
        let zone = String(format: "UTC%@%02d:%02d", input.utcOffset < 0 ? "−" : "+", offsetMinutes / 60, offsetMinutes % 60)
        return String(format: "%02d.%02d.%04d · %02d:%02d · %@", input.day, input.month, input.year, input.hour, input.minute, zone)
    }
    var calculationSummary: String {
        (input.sidereal ? L10n.text("Сидерический зодиак", "Sidereal zodiac") : L10n.text("Тропический зодиак", "Tropical zodiac")) + " · " + houseSystemName(input.houseSystem)
    }
    var libraryResults: [InterpretationRecord] {
        library?.search(librarySearch, category: libraryCategory == "Все" ? nil : libraryCategory, limit: 200) ?? []
    }

    func calculate() {
        invalidateChart()
        let chart = input
        isCalculating = true
        calculationTask = Task {
            let start = Date()
            do {
                let result = try await engine.calculate(chart, preferences: preferences)
                guard !Task.isCancelled else { return }
                snapshot = result
                lastCalculation = Date().timeIntervalSince(start)
                selectedAspect = nil
                isCalculating = false
            } catch is CancellationError { }
            catch { if !Task.isCancelled { isCalculating = false; errorMessage = error.localizedDescription } }
        }
    }

    // Any changed input invalidates both completed and in-flight dependent work.
    // Canceled tasks also check their cancellation state before publishing results.
    private func invalidateChart() {
        calculationTask?.cancel()
        calculationTask = nil
        snapshot = nil
        isCalculating = false
        lastCalculation = 0
        selectedAspect = nil
        selectedHouse = nil
        selectedSign = nil
    }

    private func invalidateReport() {
        reportTask?.cancel()
        reportTask = nil
        reportIsRunning = false
        report = ""
        comparison = nil
        comparisonPlanet = nil
        comparisonAspect = nil
        selectedSign = nil; selectedHouse = nil
    }

    private func invalidateGraphic() {
        graphicTask?.cancel()
        graphicTask = nil
        graphicIsRunning = false
        graphicData = nil
        graphicImage = nil
        graphicCaption = ""
        graphicExportName = ""
    }

    private func invalidateDerivedResults() {
        invalidateReport()
        invalidateGraphic()
    }

    func selectSign(_ index: Int) { selectedSign = index; selectedAspect = nil; selectedHouse = nil; selectedRecord = nil; showInspector = true }
    func selectPlanet(_ id: Int) { selectedSign = nil; showInspector = true; selectedPlanet = id; selectedAspect = nil; selectedHouse = nil; selectedRecord = nil }
    func selectAspect(_ value: ChartAspect) { selectedSign = nil; selectedAspect = value; selectedHouse = nil; selectedRecord = nil; showInspector = true }
    func selectHouse(_ number: Int) { selectedSign = nil; selectedHouse = number; selectedAspect = nil; selectedRecord = nil; showInspector = true }

    func edit(secondary: Bool = false) { creatingChart = false; editingSecondary = secondary; showEditor = true }

    func newChart() {
        creatingChart = true
        editingSecondary = false
        showEditor = true
    }

    func reloadCharts() {
        do { savedCharts = try chartDatabase.load() }
        catch { errorMessage = L10n.text("Не удалось прочитать базу карт: ", "Unable to read chart database: ") + error.localizedDescription }
    }

    func save() {
        do {
            let item = try chartDatabase.save(SavedChart(title: title, place: place, input: input), id: currentChartID)
            currentChartID = item.id
            reloadCharts()
            section = .savedCharts
        } catch { errorMessage = error.localizedDescription }
    }

    func commitEditorChart(_ chart: SavedChart, secondary: Bool, loadedChartID: UUID? = nil) throws {
        // Loading in the editor is a draft operation. Apply updates that record,
        // never the unrelated chart that happened to be open before the editor.
        let id = loadedChartID ?? (secondary ? secondaryChartID : (creatingChart ? nil : currentChartID))
        let item = try chartDatabase.save(chart, id: id)
        try applyChart(chart, secondary: secondary)
        if secondary { secondaryChartID = item.id } else { currentChartID = item.id; section = .chart }
        reloadCharts()
    }

    func openStoredChart(_ item: StoredChart, secondary: Bool = false) {
        do {
            try applyChart(item.chart, secondary: secondary)
            if secondary { secondaryChartID = item.id; section = .relationships }
            else { currentChartID = item.id; section = .chart }
        } catch { errorMessage = error.localizedDescription }
    }

    func removeStoredChart(_ item: StoredChart) {
        do {
            try chartDatabase.remove(id: item.id)
            if currentChartID == item.id { currentChartID = nil }
            if secondaryChartID == item.id { secondaryChartID = nil }
            reloadCharts()
        } catch { errorMessage = error.localizedDescription }
    }

    func revealChartDatabase() { NSWorkspace.shared.activateFileViewerSelecting([chartDatabase.url]) }

    func importChartDatabase() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.json]; panel.allowsMultipleSelection = false
        panel.title = L10n.text("Импортировать базу карт", "Import chart database")
        panel.message = L10n.text("Карты будут объединены с текущей базой. Для совпадающих карт сохраняется более свежая запись.", "Charts will be merged with the current database. The newer revision of each matching chart is kept.")
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do { try importChartDatabase(from: url) }
        catch { errorMessage = L10n.text("Не удалось импортировать базу карт: ", "Unable to import chart database: ") + error.localizedDescription }
    }

    func importChartDatabase(from url: URL) throws {
        let result = try chartDatabase.importFile(at: url)
        reloadCharts(); section = .savedCharts
        databaseNotice = L10n.text("Добавлено: \(result.added). Обновлено: \(result.updated). Без изменений: \(result.unchanged).", "Added: \(result.added). Updated: \(result.updated). Unchanged: \(result.unchanged).")
    }

    func exportChartDatabase() {
        let panel = NSSavePanel(); panel.allowedContentTypes = [.json]
        panel.title = L10n.text("Экспортировать базу карт", "Export chart database")
        panel.nameFieldStringValue = "AstraGlass-charts.json"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            try exportChartDatabase(to: url)
            databaseNotice = L10n.text("База карт экспортирована.", "Chart database exported.")
        } catch { errorMessage = L10n.text("Не удалось экспортировать базу карт: ", "Unable to export chart database: ") + error.localizedDescription }
    }

    func exportChartDatabase(to url: URL) throws { try chartDatabase.export(to: url) }

    func selectInterpretationPack(_ pack: InterpretationPack) {
        guard InterpretationPack.available.contains(pack) else { return }
        do {
            let loaded = try InterpretationLibrary.load(pack)
            library = loaded; interpretationPack = pack
            UserDefaults.standard.set(pack.rawValue, forKey: "interpretationPack")
            selectedRecord = nil; libraryCategory = "Все"; librarySearch = ""
        } catch { errorMessage = error.localizedDescription }
    }

    func exportChart() {
        let chart = SavedChart(title: title, place: place, input: input)
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.json]
        panel.nameFieldStringValue = chart.title + ".astraglass.json"
        panel.title = L10n.text("Сохранить карту")
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            try encoder.encode(chart).write(to: url, options: .atomic)
        } catch { errorMessage = error.localizedDescription }
    }

    func open(secondary: Bool = false) {
        let panel = NSOpenPanel(); panel.allowedContentTypes = [.json]; panel.allowsMultipleSelection = false
        panel.title = secondary ? L10n.text("Открыть вторую карту") : L10n.text("Открыть карту")
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            let chart = try JSONDecoder().decode(SavedChart.self, from: Data(contentsOf: url))
            let item = try chartDatabase.save(chart)
            reloadCharts()
            openStoredChart(item, secondary: secondary)
        } catch { errorMessage = L10n.text("Не удалось открыть карту: ", "Unable to open chart: ") + error.localizedDescription }
    }

    func applyChart(_ chart: SavedChart, secondary: Bool = false) throws {
        guard chart.format == "AstraGlass.chart.v1" else { throw CocoaError(.fileReadCorruptFile) }
        try chart.input.validate()
        if secondary {
            secondaryInput = chart.input
            secondaryTitle = chart.title
            secondaryPlace = chart.place
        } else {
            title = chart.title
            place = chart.place
            input = chart.input
            calculate()
        }
    }

    func importLibrary() {
        let panel = NSOpenPanel(); panel.allowedContentTypes = [.json]; panel.title = L10n.text("Импортировать тексты трактовок")
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            let imported = try InterpretationLibrary.importFile(url)
            library = imported; selectedRecord = nil
            interpretationPack = .custom
            UserDefaults.standard.set(InterpretationPack.custom.rawValue, forKey: "interpretationPack")
            libraryCategory = "Все"
            librarySearch = ""
            section = .library
        } catch { errorMessage = L10n.text("Не удалось открыть тексты: ", "Unable to open texts: ") + error.localizedDescription }
    }

    func exportReport() {
        guard !report.isEmpty else { return }
        let contents = report, name = reportTitle
        let panel = NSSavePanel(); panel.allowedContentTypes = [.plainText]; panel.nameFieldStringValue = name + ".txt"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do { try contents.write(to: url, atomically: true, encoding: .utf8) }
        catch { errorMessage = error.localizedDescription }
    }

    func runReport(options: [String]? = nil, name: String? = nil) {
        invalidateReport()
        let chart = input
        let arguments = options ?? selectedReport.options(input: chart)
        reportTitle = name ?? L10n.text(selectedReport.rawValue)
        reportIsRunning = true
        reportTask = Task {
            do {
                let result = try await engine.report(chart, options: arguments, preferences: preferences)
                guard !Task.isCancelled else { return }
                report = result
                reportIsRunning = false
            } catch is CancellationError { }
            catch { if !Task.isCancelled { reportIsRunning = false; errorMessage = error.localizedDescription } }
        }
    }

    func runExpert() {
        do { runReport(options: try tokenizeArguments(expertOptions), name: L10n.text("Пользовательский отчёт")) }
        catch { errorMessage = error.localizedDescription }
    }
    func cancelReport() { reportTask?.cancel(); reportIsRunning = false }

    func runComparison(transit: Bool) {
        invalidateReport()
        let primary = input, other = secondaryInput, options = preferences
        reportTitle = transit ? L10n.text("Транзиты к натальной карте") : L10n.text("Синастрия")
        reportIsRunning = true
        reportTask = Task {
            do {
                let result = try await engine.comparison(primary, secondary: other, transit: transit, preferences: options)
                guard !Task.isCancelled else { return }
                comparison = result; reportIsRunning = false
            } catch is CancellationError { }
            catch { if !Task.isCancelled { reportIsRunning = false; errorMessage = error.localizedDescription } }
        }
    }

    func runMonthlyTransits() {
        do {
            try secondaryInput.validate()
            var transit = Array(secondaryInput.arguments.prefix(9))
            transit[0] = "-qbt"
            // -t resets the transit zone and location to Astrolog's defaults.
            // Set the transit slot afterwards, preserving the natal chart.
            runReport(options: ["-t", String(secondaryInput.month), String(secondaryInput.year)] + transit,
                      name: L10n.text("Транзиты на месяц"))
        } catch { errorMessage = error.localizedDescription }
    }

    func renderGraphic() {
        invalidateGraphic()
        let chart = input, other = secondaryInput, kind = selectedGraphic
        let chartTitle = title, otherTitle = secondaryTitle
        let caption = kind.title + " · " + chartTitle + (kind.needsSecondary ? " · " + otherTitle : "")
        graphicIsRunning = true
        graphicTask = Task {
            do {
                let data = try await engine.renderGraphic(chart, kind: kind, secondary: other, preferences: preferences)
                guard !Task.isCancelled else { return }
                guard let image = NSImage(data: data) else { throw AstrologError.invalidOutput }
                graphicData = data; graphicImage = image
                graphicCaption = caption
                graphicExportName = kind.title
                graphicIsRunning = false
            } catch is CancellationError { }
            catch { if !Task.isCancelled { graphicIsRunning = false; errorMessage = error.localizedDescription } }
        }
    }
    func cancelGraphic() { graphicTask?.cancel(); graphicIsRunning = false }

    func exportGraphic() {
        guard let data = graphicData else { return }
        let panel = NSSavePanel(); panel.allowedContentTypes = [.png, .bmp]
        panel.nameFieldStringValue = graphicExportName + ".png"
        panel.title = L10n.text("Сохранить график")
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            if url.pathExtension.lowercased() == "bmp" { try data.write(to: url, options: .atomic) }
            else {
                guard let bitmap = NSBitmapImageRep(data: data), let png = bitmap.representation(using: .png, properties: [:]) else { throw AstrologError.invalidOutput }
                try png.write(to: url, options: .atomic)
            }
        } catch { errorMessage = error.localizedDescription }
    }

    func exportNativeChart(pdf: Bool) {
        guard let snapshot = displaySnapshot else { return }
        let chartTitle = title
        let content = ChartExportPage(snapshot: snapshot, title: chartTitle, subtitle: place + " · " + dateSummary, system: calculationSummary)
        let panel = NSSavePanel(); panel.allowedContentTypes = pdf ? [.pdf] : [.png]
        panel.nameFieldStringValue = chartTitle + (pdf ? ".pdf" : ".png")
        panel.title = L10n.text("Сохранить карту")
        guard panel.runModal() == .OK, let url = panel.url else { return }
        let renderer = ImageRenderer(content: content)
        renderer.scale = 2
        do {
            if pdf {
                try ChartPDFExporter.export(url: url, snapshot: snapshot, title: chartTitle,
                    subtitle: place + " · " + dateSummary, system: calculationSummary,
                    passages: exportPassages(for: snapshot))
            } else {
                guard let image = renderer.cgImage, let png = NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:]) else { throw CocoaError(.fileWriteUnknown) }
                try png.write(to: url, options: .atomic)
            }
        } catch { errorMessage = error.localizedDescription }
    }

    private func exportPassages(for chart: ChartSnapshot) -> [InterpretationRecord] {
        guard let library else { return [] }
        var records: [InterpretationRecord] = []
        for sign in Set(chart.positions.map(\.sign)).sorted() { records += library.forSign(index: sign) }
        for planet in chart.positions { records += library.forPlanet(id: planet.id, sign: planet.sign, house: planet.house) }
        for (index, cusp) in chart.houseCusps.enumerated() { records += library.forHouse(number: index + 1, sign: AstroStyle.sign(cusp)) }
        for aspect in chart.aspects { records += library.forAspect(first: aspect.first, second: aspect.second, angle: aspect.angle) }
        var seen = Set<String>()
        return records.filter { seen.insert($0.id).inserted }
    }

    func openManual() {
        guard let url = Bundle.main.url(forResource: "Astrolog-Manual", withExtension: "htm") else { errorMessage = L10n.text("Справочник отсутствует в сборке приложения."); return }
        NSWorkspace.shared.open(url)
    }
}

enum ReportPreset: String, CaseIterable, Identifiable {
    case positions = "Положения планет", aspects = "Аспекты", midpoints = "Мидпойнты", influence = "Влияния", ephemeris = "Эфемериды на месяц", calendar = "Календарь", arabic = "Арабские части", stars = "Неподвижные звёзды", astrograph = "Астрокартография", help = "Справочник параметров"
    var id: String { rawValue }
    func options(input: ChartInput) -> [String] {
        switch self { case .positions: return ["-v"]; case .aspects: return ["-a", "-g"]; case .midpoints: return ["-m"]; case .influence: return ["-j"]; case .ephemeris: return ["-E"]; case .calendar: return ["-K"]; case .arabic: return ["-P"]; case .stars: return ["-U", "-v"]; case .astrograph: return ["-L"]; case .help: return ["-H"] }
    }
}

func houseSystemName(_ id: Int) -> String {
    let names = [L10n.text("Плацидус"), L10n.text("Кох"), L10n.text("Равнодомная"), L10n.text("Кампано"), L10n.text("Меридианная"), L10n.text("Региомонтан"), L10n.text("Порфирий"), L10n.text("Морин"), L10n.text("Топоцентрическая"), L10n.text("Алькабициус"), L10n.text("Крусинский"), L10n.text("Равнодомная (MC)"), L10n.text("Пуллен (S.Ratio)"), L10n.text("Пуллен (S.Delta)"), L10n.text("Целые знаки"), L10n.text("Ведическая"), L10n.text("Шрипати"), L10n.text("Горизонтальная"), "APC", L10n.text("Картер"), "Sunshine", L10n.text("Савар A"), L10n.text("Без домов"), L10n.text("Целые знаки (MC)"), L10n.text("Ведическая (MC)"), L10n.text("Равнодомная (сбаланс.)"), L10n.text("Целые знаки (сбаланс.)"), L10n.text("Ведическая (сбаланс.)"), L10n.text("Равнодомная (EP)"), L10n.text("Целые знаки (EP)"), L10n.text("Ведическая (EP)"), L10n.text("Равнодомная (Антивертекс)", "Equal (Antivertex)"), L10n.text("Целые знаки (Антивертекс)", "Whole signs (Antivertex)"), L10n.text("Ведическая (Антивертекс)", "Vedic (Antivertex)"), L10n.text("Порфирий (EP)"), L10n.text("Порфирий (Антивертекс)", "Porphyry (Antivertex)"), L10n.text("Пуллен (SR, EP)"), L10n.text("Пуллен (SR, Антивертекс)", "Pullen (SR, Antivertex)"), L10n.text("Пуллен (SD, EP)"), L10n.text("Пуллен (SD, Антивертекс)", "Pullen (SD, Antivertex)")]
    return names.indices.contains(id) ? names[id] : L10n.text("Система домов \(id)", "House system \(id)")
}

private func tokenizeArguments(_ text: String) throws -> [String] {
    var tokens: [String] = [], current = "", quote: Character?
    for c in text {
        if let q = quote { if c == q { quote = nil } else { current.append(c) } }
        else if c == "\"" || c == "'" { quote = c }
        else if c.isWhitespace { if !current.isEmpty { tokens.append(current); current = "" } }
        else { current.append(c) }
    }
    if quote != nil { throw CocoaError(.formatting) }
    if !current.isEmpty { tokens.append(current) }
    return tokens
}
