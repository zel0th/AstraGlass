import SwiftUI
import AppKit
import CoreText

// Explicit wrapper alias keeps CLT-only builds independent of optional Xcode macro plug-ins.
typealias StoredState<Value> = SwiftUI.State<Value>

enum AstroStyle {
    static let accent = Color(red: 0.45, green: 0.37, blue: 0.83)
    static var planetNames: [String] { [L10n.text("Земля"), L10n.text("Солнце"), L10n.text("Луна"), L10n.text("Меркурий"), L10n.text("Венера"), L10n.text("Марс"), L10n.text("Юпитер"), L10n.text("Сатурн"), L10n.text("Уран"), L10n.text("Нептун"), L10n.text("Плутон"), L10n.text("Хирон"), L10n.text("Церера"), L10n.text("Паллада"), L10n.text("Юнона"), L10n.text("Веста"), L10n.text("Северный узел"), L10n.text("Южный узел"), L10n.text("Лилит"), L10n.text("Фортуна"), L10n.text("Вертекс"), L10n.text("Восточная точка")] }
    static let planetGlyphs = ["♁", "☉", "☽", "☿", "♀", "♂", "♃", "♄", "♅", "♆", "⯓", "⚷", "⚳", "⚴", "⚵", "⚶", "☊", "☋", "⚸", "⊗", "Vx", "EP"]
    static var signNames: [String] { [L10n.text("Овен"), L10n.text("Телец"), L10n.text("Близнецы"), L10n.text("Рак"), L10n.text("Лев"), L10n.text("Дева"), L10n.text("Весы"), L10n.text("Скорпион"), L10n.text("Стрелец"), L10n.text("Козерог"), L10n.text("Водолей"), L10n.text("Рыбы")] }
    static let signGlyphs = ["♈", "♉", "♊", "♋", "♌", "♍", "♎", "♏", "♐", "♑", "♒", "♓"]
    static let elementColors: [Color] = [.orange, .green, .cyan, .indigo]
    /// An explicit app palette, independent of a planet's current zodiac sign.
    /// Selection uses an outline; it never replaces the object's characteristic color.
    static func objectColor(_ id: Int) -> Color {
        switch id {
        case 1, 5, 10, 74: return .red // Sun, Mars, Pluto, Charon
        case 2, 9: return .blue       // Moon, Neptune
        case 3, 8, 21: return .cyan   // Mercury, Uranus, East Point
        case 0, 4, 12: return .green  // Earth, Venus, Ceres
        case 6, 15, 19: return .orange // Jupiter, Vesta, Fortune
        case 7: return Color(red: 0.72, green: 0.53, blue: 0.25) // Saturn: ochre
        case 11, 13: return .teal     // Chiron, Pallas
        case 14, 16, 18, 20: return .purple // Juno, North Node, Lilith, Vertex
        case 17: return .pink        // South Node
        default: return .secondary
        }
    }
    static func name(_ id: Int) -> String { id == 74 ? L10n.text("Харон", "Charon") : planetNames.indices.contains(id) ? planetNames[id] : L10n.text("Объект \(id)", "Object \(id)") }
    /// Charon has no widely established Unicode astrology glyph; an explicit
    /// abbreviation avoids a missing-font box or an invented planetary symbol.
    static func glyph(_ id: Int) -> String {
        if id == 74 { return "Ch" }
        return planetGlyphs.indices.contains(id) ? planetGlyphs[id] : "\(id)"
    }
    private static let registeredSymbolFont: String = {
        if let url = Bundle.main.url(forResource: "AstraGlassAstrology", withExtension: "ttf", subdirectory: "Fonts") {
            CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
        }
        return "AstraGlassAstrology"
    }()
    static func symbolFont(size: CGFloat) -> Font { .custom(registeredSymbolFont, size: size) }
    static func symbolNSFont(size: CGFloat) -> NSFont {
        NSFont(name: registeredSymbolFont, size: size) ?? NSFont(name: "Apple Symbols", size: size) ?? .systemFont(ofSize: size)
    }
    static func sign(_ longitude: Double) -> Int { Int((longitude.truncatingRemainder(dividingBy: 360) + 360).truncatingRemainder(dividingBy: 360) / 30) }
    static func position(_ longitude: Double) -> String {
        let normalized = (longitude + 360).truncatingRemainder(dividingBy: 360)
        let d = Int(normalized.truncatingRemainder(dividingBy: 30))
        let m = Int((normalized - floor(normalized)) * 60)
        return String(format: "%02d° %02d′", d, m)
    }
    static func aspectName(_ angle: Double) -> String {
        if let definition = ChartPreferences.aspectDefinitions.first(where: { abs($0.angle - angle) < 0.01 }) {
            return L10n.text(definition.name, definition.nameEN)
        }
        return L10n.text("Аспект \(Int(angle))°", "Aspect \(Int(angle))°")
    }
    static func aspectGlyph(_ angle: Double) -> String {
        switch Int(angle.rounded()) { case 0: return "☌"; case 60: return "✶"; case 90: return "□"; case 120: return "△"; case 180: return "☍"; default: return "∠" }
    }
    static func aspectColor(_ angle: Double) -> Color {
        switch Int(angle.rounded()) {
        case 0: return .blue
        case 180: return Color(red: 0.72, green: 0.52, blue: 0.94)
        case 90, 45, 135: return .red
        case 120: return .green
        case 60: return .teal
        default: return accent
        }
    }
}

enum AppSection: String, CaseIterable, Identifiable {
    case savedCharts = "Мои карты", chart = "Карта", planets = "Планеты", aspects = "Аспекты", relationships = "Синастрия", transits = "Транзиты", reports = "Отчёты", graphics = "Графика", library = "Библиотека"
    var id: String { rawValue }
    var symbol: String {
        switch self { case .savedCharts: return "tray.full"; case .chart: return "circle.hexagongrid"; case .planets: return "sparkles"; case .aspects: return "point.3.connected.trianglepath.dotted"; case .relationships: return "person.2"; case .transits: return "clock.arrow.circlepath"; case .reports: return "chart.xyaxis.line"; case .graphics: return "globe.europe.africa"; case .library: return "books.vertical" }
    }
}

struct SectionHeading: View {
    let eyebrow: String
    let title: String
    let subtitle: String
    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(eyebrow.uppercased()).font(.system(size: 10, weight: .semibold)).tracking(1.8).foregroundStyle(AstroStyle.accent)
            Text(title).font(.system(size: 28, weight: .semibold, design: .rounded))
            Text(subtitle).font(.subheadline).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
        }
    }
}

struct EmptyPanel: View {
    var title: String
    var description: String
    var symbol: String = "sparkles"
    var body: some View { ContentUnavailableView(title, systemImage: symbol, description: Text(description)) }
}

struct SourcePassageView: View {
    let record: InterpretationRecord
    @StoredState private var expanded = true
    var body: some View {
        VStack(alignment: .leading, spacing: 13) {
            HStack(alignment: .top) {
                Text(record.title).font(.system(.headline, design: .serif))
                Spacer(minLength: 8)
                Button { expanded.toggle() } label: { Image(systemName: expanded ? "chevron.up" : "chevron.down") }.buttonStyle(.plain).help(expanded ? L10n.text("Свернуть текст") : L10n.text("Развернуть текст"))
            }
            if expanded {
                Text(record.body).font(.system(size: 14, design: .serif)).lineSpacing(5).textSelection(.enabled).fixedSize(horizontal: false, vertical: true)
                Text(record.sourceTitle).font(.caption).foregroundStyle(.secondary)
                Text(record.source + " · " + record.sourceRange).font(.system(size: 10)).foregroundStyle(.tertiary).textSelection(.enabled)
            }
        }
    }
}
