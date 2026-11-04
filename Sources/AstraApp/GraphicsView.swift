import SwiftUI
import AppKit

struct GraphicsView: View {
    @ObservedObject var model: WorkspaceModel
    @StoredState private var zoom = 1.0
    @StoredState private var fitToWindow = true
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            SectionHeading(eyebrow: L10n.text("Визуальные методы"), title: L10n.text("Графика Astrolog"), subtitle: L10n.text("Карты, сферы, орбиты и эфемериды, построенные движком Astrolog 8.0"))
            HStack(spacing: 12) {
                Picker(L10n.text("Вид"), selection: $model.selectedGraphic) { ForEach(GraphicPreset.allCases) { Text($0.title).tag($0) } }.labelsHidden()
                Spacer()
                if model.graphicIsRunning {
                    ProgressView().controlSize(.small)
                    Button(L10n.text("Отменить")) { model.cancelGraphic() }
                } else { Button(L10n.text("Построить")) { model.renderGraphic() }.buttonStyle(.borderedProminent) }
            }
            if model.selectedGraphic.needsSecondary {
                HStack {
                    Label(model.secondaryTitle, systemImage: "person.2").font(.subheadline)
                    Spacer()
                    Button(L10n.text("Данные второй карты…")) { model.edit(secondary: true) }
                    Button(L10n.text("Открыть…")) { model.open(secondary: true) }
                }.padding(12).background(.quaternary.opacity(0.3), in: RoundedRectangle(cornerRadius: 10))
            }
            if let image = model.graphicImage {
                HStack(spacing: 14) {
                    Text(model.graphicCaption).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                    Spacer(minLength: 5)
                    Toggle(L10n.text("Вместить"), isOn: $fitToWindow).toggleStyle(.button).controlSize(.small)
                    if !fitToWindow {
                        Slider(value: $zoom, in: 0.25...2.5).frame(width: 85).accessibilityLabel(L10n.text("Масштаб графика"))
                        Text("\(Int(zoom * 100))%").font(.caption).monospacedDigit().frame(width: 35)
                    }
                    Button { model.exportGraphic() } label: { Label(L10n.text("Сохранить"), systemImage: "square.and.arrow.up") }.controlSize(.small)
                }
                GeometryReader { geometry in
                    let fitScale = min(max(1, geometry.size.width - 28) / max(1, image.size.width), max(1, geometry.size.height - 28) / max(1, image.size.height))
                    let scale = fitToWindow ? fitScale : zoom
                    ScrollView([.horizontal, .vertical]) {
                        Image(nsImage: image).resizable().interpolation(.high)
                            .frame(width: image.size.width * scale, height: image.size.height * scale)
                            .padding(14)
                            .frame(minWidth: geometry.size.width, minHeight: geometry.size.height)
                            .accessibilityLabel(model.graphicCaption)
                    }
                    .background(Color(nsColor: .underPageBackgroundColor), in: RoundedRectangle(cornerRadius: 12))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            } else {
                EmptyPanel(title: L10n.text("Выберите вид графика"), description: L10n.text("Доступны карта, двойной круг, композит, сетка аспектов, астрокартография, сфера, горизонт, орбиты, глобус, эфемериды и календарь."), symbol: "globe.europe.africa")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            Text(graphicExplanation).font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
        }.padding(28)
    }
    private var graphicExplanation: String {
        switch model.selectedGraphic {
        case .natal: L10n.text("Натальная карта показывает зодиак, дома и положения объектов на выбранный момент.", "The natal chart shows the zodiac, houses and object positions at the selected moment.")
        case .biwheel: L10n.text("Двойной круг накладывает две карты для визуального сравнения их планет и аспектов.", "A biwheel overlays two charts to compare their planets and aspects.")
        case .composite: L10n.text("Композит строит общую карту по средним положениям объектов двух исходных карт.", "A composite chart uses the midpoints of corresponding objects in two charts.")
        case .aspectGrid: L10n.text("Матрица аспектов показывает угловые связи между объектами в виде таблицы.", "The aspect grid presents angular relationships between objects in a table.")
        case .astrocartography: L10n.text("Астрокартография показывает места на Земле, где объекты находятся на углах карты в заданный момент.", "Astrocartography maps where objects are on the chart angles at the selected moment.")
        case .sphere: L10n.text("Небесная сфера показывает пространственное расположение объектов вокруг наблюдателя.", "The celestial sphere shows the spatial arrangement of objects around the observer.")
        case .horizon: L10n.text("Местный горизонт показывает высоту и направление объектов относительно выбранного места.", "The local horizon shows object altitudes and directions from the selected location.")
        case .orbit: L10n.text("Орбиты дают пространственный вид положений планет Солнечной системы.", "The orbit view shows planetary positions within the Solar System.")
        case .globe: L10n.text("Глобус представляет географию карты на объёмной модели Земли.", "The globe presents chart geography on a spherical Earth.")
        case .ephemeris: L10n.text("График эфемерид показывает, как положения объектов меняются в течение месяца.", "The ephemeris graph shows how object positions change during the month.")
        case .calendar: L10n.text("Календарь раскладывает события выбранного месяца по дням.", "The calendar arranges the selected month's events by day.")
        }
    }

}

struct ChartExportPage: View {
    let snapshot: ChartSnapshot
    let title: String
    let subtitle: String
    let system: String
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 7) {
                    Text(title).font(.system(size: 28, weight: .semibold, design: .rounded))
                    Text(subtitle).font(.system(size: 13)).foregroundStyle(.secondary)
                    Text(system).font(.system(size: 12)).foregroundStyle(.secondary)
                }
                Spacer()
                Text("AstraGlass").font(.system(size: 16, weight: .medium, design: .rounded)).foregroundStyle(AstroStyle.accent)
            }
            ChartWheel(snapshot: snapshot, selectedPlanet: 0, select: { _ in }).frame(height: 790)
            Divider()
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], alignment: .leading, spacing: 9) {
                ForEach(snapshot.positions) { planet in
                    HStack(spacing: 7) {
                        Text(AstroStyle.glyph(planet.id)).font(AstroStyle.symbolFont(size: 15)).lineLimit(1).minimumScaleFactor(0.65).frame(width: 22).foregroundStyle(AstroStyle.accent)
                        Text(AstroStyle.name(planet.id)).frame(width: 87, alignment: .leading)
                        Text(AstroStyle.signGlyphs[planet.sign]).font(AstroStyle.symbolFont(size: 14))
                        Text(AstroStyle.position(planet.longitude)).monospacedDigit()
                        Text(L10n.text("· \(planet.house) дом", "· house \(planet.house)")).foregroundStyle(.secondary)
                        if planet.isRetrograde { Text("℞").font(AstroStyle.symbolFont(size: 12)).foregroundStyle(.secondary) }
                    }.font(.system(size: 12))
                }
            }
            Spacer(minLength: 0)
            Text(L10n.text("Расчёт Astrolog 8.0 · \(system)", "Astrolog 8.0 calculation · \(system)")).font(.system(size: 10)).foregroundStyle(.secondary)
        }.padding(38).frame(width: 900, height: 1120).background(.white).foregroundStyle(.black).environment(\.colorScheme, .light)
    }
}
