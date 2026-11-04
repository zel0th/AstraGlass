import SwiftUI

/// A saved-record chooser shared by the primary and secondary chart editors.
/// Selection only fills the editor; its caller owns the pending changes.
struct SavedChartPicker: View {
    @ObservedObject var model: WorkspaceModel
    let selectedID: UUID?
    let choose: (StoredChart) -> Void
    @StoredState private var presented = false
    @StoredState private var query = ""
    @FocusState private var searchFocused: Bool

    private var results: [StoredChart] {
        let needle = query.trimmingCharacters(in: .whitespacesAndNewlines)
        return model.savedCharts.filter {
            needle.isEmpty || ($0.chart.title + " " + $0.chart.place + " " + dateLabel($0))
                .localizedCaseInsensitiveContains(needle)
        }
    }

    var body: some View {
        Button {
            model.reloadCharts(); query = ""; presented.toggle()
        } label: {
            Label(L10n.text("Из библиотеки…", "From library…"), systemImage: "tray.full")
        }
        .help(L10n.text("Загрузить данные из сохранённых карт", "Load details from saved charts"))
        .popover(isPresented: $presented, arrowEdge: .bottom) {
            VStack(alignment: .leading, spacing: 12) {
                Text(L10n.text("Библиотека карт", "Chart library")).font(.headline)
                TextField(L10n.text("Название, место или дата", "Title, place or date"), text: $query)
                    .textFieldStyle(.roundedBorder).focused($searchFocused)
                    .onSubmit { if results.count == 1, let item = results.first { select(item) } }
                Divider()
                if results.isEmpty {
                    Text(model.savedCharts.isEmpty
                         ? L10n.text("Сохранённых карт пока нет. Они появятся здесь после применения данных карты.", "No saved charts yet. Apply chart details to save a chart here.")
                         : L10n.text("Карты не найдены. Измените запрос.", "No matching charts. Change your search."))
                        .foregroundStyle(.secondary).frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView {
                        LazyVStack(spacing: 4) {
                            ForEach(results) { item in
                                Button { select(item) } label: {
                                    HStack {
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(item.chart.title).fontWeight(.medium)
                                            Text(item.chart.place + " · " + dateLabel(item)).font(.caption).foregroundStyle(.secondary)
                                        }
                                        Spacer()
                                        if selectedID == item.id { Image(systemName: "checkmark") }
                                    }.frame(maxWidth: .infinity, alignment: .leading).padding(9)
                                        .background(selectedID == item.id ? AstroStyle.accent.opacity(0.12) : .clear, in: RoundedRectangle(cornerRadius: 7))
                                        .contentShape(Rectangle())
                                }.buttonStyle(.plain)
                            }
                        }
                    }
                }
                Divider()
                Text(L10n.text("Выбор заполнит редактор. «Применить» сохранит изменения в выбранной карте; «Отмена» оставит её без изменений.", "Selection fills the editor. Apply saves changes to the selected chart; Cancel leaves it unchanged."))
                    .font(.caption).foregroundStyle(.secondary)
            }.padding(16).frame(width: 430, height: 390)
                .onAppear { searchFocused = true }.onExitCommand { presented = false }
        }
    }

    private func select(_ item: StoredChart) { choose(item); presented = false }
    private func dateLabel(_ item: StoredChart) -> String {
        let input = item.chart.input
        return String(format: "%02d.%02d.%04d · %02d:%02d", input.day, input.month, input.year, input.hour, input.minute)
    }
}
