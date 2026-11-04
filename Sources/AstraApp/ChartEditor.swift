import SwiftUI
import AppKit

struct ChartEditor: View {
    @ObservedObject var model: WorkspaceModel
    let secondary: Bool
    @Environment(\.dismiss) private var dismiss
    @StoredState private var title = ""
    @StoredState private var place = ""
    @StoredState private var input = ChartInput()
    @StoredState private var cityQuery = ""
    @StoredState private var automaticTimeZone = false
    @StoredState private var matches: [CivilTimeMatch] = []
    @StoredState private var occurrence = -1
    @StoredState private var timeZoneError: String?
    @StoredState private var validationError: String?
    @StoredState private var initialized = false
    @StoredState private var resolvedCivilFields: [Int] = []
    @StoredState private var resolvedAutomaticTimeZone = false
    private let atlas = CityAtlas.shared
    private var cities: [AtlasCity] { atlas.search(cityQuery, limit: 6) }
    private var civilFields: [Int] { [input.year, input.month, input.day, input.hour, input.minute] }
    private var selectedCity: AtlasCity? { atlas.city(id: input.cityID) }
    private var selectedMatch: CivilTimeMatch? { matches.indices.contains(occurrence) ? matches[occurrence] : nil }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                VStack(alignment: .leading, spacing: 5) {
                    Text(secondary ? L10n.text("Вторая карта", "Second chart") : L10n.text("Данные карты", "Chart details")).font(.title2.weight(.semibold))
                    Text(L10n.text("Дата, местное время и место рождения или события", "Date, local time and place of birth or event")).foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "sparkles").font(.title).foregroundStyle(AstroStyle.accent)
            }
            TextField(L10n.text("Название карты", "Chart title"), text: $title).textFieldStyle(.roundedBorder)
            HStack(alignment: .top, spacing: 20) {
                VStack(alignment: .leading, spacing: 14) {
                    citySelection
                    GroupBox(L10n.text("Координаты", "Coordinates")) {
                        VStack(alignment: .leading, spacing: 10) {
                            TextField(L10n.text("Название места", "Place label"), text: $place)
                            TextField(L10n.text("Широта, °", "Latitude, °"), value: coordinateBinding(latitude: true), format: .number.precision(.fractionLength(0...5)))
                                .disabled(selectedCity != nil)
                            TextField(L10n.text("Долгота, °", "Longitude, °"), value: coordinateBinding(latitude: false), format: .number.precision(.fractionLength(0...5)))
                                .disabled(selectedCity != nil)
                            Text(L10n.text("Север и восток — положительные значения.", "North and east use positive values.")).font(.caption).foregroundStyle(.secondary)
                            if selectedCity != nil {
                                Button(L10n.text("Ввести координаты вручную", "Enter coordinates manually")) {
                                    input.cityID = nil; input.timeZoneIdentifier = nil
                                    automaticTimeZone = false; matches = []; timeZoneError = nil
                                }.controlSize(.small)
                            }
                        }.padding(8).textFieldStyle(.roundedBorder)
                    }
                }.frame(maxWidth: .infinity, alignment: .topLeading)
                VStack(alignment: .leading, spacing: 14) {
                    GroupBox(L10n.text("Местное время", "Local time")) {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                numberField(L10n.text("Год", "Year"), value: $input.year)
                                numberField(L10n.text("Месяц", "Month"), value: $input.month)
                                numberField(L10n.text("День", "Day"), value: $input.day)
                            }
                            HStack {
                                numberField(L10n.text("Час", "Hour"), value: $input.hour)
                                numberField(L10n.text("Минуты", "Minute"), value: $input.minute)
                            }
                            Toggle(L10n.text("Часовой пояс автоматически", "Automatic time zone"), isOn: $automaticTimeZone)
                                .disabled(input.timeZoneIdentifier == nil)
                            if automaticTimeZone {
                                Text(input.timeZoneIdentifier ?? "").font(.caption).foregroundStyle(.secondary)
                                if matches.count > 1 {
                                    Text(L10n.text("В этот день часы переводились назад. Укажите, какое вхождение времени имеется в виду.", "Clocks moved back on this date. Choose which occurrence of this time you mean.")).font(.caption).foregroundStyle(.orange)
                                    Picker(L10n.text("Вхождение", "Occurrence"), selection: $occurrence) {
                                        Text(L10n.text("Выберите…", "Choose…")).tag(-1)
                                        ForEach(matches.indices, id: \.self) { i in
                                            Text("\(i + 1) · \(matches[i].offsetLabel) · \(season(matches[i]))").tag(i)
                                        }
                                    }
                                }
                                if let match = selectedMatch {
                                    Text(match.offsetLabel + " · " + season(match)).font(.subheadline.weight(.medium))
                                }
                                if let timeZoneError { Text(timeZoneError).font(.caption).foregroundStyle(.red) }
                            } else {
                                TextField(L10n.text("Смещение UTC, часы", "UTC offset, hours"), value: $input.utcOffset, format: .number.precision(.fractionLength(0...4)))
                                Text(L10n.text("Укажите смещение, действовавшее на дату карты, включая летнее время.", "Enter the offset in effect on the chart date, including daylight saving time.")).font(.caption).foregroundStyle(.secondary)
                            }
                            Text(L10n.text("При выборе города учитываются исторические правила часового пояса из macOS. Для старых дат проверьте местные исторические сведения.", "City selection uses historical time-zone rules from macOS. For older dates, check local historical records.")).font(.caption2).foregroundStyle(.secondary)
                        }.padding(8).textFieldStyle(.roundedBorder)
                    }
                    GroupBox(L10n.text("Расчёт", "Calculation")) {
                        VStack(alignment: .leading, spacing: 12) {
                            Picker(L10n.text("Система домов", "House system"), selection: $input.houseSystem) {
                                ForEach(0..<40, id: \.self) { Text(houseSystemName($0)).tag($0) }
                            }
                            Toggle(L10n.text("Сидерический зодиак", "Sidereal zodiac"), isOn: $input.sidereal)
                        }.padding(8)
                    }
                }.frame(maxWidth: .infinity, alignment: .topLeading)
            }
            if let validationError { Text(validationError).foregroundStyle(.red).font(.caption) }
            Spacer(minLength: 0)
            Divider()
            HStack {
                Button(L10n.text("Отмена", "Cancel")) { dismiss() }.keyboardShortcut(.cancelAction)
                Spacer()
                Button(L10n.text("Применить", "Apply")) { apply() }.buttonStyle(.borderedProminent).keyboardShortcut(.defaultAction)
                    .disabled(automaticTimeZone && (timeZoneError != nil || selectedMatch == nil))
            }
        }
        .padding(24).frame(width: 800, height: 700)
        .onAppear(perform: initialize)
        .onChange(of: civilFields) { _, value in if initialized && value != resolvedCivilFields { refreshTimeZone() } }
        .onChange(of: automaticTimeZone) { _, value in if initialized && value != resolvedAutomaticTimeZone { refreshTimeZone() } }
        .onChange(of: occurrence) { _, _ in if let match = selectedMatch { input.utcOffset = match.utcOffset } }
    }

    private var citySelection: some View {
        GroupBox(L10n.text("Город", "City")) {
            VStack(alignment: .leading, spacing: 10) {
                TextField(L10n.text("Поиск города или кода страны…", "Search city or country code…"), text: $cityQuery)
                    .textFieldStyle(.roundedBorder)
                if cityQuery.trimmingCharacters(in: .whitespaces).count >= 2 {
                    if cities.isEmpty {
                        Text(L10n.text("Город не найден. Попробуйте латинское название или введите координаты вручную.", "No city found. Try its Latin name or enter coordinates manually.")).font(.caption).foregroundStyle(.secondary)
                    } else {
                        VStack(alignment: .leading, spacing: 0) {
                            ForEach(cities) { city in
                                Button { choose(city) } label: {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(city.label).lineLimit(1)
                                        Text(city.timeZoneIdentifier + " · " + String(format: "%.2f°, %.2f°", city.latitude, city.longitude)).font(.caption2).foregroundStyle(.secondary).lineLimit(1)
                                    }.padding(.vertical, 5).frame(maxWidth: .infinity, alignment: .leading).contentShape(Rectangle())
                                }.buttonStyle(.plain)
                                if city.id != cities.last?.id { Divider() }
                            }
                        }
                    }
                } else if let city = selectedCity {
                    Label(city.label, systemImage: "mappin.and.ellipse").font(.subheadline.weight(.medium))
                    Text(city.timeZoneIdentifier).font(.caption).foregroundStyle(.secondary)
                } else {
                    Text(L10n.text("Выберите город: координаты и смещение UTC подставятся по дате карты.", "Choose a city to fill coordinates and the UTC offset for the chart date.")).font(.caption).foregroundStyle(.secondary)
                }
                if atlas.cities.isEmpty {
                    Text(L10n.text("Атлас городов недоступен. Можно ввести координаты и UTC вручную.", "City atlas is unavailable. You can enter coordinates and UTC manually.")).font(.caption).foregroundStyle(.orange)
                }
                Text(L10n.text("Атлас GeoNames · поиск без интернета", "GeoNames atlas · offline search")).font(.caption2).foregroundStyle(.tertiary)
            }.padding(8).frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func numberField(_ label: String, value: Binding<Int>) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label).font(.caption).foregroundStyle(.secondary)
            TextField(label, value: value, format: .number.grouping(.never)).labelsHidden()
        }
    }

    private func choose(_ city: AtlasCity) {
        input.cityID = city.id; input.timeZoneIdentifier = city.timeZoneIdentifier
        input.latitude = city.latitude; input.longitude = city.longitude
        place = city.label; cityQuery = ""; automaticTimeZone = true
        refreshTimeZone()
    }

    private func season(_ match: CivilTimeMatch) -> String {
        match.isDaylightSavingTime ? L10n.text("летнее время", "daylight time") : L10n.text("стандартное время", "standard time")
    }

    private func initialize() {
        input = secondary ? model.secondaryInput : model.input
        title = secondary ? model.secondaryTitle : model.title
        place = secondary ? model.secondaryPlace : model.place
        automaticTimeZone = input.usesAutomaticTimeZone ?? false
        if model.creatingChart {
            let parts = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: Date())
            title = L10n.text("Новая карта", "New chart")
            input.year = parts.year ?? 2000; input.month = parts.month ?? 1; input.day = parts.day ?? 1
            input.hour = parts.hour ?? 12; input.minute = parts.minute ?? 0
            // Preserve an explicitly selected city, but never associate the
            // system time zone with a different city inherited from another chart.
            if input.timeZoneIdentifier == nil { input.utcOffset = Double(TimeZone.current.secondsFromGMT()) / 3600 }
        }
        initialized = true
        refreshTimeZone(preserveOffset: !model.creatingChart)
    }

    private func refreshTimeZone(preserveOffset: Bool = false) {
        let savedOffset = input.utcOffset
        resolvedCivilFields = civilFields; resolvedAutomaticTimeZone = automaticTimeZone
        validationError = nil; timeZoneError = nil; occurrence = -1; matches = []
        guard automaticTimeZone else { return }
        guard let zone = input.timeZoneIdentifier else {
            timeZoneError = L10n.text("Сначала выберите город.", "Choose a city first."); return
        }
        do {
            matches = try CivilTimeResolver.matches(input, timeZoneIdentifier: zone)
            if matches.count == 1 { occurrence = 0; input.utcOffset = matches[0].utcOffset }
            else if preserveOffset, let i = matches.firstIndex(where: { abs($0.utcOffset - savedOffset) < 0.000001 }) { occurrence = i }
        } catch CivilTimeError.nonexistentTime {
            timeZoneError = L10n.text("Такого местного времени не было из-за перевода часов вперёд. Исправьте время или задайте UTC вручную.", "This local time did not exist because clocks moved forward. Correct the time or enter UTC manually.")
        } catch CivilTimeError.unsupportedCalendar {
            timeZoneError = L10n.text("Для дат до 1583 года задайте UTC вручную: карта использует юлианский календарь.", "For dates before 1583, enter UTC manually: the chart uses the Julian calendar.")
        } catch CivilTimeError.unknownTimeZone {
            timeZoneError = L10n.text("Этот часовой пояс отсутствует в macOS. Задайте UTC вручную.", "This time zone is unavailable in macOS. Enter UTC manually.")
        } catch {
            timeZoneError = L10n.text("Проверьте дату и время.", "Check the date and time.")
        }
    }

    private func coordinateBinding(latitude: Bool) -> Binding<Double> {
        Binding(get: { latitude ? input.latitude : input.longitude }, set: { value in
            if latitude { input.latitude = value } else { input.longitude = value }
            // A manually entered coordinate is no longer the saved atlas city.
            // Keep the last explicit UTC offset, and require a new city choice
            // before automatic zone conversion can be re-enabled.
            input.cityID = nil; input.timeZoneIdentifier = nil
            automaticTimeZone = false; matches = []; timeZoneError = nil
        })
    }

    private func apply() {
        do {
            // A number field can commit immediately before the Apply action;
            // validate against the current civil fields, never a cached match.
            if automaticTimeZone && civilFields != resolvedCivilFields { refreshTimeZone() }
            if automaticTimeZone {
                guard let match = selectedMatch, timeZoneError == nil else {
                    validationError = timeZoneError ?? L10n.text("Выберите вхождение местного времени.", "Choose the occurrence of local time.")
                    return
                }
                input.utcOffset = match.utcOffset
            }
            input.usesAutomaticTimeZone = automaticTimeZone
            try input.validate()
            let chart = SavedChart(title: title.isEmpty ? L10n.text("Без названия", "Untitled") : title, place: place, input: input)
            try model.applyChart(chart, secondary: secondary)
            dismiss()
        } catch { validationError = error.localizedDescription }
    }
}
