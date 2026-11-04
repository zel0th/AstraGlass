import Foundation
#if canImport(AppKit)
import AppKit
#endif

private struct TestFailure: Error, CustomStringConvertible { let description: String }
private func require(_ condition: @autoclosure () -> Bool, _ message: String) throws {
    if !condition() { throw TestFailure(description: message) }
}
private func distance(_ a: Double, _ b: Double) -> Double {
    let delta = abs(a - b).truncatingRemainder(dividingBy: 360)
    return min(delta, 360 - delta)
}

@main struct CoreTests {
    static func main() async {
        do {
            let args = Array(CommandLine.arguments.dropFirst())
            let root = URL(fileURLWithPath: args.last ?? FileManager.default.currentDirectoryPath)
            let engine = AstrologEngine(executableURL: root.appendingPathComponent("Engine/bin/astrolog"), resourceURL: root.appendingPathComponent("Upstream/Astrolog"))
            if args.first == "--benchmark" {
                try await benchmark(engine, count: Int(args.dropFirst().first ?? "100") ?? 100)
            } else {
                try await tests(engine, root: root)
            }
        } catch {
            FileHandle.standardError.write(Data("FAIL: \(error)\n".utf8))
            exit(1)
        }
    }

    static func tests(_ engine: AstrologEngine, root: URL) async throws {
        var checks = [String]()
        func checked(_ message: String) {
            checks.append(message)
            FileHandle.standardError.write(Data(("PASS: " + message + "\n").utf8))
        }
        FileHandle.standardError.write(Data("START: core validation\n".utf8))
        let j2000 = ChartInput(year: 2000, month: 1, day: 1, hour: 12, utcOffset: 0, longitude: 0, latitude: 0)
        let chart = try await engine.calculate(j2000)
        try require(abs(chart.julianDay - 2451545.0) < 1e-8, "J2000 Julian day must be 2451545.0")
        checked("J2000 Julian day")
        try invariants(chart)
        try require(Set(chart.positions.map(\.id)).isSuperset(of: Set(1...10)), "Ten principal planets must be present")
        checked("Finite positions, unique IDs, twelve house cusps, valid ranges")

        let defaultSelection = try await engine.calculate(j2000, preferences: .defaults)
        try require(Set(defaultSelection.positions.map(\.id)) == ChartPreferences.defaults.enabledObjects,
                    "Default selection must include both lunar nodes and ten planets")
        if let north = defaultSelection.positions.first(where: { $0.id == 16 }),
           let southNode = defaultSelection.positions.first(where: { $0.id == 17 }) {
            try require(abs(distance(north.longitude, southNode.longitude) - 180) < 1e-6, "Lunar nodes must oppose each other")
        }
        var selected = ChartPreferences(enabledObjects: [1, 2, 16, 17, 74], enabledAspects: Set(1...24))
        let extraObjects = try await engine.calculate(j2000, preferences: selected)
        try require(Set(extraObjects.positions.map(\.id)).isSubset(of: selected.enabledObjects), "Deselected planets leaked into result")
        try invariants(extraObjects)
        try require(extraObjects.positions.contains { $0.id == 74 } || extraObjects.unavailableObjects.contains(74), "Charon must be calculated or explicitly unavailable")
        for kind in 1...24 {
            selected = ChartPreferences(enabledObjects: Set(1...10), enabledAspects: [kind])
            let singleKind = try await engine.calculate(j2000, preferences: selected)
            try require(singleKind.aspects.allSatisfy { $0.kind == kind }, "Disabled aspect kind leaked into chart")
        }
        let noAspects = try await engine.calculate(j2000, preferences: ChartPreferences(enabledAspects: []))
        try require(noAspects.aspects.isEmpty, "All aspects can be disabled")
        let noObjects = try await engine.calculate(j2000, preferences: ChartPreferences(enabledObjects: [], enabledAspects: []))
        try require(noObjects.positions.isEmpty && noObjects.aspects.isEmpty && noObjects.houseCusps.count == 12,
                    "Empty object selection retains houses without invented objects")
        checked("Object choices, both nodes, honest Charon availability, and each of 24 aspect switches")

        let selectedReport = try await engine.relationship(j2000, secondary: j2000, preferences: .defaults)
        try require(selectedReport.count > 50, "Synastry must use the configured engine and selected objects")
        checked("Synastry runs through the same explicitly supplied executable")

        let comparisonDate = ChartInput(year: 1985, month: 1, day: 26, hour: 11, minute: 30, utcOffset: 3, longitude: 30.3, latitude: 59.9)
        for transit in [false, true] {
            let comparison = try await engine.comparison(j2000, secondary: comparisonDate, transit: transit)
            let primary = try await engine.calculate(j2000, preferences: .defaults)
            let second = try await engine.calculate(comparisonDate, preferences: .defaults)
            try require(comparison.primary.positions == primary.positions && comparison.secondary.positions == second.positions, "Biwheel must retain both real charts")
            try require(comparison.primary.houseCusps == primary.houseCusps && comparison.transit == transit && !comparison.aspects.isEmpty, "Comparison must retain primary houses and its mode")
            for aspect in comparison.aspects {
                let first = primary.positions.first { $0.id == aspect.first }!
                let other = second.positions.first { $0.id == aspect.second }!
                try require(abs(abs(distance(first.longitude, other.longitude) - aspect.angle) - abs(aspect.orb)) < 1e-6, "Cross-grid axes or orbital separation are incorrect")
            }
            let selfComparison = try await engine.comparison(j2000, secondary: j2000, transit: transit)
            for id in 1...10 {
                try require(selfComparison.aspects.contains { $0.first == id && $0.second == id && $0.kind == 1 && abs($0.orb) < 1e-7 }, "Same-object conjunctions must survive comparison serialization")
            }
            for aspect in primary.aspects {
                try require(selfComparison.aspects.contains { $0.first == aspect.first && $0.second == aspect.second && $0.kind == aspect.kind && abs(abs($0.orb) - abs(aspect.orb)) < 1e-7 }, "Relationship grid must preserve Astrolog's object-specific orbs")
            }
            let restricted = try await engine.comparison(j2000, secondary: comparisonDate, transit: transit, preferences: ChartPreferences(enabledObjects: [1, 2], enabledAspects: [2]))
            try require(restricted.primary.positions.count == 2 && restricted.secondary.positions.count == 2 && restricted.aspects.allSatisfy { $0.kind == 2 && [1, 2].contains($0.first) && [1, 2].contains($0.second) }, "Comparison must honor enabled bodies and aspects")
            let empty = try await engine.comparison(j2000, secondary: comparisonDate, transit: transit, preferences: ChartPreferences(enabledObjects: [], enabledAspects: []))
            try require(empty.primary.positions.isEmpty && empty.secondary.positions.isEmpty && empty.aspects.isEmpty, "Empty selections must stay empty in comparisons")
        }
        checked("Native synastry/transit grids: both real charts, directed cross-aspects, same-object conjunctions, exact engine orbs and preference filters")

        // Read the original Astrolog textual output, independently parse its DMS
        // positions, and compare the adapter's full precision JSON to that display.
        let report = try await engine.report(j2000, options: ["-v"])
        let names = [1: "Sun", 2: "Moon", 3: "Merc", 4: "Venu", 5: "Mars", 6: "Jupi", 7: "Satu", 8: "Uran", 9: "Nept", 10: "Plut"]
        let signs = ["Ari", "Tau", "Gem", "Can", "Leo", "Vir", "Lib", "Sco", "Sag", "Cap", "Aqu", "Pis"]
        for planet in chart.positions.filter({ (1...10).contains($0.id) }) {
            let regex = try NSRegularExpression(pattern: "(?m)^" + names[planet.id]! + "\\s*:\\s*(\\d{1,2})([A-Za-z]{3})(\\d{2})")
            let text = report as NSString
            guard let match = regex.firstMatch(in: report, range: NSRange(location: 0, length: text.length)), let sign = signs.firstIndex(of: text.substring(with: match.range(at: 2))), let deg = Double(text.substring(with: match.range(at: 1))), let minute = Double(text.substring(with: match.range(at: 3))) else {
                throw TestFailure(description: "Original CLI position missing for \(planet.id)")
            }
            let printed = Double(sign * 30) + deg + minute / 60
            try require(distance(printed, planet.longitude) <= 1.0 / 60 + 1e-7, "JSON differs from original CLI for \(planet.id)")
        }
        checked("All ten principal planets match original Astrolog CLI within its one-arcminute display precision")

        var moscow = j2000; moscow.hour = 15; moscow.utcOffset = 3
        var india = j2000; india.hour = 17; india.minute = 30; india.utcOffset = 5.5
        var previousDay = j2000; previousDay.day = 2; previousDay.hour = 2; previousDay.utcOffset = 14
        for input in [moscow, india, previousDay] {
            let equivalent = try await engine.calculate(input)
            try require(abs(equivalent.julianDay - chart.julianDay) < 1e-8, "UTC offset sign, fraction, or day rollover mismatch")
            for planet in chart.positions {
                guard let twin = equivalent.positions.first(where: { $0.id == planet.id }) else { throw TestFailure(description: "UTC comparison missing object") }
                try require(distance(planet.longitude, twin.longitude) < 1e-7, "Equivalent civil times must give same longitude")
            }
        }
        checked("UTC offsets +03:00, +05:30, and +14:00 across midnight give identical chart")

        var south = ChartInput(year: 1987, month: 6, day: 19, hour: 21, minute: 17, utcOffset: -3, longitude: -56.1645, latitude: -34.9011)
        for system in [0, 1, 2, 3, 4, 8, 13] {
            south.houseSystem = system
            try invariants(try await engine.calculate(south))
        }
        checked("Seven house systems at southern latitude")

        let byID = Dictionary(uniqueKeysWithValues: chart.positions.map { ($0.id, $0) })
        for aspect in chart.aspects {
            guard let first = byID[aspect.first], let second = byID[aspect.second] else { throw TestFailure(description: "Aspect references missing object") }
            let deviation = abs(distance(first.longitude, second.longitude) - aspect.angle)
            try require(abs(deviation - abs(aspect.orb)) < 1e-6, "Aspect orb must equal independent angular separation residual")
        }
        checked("Aspect separation and orb checked independently for every returned aspect")

        var sidereal = j2000; sidereal.sidereal = true
        let siderealChart = try await engine.calculate(sidereal)
        guard let sun = chart.positions.first(where: { $0.id == 1 }), let siderealSun = siderealChart.positions.first(where: { $0.id == 1 }) else { throw TestFailure(description: "Missing Sun") }
        try require(distance(sun.longitude, siderealSun.longitude) > 15 && distance(sun.longitude, siderealSun.longitude) < 30, "Sidereal mode must actually shift longitude")
        checked("Sidereal mode changes longitude")

        let leap = ChartInput(year: 2000, month: 2, day: 29, hour: 12, utcOffset: 0)
        try invariants(try await engine.calculate(leap))
        var invalid = j2000; invalid.latitude = 90
        do { _ = try await engine.calculate(invalid); throw TestFailure(description: "Invalid latitude accepted") }
        catch is AstrologError { }
        invalid = j2000; invalid.month = 13
        do { _ = try await engine.calculate(invalid); throw TestFailure(description: "Invalid month accepted") }
        catch is AstrologError { }
        invalid = j2000; invalid.utcOffset = .nan
        do { _ = try await engine.calculate(invalid); throw TestFailure(description: "Nonfinite UTC offset accepted") }
        catch is AstrologError { }
        invalid = j2000; invalid.month = 2; invalid.day = 31
        do { _ = try await engine.calculate(invalid); throw TestFailure(description: "Impossible calendar date accepted") }
        catch is AstrologError { }
        checked("Leap date and rejection of invalid date, month, latitude, and nonfinite offset")

        for flags in [["-o", "/tmp/unsafe-write"], ["-i", "/tmp/unsafe-input"], ["~", "1"], ["-Xb"],
                      [":i", "/tmp/unsafe-input"], ["i", "/tmp/unsafe-input"], ["Xb"],
                      ["-rc0", "/tmp/unsafe-input", "nul", "1", "1"],
                      ["-rp0", "nul", "/tmp/unsafe-input"]] {
            do { _ = try await engine.run(arguments: flags); throw TestFailure(description: "Unsafe report arguments accepted") }
            catch AstrologError.unsafeArguments { }
        }
        checked("Report editor rejects file/script and graphics switches including alternate prefixes and relationship variants")

        // A short-lived child can finish between polling intervals. Its total
        // output still has to obey the same cap before the host reads it.
        let fixtureFolder = FileManager.default.temporaryDirectory.appendingPathComponent("AstraGlass-limit-tests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: fixtureFolder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: fixtureFolder) }
        let fixtureExecutable = fixtureFolder.appendingPathComponent("oversized-output")
        try Data("#!/bin/sh\n/usr/bin/head -c 17825792 /dev/zero\n".utf8).write(to: fixtureExecutable)
        try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: fixtureExecutable.path)
        let oversizedEngine = AstrologEngine(executableURL: fixtureExecutable, resourceURL: fixtureFolder)
        do { _ = try await oversizedEngine.run(arguments: []); throw TestFailure(description: "Oversized completed output accepted") }
        catch AstrologError.excessiveOutput { }
        checked("Output limit also applies to a child that exits between polling intervals")

        for options in [["-a"], ["-g"], ["-m"], ["-H"]] {
            let text = try await engine.report(j2000, options: options)
            try require(text.count > 50, "Empty report for \(options)")
        }
        checked("Aspect, grid, midpoint, and help reports execute")

        for preset in GraphicPreset.allCases {
            let data = try await engine.renderGraphic(j2000, kind: preset, secondary: south, width: 600, height: 500)
            #if canImport(AppKit)
            guard let bitmap = NSBitmapImageRep(data: data) else { throw TestFailure(description: "Undecodable graphics for \(preset.rawValue)") }
            try require(bitmap.pixelsWide > 0 && bitmap.pixelsHigh > 0 && data.count > 1000, "Empty graphics for \(preset.rawValue)")
            #else
            try require(data.count > 1000 && data.prefix(2) == Data([0x42, 0x4d]), "Invalid bitmap signature for \(preset.rawValue)")
            func bitmapInteger(_ offset: Int) -> Int32 {
                let bytes = [UInt8](data[offset..<(offset + 4)])
                let value = UInt32(bytes[0]) | UInt32(bytes[1]) << 8 | UInt32(bytes[2]) << 16 | UInt32(bytes[3]) << 24
                return Int32(bitPattern: value)
            }
            try require(bitmapInteger(18) > 0 && bitmapInteger(22) != 0, "Invalid bitmap dimensions for \(preset.rawValue)")
            #endif
        }
        #if canImport(AppKit)
        checked("All eleven Astrolog graphics presets produce decodable nonempty bitmaps")
        #else
        checked("All eleven Astrolog graphics presets produce nonempty bitmaps with valid headers; AppKit decoding not tested on Linux")
        #endif

        async let firstConcurrent = engine.calculate(j2000)
        let southernInput = south
        async let secondConcurrent = engine.calculate(southernInput)
        let concurrent = try await (firstConcurrent, secondConcurrent)
        try require(abs(concurrent.0.julianDay - chart.julianDay) < 1e-8, "Concurrent calculations shared mutable engine state")
        try require(abs(concurrent.1.julianDay - chart.julianDay) > 1, "Concurrent different chart contaminated")
        checked("Concurrent requests remain isolated")

        let corpusURL = root.appendingPathComponent("Resources/interpretations.json")
        if FileManager.default.fileExists(atPath: corpusURL.path) {
            let library = try InterpretationLibrary(url: corpusURL)
            let sourceIDs = Set(library.sources.map(\.fileName))
            try require(!library.records.isEmpty && library.sources.count == 4, "Expected four source books")
            try require(library.records.allSatisfy { !$0.body.isEmpty && sourceIDs.contains($0.source) && $0.paragraphStart <= $0.paragraphEnd && $0.sourceSHA256.count == 64 }, "Corpus record missing body or verifiable provenance")
            for sign in 0..<12 {
                try require(!library.forSign(index: sign).isEmpty, "Missing zodiac sign \(sign)")
                for planet in 1...10 {
                    try require(library.forPlanet(id: planet, sign: sign, house: 1).contains { $0.bindings.contains("planet-sign:\(planet):\(sign)") }, "Missing planet-sign interpretation")
                }
                for house in 1...12 {
                    try require(library.forHouse(number: house, sign: sign).contains { $0.bindings.contains("house-sign:\(house):\(sign)") }, "Missing house-sign interpretation")
                }
            }
            checked("Source provenance and complete principal planet/sign and house/sign corpus bindings")
            let upper = library.search("СОЛНЦЕ").map(\.id)
            try require(!upper.isEmpty && upper == library.search("солнце").map(\.id), "Cyrillic search must ignore case")
            let forward = Set(library.forAspect(first: 1, second: 2, angle: 90).map(\.id))
            let reverse = Set(library.forAspect(first: 2, second: 1, angle: 90).map(\.id))
            try require(!forward.isEmpty && forward == reverse, "Aspect passages must be symmetric in endpoint order")
            checked("Cyrillic case-insensitive search and aspect endpoint lookup symmetry")
        }

        let languageFolder = FileManager.default.temporaryDirectory.appendingPathComponent("AstraGlass-language-" + UUID().uuidString)
        try FileManager.default.createDirectory(at: languageFolder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: languageFolder) }
        let fixtureURL = languageFolder.appendingPathComponent("fixture.json")
        let source: [String: Any] = ["id":"fixture", "fileName":"fixture.txt", "title":"Проверка языка", "sha256":String(repeating:"0",count:64), "sectionCount":2]
        let russian: [String: Any] = ["id":"ru", "title":"Русская трактовка", "originalTitle":"Русская трактовка", "category":"Аспекты",
            "body":"Авторский русский текст сохраняется без изменений. Ссылка на объект ASC допустима.",
            "source":"fixture.txt", "sourceTitle":"Проверка языка", "sourceSHA256":String(repeating:"0",count:64),
            "paragraphStart":1,"paragraphEnd":2,"headingLevel":1,"breadcrumbs":[],"keywords":[],
            "planetIDs":[2,7],"signIndices":[],"houseNumbers":[],"aspectAngle":180,
            "bindings":["aspect-pair:180:2:7","planet-sign:1:9","house-sign:1:0","sign:0"]]
        var english = russian; english["id"] = "en"; english["title"] = "Moon Opposition Saturn"
        english["body"] = "ForeignOnlyPhrase. Your approach to discipline and responsibilities is described here."
        func writeLanguageFixture(_ records: [[String: Any]]) throws {
            try JSONSerialization.data(withJSONObject: ["schemaVersion":1,"sources":[source],"records":records]).write(to: fixtureURL)
        }
        try writeLanguageFixture([russian, english])
        let russianLibrary = try InterpretationLibrary(url: fixtureURL)
        try require(russianLibrary.records.map(\.id) == ["ru"] && russianLibrary.sources[0].sectionCount == 1,
                    "Only Russian records and their source counts are exposed")
        try require(russianLibrary.records[0].body == russian["body"] as? String, "Do not rewrite author text")
        try require(russianLibrary.search("ForeignOnlyPhrase").isEmpty && russianLibrary.search("русский").count == 1,
                    "English interpretations must not appear in library search")
        try require(russianLibrary.forAspect(first:2,second:7,angle:180).map(\.id) == ["ru"]
                    && russianLibrary.forPlanet(id:1,sign:9,house:1).map(\.id) == ["ru"]
                    && russianLibrary.forSign(index:0).map(\.id) == ["ru"]
                    && russianLibrary.forHouse(number:1,sign:0).map(\.id) == ["ru"],
                    "Every chart/PDF lookup uses the same Russian-only library")
        try writeLanguageFixture([english])
        do { _ = try InterpretationLibrary(url: fixtureURL); throw TestFailure(description: "English-only corpus must not import") }
        catch InterpretationError.invalidCorpus { }
        checked("Russian-only interpretations, all lookup paths, search and rejection of English-only imports")

        let output: [String: Any] = ["passed": checks.count, "failed": 0, "checks": checks, "engine": chart.engine, "platform": ProcessInfo.processInfo.operatingSystemVersionString, "timestamp": ISO8601DateFormatter().string(from: Date())]
        print(String(decoding: try JSONSerialization.data(withJSONObject: output, options: [.prettyPrinted, .sortedKeys]), as: UTF8.self))
    }

    static func invariants(_ chart: ChartSnapshot) throws {
        try require(chart.julianDay.isFinite, "Nonfinite Julian day")
        try require(chart.houseCusps.count == 12, "Expected twelve cusps")
        try require(chart.houseCusps.allSatisfy { $0.isFinite && $0 >= 0 && $0 < 360 }, "Cusp range invalid")
        try require(Set(chart.positions.map(\.id)).count == chart.positions.count, "Duplicate object ID")
        let unavailable = Set(chart.unavailableObjects)
        try require(unavailable.isDisjoint(with: Set(chart.positions.map(\.id))), "Unavailable ephemeris objects must not appear as invented zero-degree positions")
        try require(chart.aspects.allSatisfy { !unavailable.contains($0.first) && !unavailable.contains($0.second) }, "Unavailable objects must not generate false aspects")
        for planet in chart.positions {
            try require(planet.longitude.isFinite && (0..<360).contains(planet.longitude), "Longitude range invalid")
            try require(planet.latitude.isFinite && (-90...90).contains(planet.latitude), "Latitude range invalid")
            try require(planet.speed.isFinite && (1...12).contains(planet.house), "Speed or house invalid")
        }
        try require(Set(chart.aspects.map(\.id)).count == chart.aspects.count, "Duplicate aspect ID")
    }

    static func benchmark(_ engine: AstrologEngine, count: Int) async throws {
        try require(count > 0 && count <= 10000, "Benchmark count outside range")
        var milliseconds = [Double]()
        var checksum = 0.0
        let fullStart = DispatchTime.now().uptimeNanoseconds
        for index in 0..<count {
            let input = ChartInput(year: 1970 + index % 56, month: 1 + index % 12, day: 1 + index % 28, hour: index % 24, minute: index % 60, utcOffset: Double(index % 24 - 11), longitude: 37.6173, latitude: 55.7558)
            let start = DispatchTime.now().uptimeNanoseconds
            let chart = try await engine.calculate(input)
            milliseconds.append(Double(DispatchTime.now().uptimeNanoseconds - start) / 1_000_000)
            checksum += chart.positions.first(where: { $0.id == 1 })?.longitude ?? 0
        }
        let total = Double(DispatchTime.now().uptimeNanoseconds - fullStart) / 1_000_000_000
        let sorted = milliseconds.sorted()
        let output: [String: Any] = ["requests": count, "wall_seconds": total, "mean_ms": milliseconds.reduce(0, +) / Double(count), "median_ms": sorted[count / 2], "p95_ms": sorted[min(count - 1, Int(Double(count) * 0.95))], "max_ms": sorted.last!, "checksum": checksum, "scenario": "100 serial Swift adapter calculations; fresh Astrolog process per chart; varying dates and time zones"]
        print(String(decoding: try JSONSerialization.data(withJSONObject: output, options: [.prettyPrinted, .sortedKeys]), as: UTF8.self))
    }
}
