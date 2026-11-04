import SwiftUI

struct CityPicker: View {
    let selected: AtlasCity?
    let choose: (AtlasCity) -> Void
    @StoredState private var presented = false
    @StoredState private var query = ""
    @StoredState private var highlighted = 0
    @FocusState private var searchFocused: Bool
    private var results: [AtlasCity] { CityAtlas.shared.search(query, limit: 80) }

    var body: some View {
        Button { query = ""; highlighted = 0; presented.toggle() } label: {
            HStack {
                Image(systemName: "mappin.and.ellipse")
                Text(selected?.label ?? L10n.text("Выберите город…", "Choose a city…"))
                    .lineLimit(1).frame(maxWidth: .infinity, alignment: .leading)
                Image(systemName: "chevron.up.chevron.down").font(.caption)
            }.padding(.vertical, 5).contentShape(Rectangle())
        }
        .accessibilityLabel(L10n.text("Выбор города", "City selection"))
        .popover(isPresented: $presented, arrowEdge: .bottom) {
            VStack(spacing: 0) {
                TextField(L10n.text("Введите название города…", "Type a city name…"), text: $query)
                    .textFieldStyle(.roundedBorder).focused($searchFocused).padding(12)
                    .onChange(of: query) { _, _ in highlighted = 0 }
                    .onSubmit { if results.indices.contains(highlighted) { select(results[highlighted]) } }
                    .onMoveCommand { direction in
                        if direction == .down { highlighted = min(highlighted + 1, max(0, results.count - 1)) }
                        if direction == .up { highlighted = max(0, highlighted - 1) }
                    }
                Divider()
                if results.isEmpty {
                    Text(L10n.text("Город не найден. Попробуйте латинское название.", "No city found. Try its Latin name."))
                        .foregroundStyle(.secondary).padding()
                } else {
                    ScrollViewReader { proxy in
                        ScrollView {
                            LazyVStack(spacing: 0) {
                                ForEach(Array(results.enumerated()), id: \.element.id) { index, city in
                                    Button { select(city) } label: {
                                        HStack {
                                            VStack(alignment: .leading, spacing: 3) {
                                                Text(city.label).fontWeight(.medium)
                                                Text(city.timeZoneIdentifier + " · " + String(format: "%.2f°, %.2f°", city.latitude, city.longitude))
                                                    .font(.caption).foregroundStyle(.secondary)
                                            }
                                            Spacer()
                                            if selected?.id == city.id { Image(systemName: "checkmark") }
                                        }.padding(.horizontal, 12).padding(.vertical, 8)
                                            .background(highlighted == index ? AstroStyle.accent.opacity(0.12) : .clear)
                                            .contentShape(Rectangle())
                                    }.buttonStyle(.plain).id(city.id)
                                }
                            }
                        }.onChange(of: highlighted) { _, index in if results.indices.contains(index) { proxy.scrollTo(results[index].id) } }
                    }
                }
                Divider()
                Text(L10n.text("GeoNames · поиск без интернета · уточняйте запрос по мере ввода", "GeoNames · offline search · results filter as you type"))
                    .font(.caption2).foregroundStyle(.secondary).padding(10)
            }.frame(width: 390, height: 370)
                .onAppear { searchFocused = true }
                .onExitCommand { presented = false }
        }
    }

    private func select(_ city: AtlasCity) { choose(city); presented = false }
}
