import SwiftUI

struct SettingsView: View {
    @ObservedObject var model: WorkspaceModel
    @AppStorage("appearance") private var appearance = "system"
    @AppStorage("appLanguage") private var appLanguage = "system"

    var body: some View {
        TabView {
            general.tabItem { Label(L10n.text("Основные", "General"), systemImage: "gearshape") }
            objects.tabItem { Label(L10n.text("Планеты и точки", "Planets & points"), systemImage: "sparkles") }
            aspects.tabItem { Label(L10n.text("Аспекты", "Aspects"), systemImage: "point.3.connected.trianglepath.dotted") }
        }
        .padding(20)
        .frame(width: 760, height: 560)
    }

    private var general: some View {
        VStack(alignment: .leading, spacing: 24) {
            Grid(alignment: .leading, horizontalSpacing: 28, verticalSpacing: 20) {
                GridRow {
                    Text(L10n.text("Язык", "Language"))
                    Picker("", selection: $appLanguage) {
                        Text(L10n.text("Автоматически", "Automatic")).tag("system")
                        Text("Русский").tag("ru")
                        Text("English").tag("en")
                    }.labelsHidden().frame(width: 280)
                }
                GridRow {
                    Text(L10n.text("Оформление", "Appearance"))
                    Picker("", selection: $appearance) {
                        Text(L10n.text("Как в macOS", "System")).tag("system")
                        Text(L10n.text("Светлое", "Light")).tag("light")
                        Text(L10n.text("Тёмное", "Dark")).tag("dark")
                    }.labelsHidden().frame(width: 280)
                }
            }
            Divider()
            VStack(alignment: .leading, spacing: 12) {
                Text(L10n.text("Библиотека трактовок", "Interpretation library")).font(.headline)
                Button(L10n.text("Импортировать библиотеку JSON…", "Import JSON library…")) { model.importLibrary() }
                Picker(L10n.text("Набор текстов", "Text collection"), selection: Binding(get: { model.interpretationPack }, set: { model.selectInterpretationPack($0) })) {
                    ForEach(InterpretationPack.allCases) { pack in
                        Text(pack.title + (pack.url == nil ? L10n.text(" · не установлен", " · not installed") : "")).tag(pack).disabled(pack.url == nil)
                    }
                }
                Text(L10n.text("\(model.library?.records.count ?? 0) разделов из \(model.library?.sources.count ?? 0) источников. Выбранный набор используется в трактовках карты, библиотеке и PDF.", "\(model.library?.records.count ?? 0) sections from \(model.library?.sources.count ?? 0) sources. The selected collection is used in chart interpretations, the library and PDF."))
                    .font(.callout).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                Text(L10n.text("Авторские тексты сохраняются на языке оригинала. Язык интерфейса не переводит библиотеку и исходные отчёты Astrolog.", "Author texts stay in their original language. Interface language does not translate the library or Astrolog's original reports."))
                    .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }.padding(24)
    }

    private var objects: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text(L10n.text("Учитывать на карте", "Include in the chart")).font(.headline)
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), alignment: .leading), count: 3), alignment: .leading, spacing: 14) {
                ForEach(ChartPreferences.objectIDs, id: \.self) { id in
                    Toggle(isOn: objectBinding(id)) {
                        HStack(spacing: 8) {
                            Text(AstroStyle.glyph(id)).font(AstroStyle.symbolFont(size: 20)).lineLimit(1).minimumScaleFactor(0.65).frame(width: 28)
                            Text(AstroStyle.name(id))
                        }
                    }.toggleStyle(.checkbox)
                }
            }
            Divider()
            Text(L10n.text("Харон, Хирон и некоторые малые тела требуют дополнительных файлов эфемерид. Если данных нет, объект отмечается как недоступный и не получает вымышленного положения.", "Charon, Chiron and some minor bodies require additional ephemeris files. Objects without data are marked unavailable and are not assigned an estimated position."))
                .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
            Button(L10n.text("Основные планеты и узлы", "Main planets and lunar nodes")) {
                model.preferences.enabledObjects = ChartPreferences.defaults.enabledObjects
            }
        }.padding(24)
    }

    private var aspects: some View {
        VStack(alignment: .leading, spacing: 16) {
            aspectGroup(title: L10n.text("Мажорные", "Major"), major: true)
            Divider()
            aspectGroup(title: L10n.text("Минорные", "Minor"), major: false)
            Spacer(minLength: 0)
            Text(L10n.text("Выбор применяется к кругу, таблицам, сравнительным расчётам, графике и экспорту.", "These choices apply to the wheel, tables, comparisons, graphics and export."))
                .font(.caption).foregroundStyle(.secondary)
        }.padding(24)
    }

    private func aspectGroup(title: String, major: Bool) -> some View {
        let definitions = ChartPreferences.aspectDefinitions.filter { $0.isMajor == major }
        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(title).font(.headline)
                Spacer()
                Button(L10n.text("Все", "All")) { setAspects(definitions.map(\.id), enabled: true) }
                Button(L10n.text("Ни одного", "None")) { setAspects(definitions.map(\.id), enabled: false) }
            }.controlSize(.small)
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), alignment: .leading), count: 3), alignment: .leading, spacing: 10) {
                ForEach(definitions, id: \.id) { definition in
                    Toggle(L10n.text(definition.name, definition.nameEN), isOn: aspectBinding(definition.id)).toggleStyle(.checkbox)
                }
            }
        }
    }

    private func objectBinding(_ id: Int) -> Binding<Bool> {
        Binding(get: { model.preferences.enabledObjects.contains(id) }, set: { enabled in
            var value = model.preferences
            if enabled { value.enabledObjects.insert(id) } else { value.enabledObjects.remove(id) }
            model.preferences = value
        })
    }
    private func aspectBinding(_ id: Int) -> Binding<Bool> {
        Binding(get: { model.preferences.enabledAspects.contains(id) }, set: { setAspects([id], enabled: $0) })
    }
    private func setAspects(_ ids: [Int], enabled: Bool) {
        var value = model.preferences
        if enabled { value.enabledAspects.formUnion(ids) } else { value.enabledAspects.subtract(ids) }
        model.preferences = value
    }
}
