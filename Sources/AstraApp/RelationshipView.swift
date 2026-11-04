import SwiftUI

struct RelationshipView: View {
    @ObservedObject var model: WorkspaceModel
    let transit: Bool
    @StoredState private var showTable = false

    var body: some View {
        GeometryReader { viewport in
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                SectionHeading(eyebrow: transit ? L10n.text("Движение во времени") : L10n.text("Две карты"),
                    title: transit ? L10n.text("Транзиты") : L10n.text("Синастрия"),
                    subtitle: transit ? L10n.text("Сопоставьте положение планет на выбранную дату с натальной картой") : L10n.text("Сравните положения планет и межкартные аспекты"))
                HStack(alignment: .top, spacing: 20) {
                    chartLabel(secondary: false)
                    Divider()
                    chartLabel(secondary: true)
                }.fixedSize(horizontal: false, vertical: true).padding(16)
                    .background(.quaternary.opacity(0.3), in: RoundedRectangle(cornerRadius: 16))
                HStack {
                    Picker(L10n.text("Представление", "View"), selection: $showTable) {
                        Text(L10n.text("Карта")).tag(false)
                        Text(L10n.text("Таблица", "Table")).tag(true)
                    }.pickerStyle(.segmented).labelsHidden().frame(maxWidth: 220)
                    Spacer()
                    if model.reportIsRunning {
                        ProgressView().controlSize(.small)
                        Button(L10n.text("Отменить")) { model.cancelReport() }
                    } else {
                        Button(transit ? L10n.text("Рассчитать транзиты") : L10n.text("Сравнить карты")) { model.runComparison(transit: transit) }
                            .buttonStyle(.borderedProminent)
                    }
                }
                if let result = model.comparison, result.transit == transit {
                    if showTable { ComparisonTable(model: model, result: result) }
                    else {
                        ChartWheel(snapshot: result.primary,
                            selectedPlanet: model.comparisonSecondarySelected ? 0 : model.comparisonPlanet ?? 0,
                            select: { model.selectComparisonPlanet($0, secondary: false) },
                            selectSign: model.selectComparisonSign,
                            selectAspect: model.selectComparisonAspect,
                            selectHouse: model.selectComparisonHouse,
                            selectedAspect: model.comparisonAspect,
                            selectedSign: model.selectedSign,
                            selectedHouse: model.selectedHouse,
                            secondarySnapshot: result.secondary, comparisonAspects: result.aspects,
                            selectedSecondaryPlanet: model.comparisonSecondarySelected ? model.comparisonPlanet : nil,
                            selectSecondary: { model.selectComparisonPlanet($0, secondary: true) })
                            .frame(width: max(420, viewport.size.width - 56), height: max(420, viewport.size.width - 56))
                        Text(L10n.text("① Внешний ряд — основная карта. ② Внутренний ряд, пунктирная рамка — вторая карта. Линии в центре показывают только межкартные аспекты.", "① Outer row: primary chart. ② Inner row, dashed outline: second chart. Central lines show only cross-chart aspects."))
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    Text(L10n.text("Дома и зодиак — основной карты. Обе группы планет рассчитаны в одной системе зодиака.", "Houses and zodiac follow the primary chart. Both sets of planets use the same zodiac convention."))
                        .font(.caption).foregroundStyle(.secondary)
                    let missing = Set(result.primary.unavailableObjects + result.secondary.unavailableObjects)
                    if !missing.isEmpty {
                        Text(L10n.text("Недоступные эфемериды: ", "Unavailable ephemerides: ") + missing.sorted().map { AstroStyle.name($0) }.joined(separator: ", "))
                            .font(.caption).foregroundStyle(.secondary)
                    }
                } else if !model.report.isEmpty {
                    ReportOutput(model: model).frame(minHeight: 400)
                } else if !model.reportIsRunning {
                    EmptyPanel(title: L10n.text("Карта ещё не построена", "Chart not calculated"),
                        description: L10n.text("Проверьте данные обеих карт и запустите расчёт.", "Check both charts and start the calculation."), symbol: "circle.hexagongrid")
                        .frame(maxWidth: .infinity, minHeight: 280)
                }
                if transit {
                    Button(L10n.text("Транзиты на месяц")) { model.runMonthlyTransits() }.disabled(model.reportIsRunning)
                }
            }.padding(28)
        }
        }
        .task(id: transit) {
            if model.comparison?.transit != transit { model.runComparison(transit: transit) }
        }
    }

    private func chartLabel(secondary: Bool) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(secondary ? (transit ? L10n.text("② Транзитная дата", "② Transit date") : L10n.text("② Вторая карта", "② Second chart")) : L10n.text("① Основная карта", "① Primary chart"))
                .font(.caption.weight(.semibold)).foregroundStyle(.secondary)
            Text(secondary ? model.secondaryTitle : model.title).font(.headline)
            Text(secondary ? model.secondaryPlace : model.place).font(.caption).foregroundStyle(.secondary)
            Text(secondary ? model.secondaryDateSummary : model.dateSummary).font(.caption).foregroundStyle(.secondary)
            HStack {
                Button(L10n.text("Изменить…")) { model.edit(secondary: secondary) }
                if secondary { Button(L10n.text("Открыть…")) { model.open(secondary: true) } }
            }
        }.frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct ComparisonTable: View {
    @ObservedObject var model: WorkspaceModel
    let result: ComparisonSnapshot
    private var objectIDs: [Int] {
        Set(result.primary.positions.map(\.id) + result.secondary.positions.map(\.id)).sorted()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text(L10n.text("Положения планет")).font(.headline)
            Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 10) {
                GridRow {
                    Text(L10n.text("Объект", "Object"))
                    Text(L10n.text("① Основная карта", "① Primary chart"))
                    Text(L10n.text("② Вторая карта", "② Second chart"))
                }.font(.caption).foregroundStyle(.secondary)
                ForEach(objectIDs, id: \.self) { id in
                    GridRow {
                        HStack(spacing: 7) {
                            Text(AstroStyle.glyph(id)).font(AstroStyle.symbolFont(size: 21)).foregroundStyle(AstroStyle.objectColor(id)).frame(width: 24)
                            Text(AstroStyle.name(id))
                        }
                        if let first = result.primary.positions.first(where: { $0.id == id }) {
                            position(first, secondary: false)
                        } else { Text("—").foregroundStyle(.secondary) }
                        if let second = result.secondary.positions.first(where: { $0.id == id }) {
                            position(second, secondary: true)
                        } else { Text("—").foregroundStyle(.secondary) }
                    }
                }
            }.font(.callout)
            Divider()
            Text(L10n.text("Межкартные аспекты", "Cross-chart aspects")).font(.headline)
            if result.aspects.isEmpty {
                Text(L10n.text("Нет аспектов с выбранными настройками.", "No aspects with the selected settings.")).foregroundStyle(.secondary)
            }
            LazyVStack(spacing: 4) {
                ForEach(result.aspects.sorted { abs($0.orb) < abs($1.orb) }) { aspect in
                    Button { model.selectComparisonAspect(aspect) } label: {
                        HStack(spacing: 10) {
                            Text(AstroStyle.aspectGlyph(aspect.angle)).font(AstroStyle.symbolFont(size: 21)).foregroundStyle(AstroStyle.aspectColor(aspect.angle)).frame(width: 24)
                            Text("① " + AstroStyle.name(aspect.first))
                            Text(AstroStyle.aspectName(aspect.angle).lowercased()).foregroundStyle(.secondary)
                            Text("② " + AstroStyle.name(aspect.second))
                            Spacer(minLength: 2)
                            Text(String(format: L10n.text("Орбис %.2f°"), abs(aspect.orb))).font(.caption).monospacedDigit().foregroundStyle(.secondary)
                        }.padding(9).frame(maxWidth: .infinity, alignment: .leading)
                            .background(model.comparisonAspect?.id == aspect.id ? AstroStyle.aspectColor(aspect.angle).opacity(0.12) : .clear, in: RoundedRectangle(cornerRadius: 8))
                            .contentShape(Rectangle())
                    }.buttonStyle(.plain)
                }
            }.font(.callout)
        }.padding(18).frame(maxWidth: .infinity, alignment: .leading)
            .background(.quaternary.opacity(0.2), in: RoundedRectangle(cornerRadius: 16))
    }

    private func position(_ planet: PlanetPosition, secondary: Bool) -> some View {
        Button { model.selectComparisonPlanet(planet.id, secondary: secondary) } label: {
            Text(AstroStyle.signNames[planet.sign] + " · " + AstroStyle.position(planet.longitude) + (planet.isRetrograde ? " ℞" : ""))
        }.buttonStyle(.plain)
    }
}
