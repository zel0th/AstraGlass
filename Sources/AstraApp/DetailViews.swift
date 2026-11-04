import SwiftUI
import AppKit

struct PlanetTableView: View {
    @ObservedObject var model: WorkspaceModel
    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            SectionHeading(eyebrow: L10n.text("Положения"), title: L10n.text("Планеты и точки"), subtitle: L10n.text("Эклиптическая долгота, движение и положение в домах"))
            if let snapshot = model.displaySnapshot {
                Table(snapshot.positions, selection: Binding<Int?>(get: { model.selectedPlanet }, set: { if let id = $0 { model.selectPlanet(id) } })) {
                    TableColumn(L10n.text("Объект")) { p in HStack(spacing: 12) { Text(AstroStyle.glyph(p.id)).font(AstroStyle.symbolFont(size: 24)).lineLimit(1).minimumScaleFactor(0.65).frame(width: 32).foregroundStyle(AstroStyle.objectColor(p.id)); Text(AstroStyle.name(p.id)).fontWeight(.medium) } }.width(min: 140, ideal: 170)
                    TableColumn(L10n.text("Знак")) { p in HStack { Text(AstroStyle.signGlyphs[p.sign]).font(AstroStyle.symbolFont(size: 16)).foregroundStyle(AstroStyle.elementColors[p.sign % 4]); Text(AstroStyle.signNames[p.sign]) } }.width(min: 100, ideal: 120)
                    TableColumn(L10n.text("Положение")) { p in Text(AstroStyle.position(p.longitude)).monospacedDigit() }.width(min: 75, ideal: 85)
                    TableColumn(L10n.text("Дом")) { p in Text("\(p.house)").monospacedDigit() }.width(40)
                    TableColumn(L10n.text("Ход")) { p in Text(p.isRetrograde ? "℞" : "D").font(AstroStyle.symbolFont(size: 13)).foregroundStyle(p.isRetrograde ? Color.orange : .secondary).help(String(format:L10n.text("%.5f° в сутки"),p.speed)) }.width(40)
                }.alternatingRowBackgrounds(.enabled)
                DisclosureGroup(L10n.text("Куспиды домов")) {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 145))], alignment: .leading, spacing: 14) {
                        ForEach(Array(snapshot.houseCusps.enumerated()), id: \.offset) { item in
                            Button { model.selectHouse(item.offset + 1) } label: { HStack { Text("\(item.offset+1)").fontWeight(.semibold).frame(width: 22,alignment:.leading); Text(AstroStyle.signGlyphs[AstroStyle.sign(item.element)]).font(AstroStyle.symbolFont(size: 14)); Text(AstroStyle.position(item.element)).monospacedDigit() }.font(.caption) }.buttonStyle(.plain).help(L10n.text("Трактовка \(item.offset + 1) дома", "House \(item.offset + 1) interpretation"))
                        }
                    }.padding(.vertical, 12)
                }
            }
        }.padding(28)
    }
}

struct AspectTableView: View {
    @ObservedObject var model: WorkspaceModel
    @StoredState private var majorOnly = false
    private var aspects: [ChartAspect] { (model.displaySnapshot?.aspects ?? []).filter { !majorOnly || ChartPreferences.majorAspectIDs.contains($0.kind) }.sorted { abs($0.orb) < abs($1.orb) } }
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            SectionHeading(eyebrow: L10n.text("Взаимодействия"), title: L10n.text("Аспекты карты"), subtitle: L10n.text("Выберите аспект: справа появятся трактовки из выбранного набора", "Choose an aspect to see interpretations from the selected collection"))
            Toggle(L10n.text("Только мажорные аспекты"), isOn: $majorOnly).toggleStyle(.switch).controlSize(.small)
            List(aspects, selection: Binding<String?>(get: { model.selectedAspect?.id }, set: { id in if let a = aspects.first(where: {$0.id == id}) { model.selectAspect(a) } })) { aspect in
                HStack(spacing: 16) {
                    Text(AstroStyle.aspectGlyph(aspect.angle)).font(AstroStyle.symbolFont(size: 28)).foregroundStyle(AstroStyle.aspectColor(aspect.angle)).frame(width: 36)
                    VStack(alignment: .leading, spacing: 4) { Text("\(AstroStyle.name(aspect.first)) — \(AstroStyle.name(aspect.second))").fontWeight(.medium); Text(AstroStyle.aspectName(aspect.angle)).font(.caption).foregroundStyle(.secondary) }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 4) { Text(String(format: "%.2f°", abs(aspect.orb))).monospacedDigit(); Text(L10n.text("орбис")).font(.caption2).foregroundStyle(.secondary) }
                }.padding(.vertical, 5).tag(aspect.id)
            }.listStyle(.inset(alternatesRowBackgrounds: true))
            Text(L10n.text("\(aspects.count) аспектов · порядок по точности", "\(aspects.count) aspects · sorted by accuracy")).font(.caption).foregroundStyle(.secondary)
        }.padding(28)
    }
}

struct InterpretationInspector: View {
    @ObservedObject var model: WorkspaceModel
    var body: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 12) {
                HStack { Text(L10n.text("ТРАКТОВКА")).font(.system(size: 10, weight: .semibold)).tracking(1.8).foregroundStyle(.secondary); Spacer(); Image(systemName: "text.book.closed").foregroundStyle(AstroStyle.accent) }
                if let sign = model.selectedSign {
                    Text(AstroStyle.signGlyphs[sign]).font(AstroStyle.symbolFont(size: 43)).foregroundStyle(AstroStyle.elementColors[sign % 4])
                    Text(AstroStyle.signNames[sign]).font(.system(size: 25, weight: .medium, design: .serif))
                } else if let house = model.selectedHouse, let cusps = model.inspectorCusps, cusps.indices.contains(house - 1) {
                    Text(L10n.text("Дом \(house)", "House \(house)")).font(.system(size: 25, weight: .medium, design: .serif))
                    Text("\(AstroStyle.signNames[AstroStyle.sign(cusps[house - 1])]) · \(AstroStyle.position(cusps[house - 1]))").font(.subheadline).foregroundStyle(.secondary)
                } else if model.comparisonIsVisible {
                    if let aspect = model.comparisonAspect {
                        Text("① " + AstroStyle.name(aspect.first) + "\n" + AstroStyle.aspectName(aspect.angle).lowercased() + "\n② " + AstroStyle.name(aspect.second)).font(.system(size: 23, weight: .medium, design: .serif))
                        Text(String(format: L10n.text("Орбис %.2f°"), abs(aspect.orb))).font(.caption).foregroundStyle(.secondary)
                        Text("① " + model.title + " · ② " + model.secondaryTitle).font(.caption).foregroundStyle(.secondary)
                    } else if let planet = model.comparisonPosition {
                        Text((model.comparisonSecondarySelected ? "② " : "① ") + AstroStyle.name(planet.id)).font(.system(size: 23, weight: .medium, design: .serif))
                        Text(AstroStyle.signNames[planet.sign] + " · " + AstroStyle.position(planet.longitude)).font(.subheadline)
                        Text(L10n.text("Дом в собственной карте: \(planet.house)", "House in its own chart: \(planet.house)")).font(.caption).foregroundStyle(.secondary)
                    } else {
                        Text(L10n.text("Выберите элемент карты")).font(.headline)
                    }
                    Text(L10n.text("Ниже — общие трактовки положений и аспектов; они не являются отдельной интерпретацией синастрии или транзита.", "Below are general interpretations of positions and aspects, not a dedicated synastry or transit interpretation."))
                        .font(.caption).foregroundStyle(.secondary)
                } else if let aspect = model.selectedAspect {
                    Text("\(AstroStyle.name(aspect.first))\n\(AstroStyle.aspectName(aspect.angle).lowercased())\n\(AstroStyle.name(aspect.second))").font(.system(size: 23, weight: .medium, design: .serif))
                    Text(String(format:L10n.text("Орбис %.2f°"),abs(aspect.orb))).font(.caption).foregroundStyle(.secondary)
                } else if model.section == .library, let record = model.selectedRecord {
                    Text(record.title).font(.system(size: 23, weight: .medium, design: .serif))
                    Text(L10n.text(record.category)).font(.caption).foregroundStyle(.secondary)
                } else if let p = model.selectedPosition {
                    HStack(alignment: .center, spacing: 14) { Text(AstroStyle.glyph(p.id)).font(AstroStyle.symbolFont(size: 43)).foregroundStyle(AstroStyle.objectColor(p.id)); VStack(alignment: .leading,spacing:5) { Text(AstroStyle.name(p.id)).font(.system(size: 24, weight: .medium, design: .serif)); Text("\(AstroStyle.signNames[p.sign]) · \(AstroStyle.position(p.longitude))").font(.subheadline).foregroundStyle(.secondary) } }
                    HStack { Label(L10n.text("\(p.house) дом", "House \(p.house)"),systemImage:"house"); if p.isRetrograde { Text(L10n.text("Ретроградная")) } }.font(.caption).foregroundStyle(.secondary)
                }
            }.frame(maxWidth:.infinity,alignment:.leading).padding(23)
            Divider()
            if model.relevantPassages.isEmpty {
                EmptyPanel(title: L10n.text("Выберите элемент карты"), description: model.library == nil ? L10n.text("Добавьте индекс текстов в настройках приложения.") : L10n.text("Для этой точки нет отдельной главы в загруженных книгах."), symbol: "text.book.closed").padding()
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 25) {
                        if model.selectedAspect != nil && model.interpretationPack == .podvodny { Text(L10n.text("В книгах описаны проявления аспекта для каждой планеты отдельно. Ниже приведены эти авторские разделы.")).font(.caption).foregroundStyle(.secondary) }
                        ForEach(model.relevantPassages) { record in SourcePassageView(record: record); Divider() }
                    }.padding(23)
                }
            }
        }.frame(maxHeight: .infinity, alignment: .top)
            .background(Color(nsColor: .textBackgroundColor).opacity(0.35))
    }
}

struct LibraryView: View {
    @ObservedObject var model: WorkspaceModel
    @StoredState private var selectedID: String?
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            SectionHeading(eyebrow: L10n.text("Первоисточники"), title: model.interpretationPack.title, subtitle: L10n.text("Поиск по заголовкам и полному тексту выбранного набора.", "Search titles and full text in the selected collection."))
            HStack {
                TextField(L10n.text("Планета, знак, дом или фраза"), text: $model.librarySearch).textFieldStyle(.roundedBorder)
                Picker(L10n.text("Раздел"),selection:$model.libraryCategory) { Text(L10n.text("Все")).tag("Все"); ForEach(model.library?.categories ?? [],id:\.self) { Text(L10n.text($0)).tag($0) } }.labelsHidden().frame(width:130)
            }
            List(model.libraryResults, selection: $selectedID) { record in
                VStack(alignment: .leading, spacing: 7) {
                    HStack { Text(record.title).font(.system(.headline,design:.serif)); Spacer(); Text(L10n.text(record.category)).font(.caption2).foregroundStyle(.secondary) }
                    Text(record.body.prefix(180) + (record.body.count > 180 ? "…" : "")).font(.caption).foregroundStyle(.secondary).lineLimit(2)
                    Text(record.sourceTitle).font(.system(size:10)).foregroundStyle(.tertiary)
                }.padding(.vertical,7).tag(record.id)
            }.listStyle(.inset).onChange(of: selectedID) { _, id in model.selectedRecord = model.library?.records.first(where: {$0.id == id}); model.selectedAspect = nil; model.selectedHouse = nil; model.selectedSign = nil; model.showInspector = true }
            HStack { Text(L10n.text("Показано \(model.libraryResults.count) из \(model.library?.records.count ?? 0) разделов", "Showing \(model.libraryResults.count) of \(model.library?.records.count ?? 0) sections")).font(.caption).foregroundStyle(.secondary); Spacer(); Button(L10n.text("Импортировать…")) { model.importLibrary() } }
        }.padding(28)
    }
}

struct ReportsView: View {
    @ObservedObject var model: WorkspaceModel
    @StoredState private var expert = false
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            SectionHeading(eyebrow: "Astrolog 8.0", title: L10n.text("Расчёты и отчёты"), subtitle: L10n.text("Эфемериды, аспекты, мидпойнты и дополнительные методы анализа"))
            HStack { Picker(L10n.text("Отчёт"),selection:$model.selectedReport) { ForEach(ReportPreset.allCases) { Text(L10n.text($0.rawValue)).tag($0) } }.labelsHidden(); Spacer(); reportButton }
            DisclosureGroup(L10n.text("Расширенные параметры Astrolog"),isExpanded:$expert) {
                VStack(alignment:.leading,spacing:10) {
                    TextField(L10n.text("Например: -v -g -a"),text:$model.expertOptions).font(.system(.body,design:.monospaced)).textFieldStyle(.roundedBorder)
                    HStack { Text(L10n.text("Параметры добавляются к данным текущей карты.")).font(.caption).foregroundStyle(.secondary); Spacer(); Button(L10n.text("Выполнить")) { model.runExpert() }.disabled(model.reportIsRunning) }
                }.padding(.top,8)
            }
            ReportOutput(model: model)
            Text(L10n.text("Отчёты дополняют круг числовыми таблицами: положениями, аспектами, мидпойнтами и событиями месяца. Выберите метод, затем нажмите «Рассчитать».", "Reports complement the wheel with tables of positions, aspects, midpoints and monthly events. Select a method, then choose Calculate."))
                .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
        }.padding(28)
    }
    private var reportButton: some View { Group { if model.reportIsRunning { ProgressView().controlSize(.small); Button(L10n.text("Отменить")) { model.cancelReport() } } else { Button(L10n.text("Рассчитать")) { model.runReport() }.buttonStyle(.borderedProminent) } } }
}

struct ReportOutput: View {
    @ObservedObject var model: WorkspaceModel
    var body: some View {
        VStack(alignment:.leading,spacing:12) {
            HStack { Text(model.reportTitle).font(.headline); Spacer(); Button { NSPasteboard.general.clearContents(); NSPasteboard.general.setString(model.report,forType:.string) } label: { Image(systemName:"doc.on.doc") }.help(L10n.text("Скопировать отчёт")).disabled(model.report.isEmpty); Button { model.exportReport() } label: { Image(systemName:"square.and.arrow.up") }.help(L10n.text("Сохранить отчёт")).disabled(model.report.isEmpty) }
            if model.report.isEmpty { EmptyPanel(title:L10n.text("Отчёт ещё не построен"),description:L10n.text("Выберите вид расчёта и нажмите «Рассчитать»."),symbol:"doc.text.magnifyingglass").frame(maxWidth:.infinity,maxHeight:.infinity) }
            else { ScrollView([.horizontal,.vertical]) { Text(model.report).font(.system(size:12,design:.monospaced)).textSelection(.enabled).fixedSize(horizontal:true,vertical:true).padding(18).frame(maxWidth:.infinity,alignment:.topLeading) }.background(Color(nsColor:.textBackgroundColor),in:RoundedRectangle(cornerRadius:12)) }
        }.frame(maxWidth:.infinity,maxHeight:.infinity,alignment:.topLeading)
    }
}

