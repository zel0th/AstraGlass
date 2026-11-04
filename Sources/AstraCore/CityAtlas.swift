import Foundation

/// The offline GeoNames atlas shipped with Astrolog. Its longitude convention is
/// west-positive; AstraGlass stores geographic longitude east-positive.
public struct AtlasCity: Codable, Hashable, Identifiable, Sendable {
    public let name: String
    public let region: String
    public let latitude: Double
    public let longitude: Double
    public let timeZoneIdentifier: String
    public var id: String { "\(region)|\(name)|\(latitude)|\(longitude)" }
    public var regionLabel: String {
        guard region == region.lowercased() else { return region }
        let canadianProvinces: Set<String> = ["ab", "bc", "mb", "nb", "nf", "nl", "ns", "nt", "nu", "on", "pe", "qc", "sk", "yt"]
        return (canadianProvinces.contains(region) ? "CA-" : "US-") + region.uppercased()
    }
    public var label: String { "\(name) · \(regionLabel)" }
}

public final class CityAtlas: Sendable {
    public let cities: [AtlasCity]
    private let searchNames: [String]
    public static let shared = CityAtlas()

    public init(url: URL? = nil) {
        let resources = Bundle.main.resourceURL
        let candidates = [url, resources?.appendingPathComponent("Engine/atlas.as"),
                          resources?.appendingPathComponent("atlas.as")].compactMap { $0 }
        let source = candidates.lazy.compactMap { try? String(contentsOf: $0, encoding: .utf8) }.first ?? ""
        cities = Self.parse(source)
        searchNames = cities.map { Self.normalize($0.name + " " + $0.regionLabel + " " + Self.aliases[$0.name, default: ""]) }
    }

    public static func parse(_ source: String) -> [AtlasCity] {
        var zone = ""
        var result: [AtlasCity] = []
        for line in source.split(whereSeparator: \.isNewline) {
            let fields = line.split(separator: "\t", omittingEmptySubsequences: false)
            guard fields.count >= 4, let westLongitude = Double(fields[0]),
                  let latitude = Double(fields[1]), (-180...180).contains(westLongitude),
                  (-90...90).contains(latitude) else { continue }
            if fields.count >= 5, !fields[4].isEmpty { zone = String(fields[4]).trimmingCharacters(in: .whitespaces) }
            guard !zone.isEmpty else { continue }
            result.append(AtlasCity(name: String(fields[3]), region: String(fields[2]),
                                    latitude: latitude, longitude: -westLongitude, timeZoneIdentifier: zone))
        }
        return result
    }

    public func city(id: String?) -> AtlasCity? {
        guard let id else { return nil }
        return cities.first { $0.id == id }
    }

    public func search(_ query: String, limit: Int = 8) -> [AtlasCity] {
        let needle = Self.normalize(query.trimmingCharacters(in: .whitespacesAndNewlines))
        guard needle.count >= 2, limit > 0 else { return [] }
        let tokens = needle.split(separator: " ").map(String.init)
        let hits = cities.indices.filter { i in tokens.allSatisfy { searchNames[i].contains($0) } }
        let ranked = hits.sorted { a, b in
            let aExact = Self.normalize(cities[a].name) == needle || Self.normalize(Self.aliases[cities[a].name, default: ""]) == needle
            let bExact = Self.normalize(cities[b].name) == needle || Self.normalize(Self.aliases[cities[b].name, default: ""]) == needle
            if aExact != bExact { return aExact }
            let aPrefix = searchNames[a].hasPrefix(needle), bPrefix = searchNames[b].hasPrefix(needle)
            if aPrefix != bPrefix { return aPrefix }
            return cities[a].label.localizedStandardCompare(cities[b].label) == .orderedAscending
        }
        return ranked.prefix(limit).map { cities[$0] }
    }

    private static func normalize(_ value: String) -> String {
        // Keep both Cyrillic aliases and Latin atlas names searchable; case and
        // diacritics do not affect a match. Do not silently pick a same-name city.
        value.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "en_US_POSIX"))
            .replacingOccurrences(of: "ё", with: "е")
    }

    private static let aliases: [String: String] = [
        "Moscow": "Москва", "Saint Petersburg": "Санкт-Петербург Петербург Санкт Петербург",
        "Helsinki": "Хельсинки", "Greenwich": "Гринвич", "New York City": "Нью-Йорк Нью Йорк",
        "London": "Лондон", "Paris": "Париж", "Berlin": "Берлин", "Rome": "Рим",
        "Belgrade": "Белград", "Novi Sad": "Нови-Сад Нови Сад", "Dubai": "Дубай",
        "Kiev": "Киев Київ", "Kyiv": "Киев Київ", "Minsk": "Минск",
        "Tallinn": "Таллин Таллинн", "Riga": "Рига", "Vilnius": "Вильнюс",
        "Yekaterinburg": "Екатеринбург", "Novosibirsk": "Новосибирск", "Kazan": "Казань",
        "Nizhniy Novgorod": "Нижний Новгород", "Samara": "Самара", "Omsk": "Омск",
        "Rostov-na-Donu": "Ростов-на-Дону Ростов на Дону", "Rostov-on-Don": "Ростов-на-Дону Ростов на Дону",
        "Krasnodar": "Краснодар", "Sochi": "Сочи", "Vladivostok": "Владивосток",
        "Irkutsk": "Иркутск", "Krasnoyarsk": "Красноярск", "Kaliningrad": "Калининград",
        "Chelyabinsk": "Челябинск", "Ufa": "Уфа", "Perm": "Пермь", "Voronezh": "Воронеж",
        "Volgograd": "Волгоград", "Saratov": "Саратов", "Yaroslavl": "Ярославль",
        "Tbilisi": "Тбилиси", "Yerevan": "Ереван", "Baku": "Баку", "Almaty": "Алматы",
        "Astana": "Астана", "Tashkent": "Ташкент", "Bishkek": "Бишкек", "Istanbul": "Стамбул"
    ]
}

public struct CivilTimeMatch: Equatable, Sendable {
    public let date: Date
    public let utcOffset: Double
    public let isDaylightSavingTime: Bool
    public let abbreviation: String
    public var offsetLabel: String {
        let total = Int((abs(utcOffset) * 3600).rounded())
        let main = String(format: "UTC%@%02d:%02d", utcOffset < 0 ? "−" : "+", total / 3600, (total % 3600) / 60)
        return total % 60 == 0 ? main : main + String(format: ":%02d", total % 60)
    }
}

public enum CivilTimeError: Error, Sendable {
    case invalidDate, unsupportedCalendar, unknownTimeZone, nonexistentTime
}

public enum CivilTimeResolver {
    /// Returns every instant matching a local wall clock. Two results mean the
    /// clock was set back; zero is reported as a gap, never silently shifted.
    /// Gregorian dates from 1583 match ChartInput's calendar convention.
    public static func matches(_ input: ChartInput, timeZoneIdentifier: String) throws -> [CivilTimeMatch] {
        guard input.year >= 1583 else { throw CivilTimeError.unsupportedCalendar }
        guard let zone = TimeZone(identifier: timeZoneIdentifier) else { throw CivilTimeError.unknownTimeZone }
        guard (1...12).contains(input.month), (1...31).contains(input.day),
              (0...23).contains(input.hour), (0...59).contains(input.minute) else { throw CivilTimeError.invalidDate }
        var utcCalendar = Calendar(identifier: .gregorian)
        utcCalendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let components = DateComponents(year: input.year, month: input.month, day: input.day, hour: input.hour, minute: input.minute, second: 0)
        guard let wall = utcCalendar.date(from: components), sameCivilTime(wall, input: input, calendar: utcCalendar) else { throw CivilTimeError.invalidDate }
        var localCalendar = Calendar(identifier: .gregorian)
        localCalendar.timeZone = zone
        // Both sides of DST, date-line and historical offset transitions fall
        // within this four-day window. Every offset is validated by roundtrip.
        let offsets = Set(stride(from: -48, through: 48, by: 3).map { zone.secondsFromGMT(for: wall.addingTimeInterval(Double($0) * 3600)) })
        let results = offsets.compactMap { offset -> CivilTimeMatch? in
            let candidate = wall.addingTimeInterval(-Double(offset))
            guard zone.secondsFromGMT(for: candidate) == offset,
                  sameCivilTime(candidate, input: input, calendar: localCalendar) else { return nil }
            return CivilTimeMatch(date: candidate, utcOffset: Double(offset) / 3600,
                                  isDaylightSavingTime: zone.isDaylightSavingTime(for: candidate),
                                  abbreviation: zone.abbreviation(for: candidate) ?? timeZoneIdentifier)
        }.sorted { $0.date < $1.date }
        guard !results.isEmpty else { throw CivilTimeError.nonexistentTime }
        return results
    }

    private static func sameCivilTime(_ date: Date, input: ChartInput, calendar: Calendar) -> Bool {
        let c = calendar.dateComponents([.era, .year, .month, .day, .hour, .minute, .second], from: date)
        return c.era == 1 && c.year == input.year && c.month == input.month && c.day == input.day &&
            c.hour == input.hour && c.minute == input.minute && c.second == 0
    }
}
