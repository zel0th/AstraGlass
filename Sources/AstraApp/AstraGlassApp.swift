import SwiftUI
import AppKit

#if !ASTRAGLASS_WORKSPACE_TESTS
@main
#endif
struct AstraGlassApp: App {
    @StateObject private var model = WorkspaceModel()
    @AppStorage("appearance") private var appearance = "system"
    @AppStorage("appLanguage") private var appLanguage = "system"
    var body: some Scene {
        WindowGroup {
            WorkspaceView(model: model)
                .tint(AstroStyle.accent)
                .environment(\.locale, L10n.locale)
                .id(appLanguage)
                .preferredColorScheme(appearance == "dark" ? .dark : appearance == "light" ? .light : nil)
        }
        .defaultSize(width: 1500, height: 900)
        .windowResizability(.contentMinSize)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button(L10n.text("Новая карта")) { model.newChart() }.keyboardShortcut("n")
                Button(L10n.text("Открыть карту…")) { model.open() }.keyboardShortcut("o")
                Button(L10n.text("Сохранить в базу", "Save to database")) { model.save() }.keyboardShortcut("s")
            }
            CommandMenu(L10n.text("Карта")) {
                Button(L10n.text("Мои карты", "My charts")) { model.reloadCharts(); model.section = .savedCharts }
                Button(L10n.text("Экспортировать карту в JSON…", "Export chart as JSON…")) { model.exportChart() }
                Button(L10n.text("Импортировать базу карт…", "Import chart database…")) { model.importChartDatabase() }
                Button(L10n.text("Экспортировать базу карт…", "Export chart database…")) { model.exportChartDatabase() }
                Divider()
                Button(L10n.text("Изменить данные…")) { model.edit() }.keyboardShortcut("e")
                Button(L10n.text("Пересчитать")) { model.calculate() }.keyboardShortcut("r")
                Divider()
                Button(L10n.text("Импортировать тексты…")) { model.importLibrary() }
                Button(L10n.text("Экспортировать отчёт…")) { model.exportReport() }.disabled(model.report.isEmpty)
                Button(L10n.text("Карта и трактовки в PDF…")) { model.exportNativeChart(pdf: true) }.disabled(model.snapshot == nil)
                Button(L10n.text("Сохранить карту в PNG…")) { model.exportNativeChart(pdf: false) }.disabled(model.snapshot == nil)
            }
            CommandGroup(after: .sidebar) {
                Button(model.showInspector ? L10n.text("Скрыть трактовки") : L10n.text("Показать трактовки")) { model.showInspector.toggle() }.keyboardShortcut("i", modifiers: [.command, .option])
            }
            CommandGroup(replacing: .help) { Button(L10n.text("Справочник Astrolog 8.0")) { model.openManual() } }
        }
        Settings { SettingsView(model: model).environment(\.locale, L10n.locale).id(appLanguage) }
            .windowResizability(.contentSize)
    }
}

struct WorkspaceView: View {
    @ObservedObject var model: WorkspaceModel
    @StoredState private var columnVisibility = NavigationSplitViewVisibility.all
    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            VStack(spacing: 0) {
                HStack(spacing: 10) {
                    Image(systemName: "sparkle").font(.system(size: 25, weight: .light)).foregroundStyle(AstroStyle.accent)
                    VStack(alignment: .leading, spacing: 2) { Text("AstraGlass").font(.system(size: 18, weight: .semibold, design: .rounded)); Text(L10n.text("АТЛАС КАРТЫ")).font(.system(size: 8, weight: .medium)).tracking(2).foregroundStyle(.secondary) }
                    Spacer()
                }.padding(.horizontal, 20).padding(.top, 21).padding(.bottom, 23)
                List(selection: $model.section) {
                    Section(L10n.text("Исследование")) { ForEach([AppSection.savedCharts, .chart, .planets, .aspects]) { item in Label(L10n.text(item.rawValue), systemImage: item.symbol).tag(item) } }
                    Section(L10n.text("Динамика")) { ForEach([AppSection.relationships, .transits, .reports, .graphics]) { item in Label(L10n.text(item.rawValue), systemImage: item.symbol).tag(item) } }
                    Section(L10n.text("Тексты")) { Label(L10n.text(AppSection.library.rawValue), systemImage: AppSection.library.symbol).tag(AppSection.library) }
                }.listStyle(.sidebar)
                VStack(alignment: .leading, spacing: 7) {
                    Text(model.interpretationPack.title).font(.caption.weight(.medium))
                    Text(L10n.text("\(model.library?.records.count ?? 0) разделов · \(model.library?.sources.count ?? 0) источников", "\(model.library?.records.count ?? 0) sections · \(model.library?.sources.count ?? 0) sources")).font(.caption2).foregroundStyle(.tertiary)
                    Divider().padding(.vertical, 5)
                    HStack { Circle().fill(.green).frame(width: 5, height: 5); Text(L10n.text("Astrolog 8.0 · локально")).font(.system(size: 10)).foregroundStyle(.secondary) }
                }.padding(20).frame(maxWidth: .infinity, alignment: .leading)
            }.navigationSplitViewColumnWidth(min: 220, ideal: 280, max: 280)
        } detail: {
            ZStack(alignment: .topLeading) {
                switch model.section ?? .chart {
                case .savedCharts: SavedChartsView(model: model)
                case .chart: ChartDashboard(model: model)
                case .planets: PlanetTableView(model: model)
                case .aspects: AspectTableView(model: model)
                case .relationships: RelationshipView(model: model, transit: false)
                case .transits: RelationshipView(model: model, transit: true)
                case .reports: ReportsView(model: model)
                case .graphics: GraphicsView(model: model)
                case .library: LibraryView(model: model)
                }
            }
            .frame(minWidth: 500, minHeight: 600)
            .background(Color(nsColor: .windowBackgroundColor))
            .inspector(isPresented: $model.showInspector) {
                InterpretationInspector(model: model)
                    .inspectorColumnWidth(min: 360, ideal: 800, max: 1200)
            }
            .navigationTitle(model.title)
            .navigationSubtitle(model.place + " · " + model.dateSummary)
            .toolbar {
                ToolbarItemGroup(placement: .automatic) {
                    Button { model.edit() } label: { Label(L10n.text("Данные карты"), systemImage: "slider.horizontal.3") }.help(L10n.text("Изменить дату, время и место"))
                    Button { model.calculate() } label: { Label(L10n.text("Пересчитать"), systemImage: "arrow.clockwise") }.disabled(model.isCalculating)
                }
                ToolbarItemGroup(placement: .primaryAction) {
                    Button { model.save() } label: { Label(L10n.text("Сохранить"), systemImage: "square.and.arrow.down") }
                    Menu { Button(L10n.text("Карта и трактовки в PDF…")) { model.exportNativeChart(pdf: true) }; Button(L10n.text("Карта в PNG…")) { model.exportNativeChart(pdf: false) } } label: { Label(L10n.text("Экспорт карты"), systemImage: "square.and.arrow.up") }.disabled(model.snapshot == nil)
                    Button { model.showInspector.toggle() } label: { Label(L10n.text("Трактовки"), systemImage: "sidebar.right") }.help(L10n.text("Показать или скрыть трактовки"))
                }
            }
        }
        .sheet(isPresented: $model.showEditor) { ChartEditor(model: model, secondary: model.editingSecondary) }
        .alert("AstraGlass", isPresented: Binding(get: { model.errorMessage != nil }, set: { if !$0 { model.errorMessage = nil } })) { Button(L10n.text("Понятно")) { model.errorMessage = nil } } message: { Text(model.errorMessage ?? "") }
        .task { if model.snapshot == nil { model.calculate() } }
        .frame(minWidth: 1100, minHeight: 600)
    }
}

struct ChartDashboard: View {
    @ObservedObject var model: WorkspaceModel
    var body: some View {
        GeometryReader { viewport in
        ScrollView {
            ChartDashboardLayout(viewportHeight: max(0, viewport.size.height - 56)) {
                VStack(alignment: .leading, spacing: 20) {
                HStack(alignment: .top) {
                    SectionHeading(eyebrow: L10n.text("Натальная карта"), title: L10n.text("Геометрия неба"), subtitle: model.calculationSummary)
                    Spacer()
                    if model.isCalculating { ProgressView().controlSize(.small).padding(.top, 12) }
                    else { Button { model.section = .planets } label: { Image(systemName: "list.bullet").padding(4) }.buttonStyle(.glass).help(L10n.text("Таблица положений")) }
                }
                if model.currentChartID == nil && model.input == ChartInput() && (model.title.hasPrefix("Пример") || model.title.hasPrefix("Example")) { Text(L10n.text("Демонстрационная карта: 1 января 2000, 12:00, Москва. Измените данные для своей карты.")).font(.caption).foregroundStyle(.secondary) }
                }
                if let snapshot = model.displaySnapshot {
                    ChartWheel(snapshot: snapshot, selectedPlanet: model.selectedPlanet, select: model.selectPlanet, selectSign: model.selectSign, selectAspect: model.selectAspect, selectedAspect: model.selectedAspect, selectedSign: model.selectedSign)
                    VStack(alignment: .leading, spacing: 20) {
                    HStack(spacing: 0) {
                        chartMetric(L10n.text("СОЛНЦЕ"), value: signSummary(snapshot, planet: 1))
                        Divider().frame(height: 35)
                        chartMetric(L10n.text("ЛУНА"), value: signSummary(snapshot, planet: 2))
                        Divider().frame(height: 35)
                        chartMetric(L10n.text("АСЦЕНДЕНТ"), value: snapshot.houseCusps.first.map { AstroStyle.signNames[AstroStyle.sign($0)] } ?? "—")
                    }.padding(.vertical, 18).background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 16))
                    if !model.unavailableObjectNames.isEmpty {
                        Text(L10n.text("Недоступны без дополнительных эфемерид: ", "Additional ephemerides required: ") + model.unavailableObjectNames.joined(separator: ", ")).font(.caption).foregroundStyle(.secondary)
                    }
                    HStack { Text(L10n.text("Выберите планету, знак или линию аспекта для трактовки")); Spacer(); Text(String(format: L10n.text("Расчёт %.0f мс"), model.lastCalculation * 1000)) }.font(.caption2).foregroundStyle(.tertiary)
                    }
                } else {
                    EmptyPanel(title: model.isCalculating ? L10n.text("Рассчитываем карту") : L10n.text("Карта не рассчитана"), description: L10n.text("Укажите дату, местное время и координаты в данных карты."))
                    Color.clear.frame(height: 0)
                }
            }.padding(28)
        }
        }
    }
    private func chartMetric(_ label: String, value: String) -> some View { VStack(spacing: 7) { Text(label).font(.system(size: 9, weight: .medium)).tracking(1.3).foregroundStyle(.secondary); Text(value).font(.system(size: 17, weight: .medium, design: .rounded)) }.frame(maxWidth: .infinity) }
    private func signSummary(_ snapshot: ChartSnapshot, planet: Int) -> String { snapshot.positions.first { $0.id == planet }.map { AstroStyle.signNames[$0.sign] } ?? "—" }
}

