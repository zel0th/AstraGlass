import SwiftUI

struct SavedChartsView: View {
    @ObservedObject var model: WorkspaceModel
    @StoredState private var query = ""
    @StoredState private var deletion: StoredChart?
    private var results: [StoredChart] {
        let needle = query.trimmingCharacters(in: .whitespacesAndNewlines)
        return model.savedCharts.filter { needle.isEmpty || ($0.chart.title + " " + $0.chart.place).localizedCaseInsensitiveContains(needle) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            SectionHeading(eyebrow: L10n.text("Локальная база", "Local database"),
                           title: L10n.text("Мои карты", "My charts"),
                           subtitle: L10n.text("Карты сохраняются автоматически после применения данных. Откройте любую для повторного расчёта.", "Charts are saved automatically when you apply their details. Open any chart to calculate it again."))
            HStack {
                TextField(L10n.text("Поиск по названию или месту", "Search title or place"), text: $query).textFieldStyle(.roundedBorder)
                Button(L10n.text("Новая карта", "New chart")) { model.newChart() }
                Button { model.reloadCharts() } label: { Image(systemName: "arrow.clockwise") }
                    .help(L10n.text("Обновить список", "Refresh list"))
            }
            if results.isEmpty {
                EmptyPanel(title: L10n.text("Нет сохранённых карт", "No saved charts"),
                           description: L10n.text("Создайте карту или сохраните текущую кнопкой на панели.", "Create a chart or save the current chart using the toolbar."), symbol: "tray")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(results) { item in
                    HStack(spacing: 16) {
                        Image(systemName: "circle.hexagongrid").foregroundStyle(AstroStyle.accent).font(.title2)
                        VStack(alignment: .leading, spacing: 5) {
                            Text(item.chart.title).font(.headline)
                            Text(item.chart.place + " · " + String(format: "%02d.%02d.%04d · %02d:%02d", item.chart.input.day, item.chart.input.month, item.chart.input.year, item.chart.input.hour, item.chart.input.minute)).font(.subheadline).foregroundStyle(.secondary)
                            Text(houseSystemName(item.chart.input.houseSystem)).font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button(L10n.text("Открыть", "Open")) { model.openStoredChart(item) }
                    }.padding(.vertical, 9).contentShape(Rectangle())
                        .onTapGesture(count: 2) { model.openStoredChart(item) }
                        .contextMenu {
                            Button(L10n.text("Открыть", "Open")) { model.openStoredChart(item) }
                            Button(L10n.text("Открыть как вторую карту", "Open as second chart")) { model.openStoredChart(item, secondary: true) }
                            Divider()
                            Button(L10n.text("Удалить из базы…", "Remove from database…"), role: .destructive) { deletion = item }
                        }
                }.listStyle(.inset)
            }
            HStack {
                Text(L10n.text("\(model.savedCharts.count) карт · JSON", "\(model.savedCharts.count) charts · JSON")).font(.caption).foregroundStyle(.secondary)
                Spacer()
                Button(L10n.text("Показать файл базы", "Show database file")) { model.revealChartDatabase() }
                    .disabled(model.savedCharts.isEmpty)
            }
        }.padding(28)
            .confirmationDialog(L10n.text("Удалить сохранённую карту?", "Remove the saved chart?"), isPresented: Binding(get: { deletion != nil }, set: { if !$0 { deletion = nil } })) {
                Button(L10n.text("Удалить", "Remove"), role: .destructive) {
                    if let deletion { model.removeStoredChart(deletion) }; deletion = nil
                }
            } message: { Text(deletion?.chart.title ?? "") }
    }
}
