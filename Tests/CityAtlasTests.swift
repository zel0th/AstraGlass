import Foundation

@main
struct CityAtlasTests {
    static func require(_ condition: @autoclosure () -> Bool, _ message: String) throws {
        if !condition() { throw NSError(domain: "CityAtlasTests", code: 1, userInfo: [NSLocalizedDescriptionKey: message]) }
    }
    static func offset(_ year: Int, _ month: Int, _ day: Int, _ hour: Int = 12, _ minute: Int = 0,
                       zone: String) throws -> [CivilTimeMatch] {
        try CivilTimeResolver.matches(ChartInput(year: year, month: month, day: day, hour: hour, minute: minute), timeZoneIdentifier: zone)
    }
    static func main() throws {
        let root = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : FileManager.default.currentDirectoryPath
        let atlas = CityAtlas(url: URL(fileURLWithPath: root).appendingPathComponent("Upstream/Astrolog/atlas.as"))
        try require(atlas.cities.count == 33702, "Expected complete bundled atlas")
        let moscow = atlas.search("Москва").first { $0.region == "RU" }
        try require(moscow?.name == "Moscow", "Russian Moscow alias")
        try require(moscow?.timeZoneIdentifier == "Europe/Moscow", "Inherited time zone")
        try require(abs((moscow?.longitude ?? 0) - 37.6178) < 0.00001, "West-positive atlas converted to east-positive")
        try require(atlas.search("mOsCoW").contains { $0.region == "RU" }, "Case insensitive search")
        try require(atlas.search("Москва RU").first?.region == "RU", "City and country tokens")
        try require(atlas.search("").isEmpty, "Empty search is bounded")
        try require(atlas.search("Moscow").first { $0.region == "id" }?.regionLabel == "US-ID", "US state distinguishes same-name cities")
        try require(atlas.search("Petersburg", limit: 2).count <= 2, "Search result limit")
        try require(atlas.city(id: moscow?.id) == moscow, "Stable city identity")
        let parsed = CityAtlas.parse("; comment\n-YY 2\n-1.5\t42.5\tAD\tAndorra\tEurope/Andorra\n-1.6\t42.6\tAD\tOther\n")
        try require(parsed.count == 2 && parsed[1].timeZoneIdentifier == "Europe/Andorra", "Parser timezone continuation")
        let nyWinter = try offset(2020, 1, 1, zone: "America/New_York").first!
        let nySummer = try offset(2020, 7, 1, zone: "America/New_York").first!
        try require(nyWinter.utcOffset == -5 && !nyWinter.isDaylightSavingTime, "NY standard time")
        try require(nySummer.utcOffset == -4 && nySummer.isDaylightSavingTime, "NY daylight time")
        let oldMoscowWinter = try offset(2010, 1, 1, zone: "Europe/Moscow").first!
        let oldMoscowSummer = try offset(2010, 7, 1, zone: "Europe/Moscow").first!
        try require(oldMoscowWinter.utcOffset == 3 && oldMoscowSummer.utcOffset == 4, "Moscow historical seasonal change")
        let moscow2012 = try offset(2012, 1, 1, zone: "Europe/Moscow").first!
        try require(moscow2012.utcOffset == 4, "Moscow 2012 permanent UTC+4")
        let modernMoscow = try offset(2020, 7, 1, zone: "Europe/Moscow").first!
        try require(modernMoscow.utcOffset == 3, "Moscow modern UTC+3")
        let fold = try offset(2020, 11, 1, 1, 30, zone: "America/New_York")
        try require(fold.count == 2 && fold.map(\.utcOffset) == [-4, -5], "Fall-back exposes both occurrences")
        try require(fold[1].date.timeIntervalSince(fold[0].date) == 3600, "Fold instant separation")
        do { _ = try offset(2020, 3, 8, 2, 30, zone: "America/New_York"); throw NSError(domain: "Gap accepted", code: 1) }
        catch CivilTimeError.nonexistentTime { }
        do { _ = try offset(2011, 12, 30, zone: "Pacific/Apia"); throw NSError(domain: "Skipped date accepted", code: 1) }
        catch CivilTimeError.nonexistentTime { }
        do { _ = try offset(2021, 2, 29, zone: "Europe/Moscow"); throw NSError(domain: "Invalid date accepted", code: 1) }
        catch CivilTimeError.invalidDate { }
        do { _ = try offset(1500, 1, 1, zone: "Europe/Moscow"); throw NSError(domain: "Julian date accepted", code: 1) }
        catch CivilTimeError.unsupportedCalendar { }
        do { _ = try offset(2020, 1, 1, zone: "No/SuchZone"); throw NSError(domain: "Unknown zone accepted", code: 1) }
        catch CivilTimeError.unknownTimeZone { }
        let savedFold = ChartInput(year: 2020, month: 11, day: 1, hour: 1, minute: 30,
                                   utcOffset: -5, timeZoneIdentifier: "America/New_York",
                                   cityID: "test-new-york", usesAutomaticTimeZone: true)
        let restored = try JSONDecoder().decode(ChartInput.self, from: JSONEncoder().encode(savedFold))
        let restoredMatches = try CivilTimeResolver.matches(restored, timeZoneIdentifier: restored.timeZoneIdentifier!)
        try require(restored.usesAutomaticTimeZone == true && restoredMatches.firstIndex { $0.utcOffset == restored.utcOffset } == 1,
                    "Saved fold preserves explicitly chosen second occurrence")
        let oldJSON = "{\"year\":2000,\"month\":1,\"day\":1,\"hour\":12,\"minute\":0,\"utcOffset\":3,\"longitude\":37.6173,\"latitude\":55.7558,\"houseSystem\":0,\"sidereal\":false}"
        let legacy = try JSONDecoder().decode(ChartInput.self, from: Data(oldJSON.utf8))
        try require(legacy.timeZoneIdentifier == nil && legacy.cityID == nil && legacy.usesAutomaticTimeZone == nil,
                    "Older charts remain manual and decode without location metadata")
        let kathmandu = try offset(2020, 1, 1, zone: "Asia/Kathmandu").first!
        try require(kathmandu.utcOffset == 5.75 && kathmandu.offsetLabel == "UTC+05:45", "Quarter-hour offset")
        let oldMoscow = try offset(1900, 1, 1, zone: "Europe/Moscow").first!
        try require(abs(oldMoscow.utcOffset * 3600 - 9017) < 0.001, "Historical second-level offset retained")
        print("{\"suite\":\"city-atlas\",\"passed\":27,\"atlasCities\":\(atlas.cities.count)}")
    }
}
