import Foundation
#if canImport(Darwin)
import Darwin
#else
import Glibc
#endif

public struct ChartInput: Codable, Hashable, Sendable {
    public var year: Int
    public var month: Int
    public var day: Int
    public var hour: Int
    public var minute: Int
    /// Local civil time minus UTC, including the daylight-saving offset.
    public var utcOffset: Double
    /// Geographic longitude, east positive, in decimal degrees.
    public var longitude: Double
    public var latitude: Double
    public var houseSystem: Int
    public var sidereal: Bool
    public var timeZoneIdentifier: String?
    public var cityID: String?
    public var usesAutomaticTimeZone: Bool?

    public init(year: Int = 2000, month: Int = 1, day: Int = 1, hour: Int = 12,
                minute: Int = 0, utcOffset: Double = 3, longitude: Double = 37.6173,
                latitude: Double = 55.7558, houseSystem: Int = 0, sidereal: Bool = false,
                timeZoneIdentifier: String? = nil, cityID: String? = nil, usesAutomaticTimeZone: Bool? = nil) {
        self.year = year; self.month = month; self.day = day; self.hour = hour
        self.minute = minute; self.utcOffset = utcOffset; self.longitude = longitude
        self.latitude = latitude; self.houseSystem = houseSystem; self.sidereal = sidereal
        self.timeZoneIdentifier = timeZoneIdentifier; self.cityID = cityID
        self.usesAutomaticTimeZone = usesAutomaticTimeZone
    }

    public var arguments: [String] {
        var result = ["-qb", String(month), String(day), String(year), String(format: "%02d:%02d", hour, minute),
                      "0", String(-utcOffset), String(-longitude), String(latitude), "-c", String(houseSystem), "=b", "_k", "_k0"]
        result.append(sidereal ? "=s" : "_s")
        return result
    }

    public func validate() throws {
        guard (-3000...3000).contains(year), (1...12).contains(month), (1...31).contains(day),
              (0...23).contains(hour), (0...59).contains(minute),
              utcOffset.isFinite, (-14...14).contains(utcOffset), longitude.isFinite,
              (-180...180).contains(longitude), latitude.isFinite, (-89.999...89.999).contains(latitude),
              (0...39).contains(houseSystem) else { throw AstrologError.invalidInput }
        let leap = year % 4 == 0 && (year <= 1582 || year % 100 != 0 || year % 400 == 0)
        let days = [31, leap ? 29 : 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31]
        guard day <= days[month - 1] else { throw AstrologError.invalidInput }
    }
}

public struct PlanetPosition: Codable, Hashable, Identifiable, Sendable {
    public let id: Int
    public let longitude: Double
    public let latitude: Double
    /// Ecliptic longitude velocity, degrees per day; negative is retrograde.
    public let speed: Double
    public let house: Int
    public var sign: Int { min(11, max(0, Int(longitude / 30))) }
    public var degreeInSign: Double { longitude.truncatingRemainder(dividingBy: 30) }
    public var isRetrograde: Bool { speed < 0 }
}

public struct ChartAspect: Codable, Hashable, Identifiable, Sendable {
    public let first: Int
    public let second: Int
    public let kind: Int
    public let angle: Double
    public let orb: Double
    public var id: String { "\(first)-\(second)-\(kind)" }
}

public struct ChartSnapshot: Codable, Sendable {
    public let engine: String
    public let julianDay: Double
    public let positions: [PlanetPosition]
    /// Twelve cusps, house 1 at index 0, in ecliptic degrees.
    public let houseCusps: [Double]
    public let aspects: [ChartAspect]
    public let unavailableObjects: [Int]
    public var rawReport: String?
}

public enum GraphicPreset: String, CaseIterable, Identifiable, Sendable {
    case natal, biwheel, composite, aspectGrid, astrocartography, sphere
    case horizon, orbit, globe, ephemeris, calendar
    public var id: String { rawValue }
    public var title: String {
        switch self {
        case .natal: L10n.text("Натальная карта")
        case .biwheel: L10n.text("Двойная карта")
        case .composite: L10n.text("Композит")
        case .aspectGrid: L10n.text("Матрица аспектов")
        case .astrocartography: L10n.text("Астрокартография")
        case .sphere: L10n.text("Небесная сфера")
        case .horizon: L10n.text("Местный горизонт")
        case .orbit: L10n.text("Орбиты планет")
        case .globe: L10n.text("Земной глобус")
        case .ephemeris: L10n.text("График эфемерид")
        case .calendar: L10n.text("Календарь")
        }
    }
    public var needsSecondary: Bool { self == .biwheel || self == .composite }
    fileprivate var arguments: [String] {
        switch self {
        case .natal, .biwheel, .composite: ["-v"]
        case .aspectGrid: ["-g"]
        case .astrocartography: ["-L"]
        case .sphere: ["-XX"]
        case .horizon: ["-Z"]
        case .orbit: ["-S"]
        case .globe: ["-XG"]
        case .ephemeris: ["-E"]
        case .calendar: ["-K"]
        }
    }
}

private struct EngineProcessResult: Sendable {
    let text: String
    let bitmap: Data?
}

public enum AstrologError: LocalizedError, Sendable {
    case missingEngine, invalidInput, invalidOutput, timeout, excessiveOutput, terminationFailed
    case execution(Int32, String)
    case unsafeArguments
    public var errorDescription: String? {
        switch self {
        case .missingEngine: L10n.text("Не удалось запустить расчётный модуль. Откройте AstraGlass из полной папки приложения или установите свежую сборку.")
        case .invalidInput: L10n.text("Проверьте дату, время, часовой пояс и координаты.")
        case .invalidOutput: L10n.text("Astrolog вернул данные, которые не удалось прочитать.")
        case .timeout: L10n.text("Расчёт прерван: превышено время ожидания.")
        case .excessiveOutput: L10n.text("Расчёт прерван: объём отчёта превышает 16 МБ.")
        case .terminationFailed: L10n.text("Операционная система не позволила завершить расчётный процесс.")
        case let .execution(code, detail): L10n.text("Ошибка Astrolog (\(code)): \(detail)", "Astrolog error (\(code)): \(detail)")
        case .unsafeArguments: L10n.text("Эти параметры недоступны в редакторе отчётов. Используйте параметры расчёта и отображения.")
        }
    }
}

/// A fresh, isolated Astrolog subprocess per request. No shared C globals cross
/// requests; calculation never blocks the main actor. Cancellation terminates it.
public actor AstrologEngine {
    private let executableURL: URL
    private let resourceURL: URL

    public init(executableURL: URL? = nil, resourceURL: URL? = nil) {
        // Resolve once from the bundle, independent of subprocess working directories.
        // Helpers is canonical; Resources/Engine supports existing installations.
        let bundle = Bundle.main
        let contents = bundle.bundleURL.appendingPathComponent("Contents", isDirectory: true)
        let executableContents = bundle.executableURL?.deletingLastPathComponent().deletingLastPathComponent()
        let resourceCandidates = [bundle.resourceURL?.appendingPathComponent("Engine", isDirectory: true),
                                  executableContents?.appendingPathComponent("Resources/Engine", isDirectory: true)].compactMap { $0 }
        let resources = resourceURL ?? resourceCandidates.first(where: {
            FileManager.default.fileExists(atPath: $0.appendingPathComponent("astrolog.as").path)
        }) ?? contents.appendingPathComponent("Resources/Engine", isDirectory: true)
        let candidates = [resourceURL?.appendingPathComponent("astrolog"),
                          contents.appendingPathComponent("Helpers/astrolog"),
                          executableContents?.appendingPathComponent("Helpers/astrolog"),
                          resources.appendingPathComponent("astrolog")].compactMap { $0 }
        self.resourceURL = resources
        self.executableURL = executableURL ?? candidates.first(where: {
            FileManager.default.isExecutableFile(atPath: $0.path)
        }) ?? candidates[0]
    }

    public func calculate(_ input: ChartInput, preferences: ChartPreferences? = nil) async throws -> ChartSnapshot {
        try input.validate()
        let text = try await execute(arguments: ["--json"] + input.arguments + (preferences?.engineArguments(keepPrincipalPlanets: true) ?? []), timeout: 20)
        guard let start = text.firstIndex(of: "{"), let end = text.lastIndex(of: "}") else { throw AstrologError.invalidOutput }
        let data = Data(text[start...end].utf8)
        let result = try JSONDecoder().decode(ChartSnapshot.self, from: data)
        guard result.positions.count >= 10, result.houseCusps.count == 12,
              result.positions.allSatisfy({ $0.longitude.isFinite && $0.latitude.isFinite && $0.speed.isFinite }),
              result.houseCusps.allSatisfy(\.isFinite) else { throw AstrologError.invalidOutput }
        return preferences?.applying(to: result) ?? result
    }

    public func report(_ input: ChartInput, options: [String] = ["-v"], preferences: ChartPreferences? = nil) async throws -> String {
        try input.validate()
        return try await run(arguments: input.arguments + (preferences?.engineArguments() ?? []) + options)
    }

    public func relationship(_ input: ChartInput, secondary: ChartInput,
                             mode: String = "synastry", options: [String] = ["-a", "-g"],
                             preferences: ChartPreferences? = nil) async throws -> String {
        try input.validate(); try secondary.validate()
        var second = Array(secondary.arguments.prefix(9))
        second[0] = "-qb2"
        let flag = mode == "transit" ? "-rt" : (mode == "composite" ? "-rc" : "-r0")
        return try await run(arguments: input.arguments + (preferences?.engineArguments() ?? []) + second + [flag, "nul", "nul"] + options)
    }

    /// Renders genuine Astrolog graphics into a private temporary BMP, reads its
    /// bytes, then removes the directory. No caller-supplied command or path can
    /// enable file writes. NSImage(data:) can decode the returned Windows BMP.
    public func renderGraphic(_ input: ChartInput, kind: GraphicPreset = .natal,
                              secondary: ChartInput? = nil, width: Int = 1200,
                              height: Int = 1000, preferences: ChartPreferences? = nil) async throws -> Data {
        try input.validate()
        guard (256...2048).contains(width), (256...2048).contains(height) else { throw AstrologError.invalidInput }
        var arguments = input.arguments + (preferences?.engineArguments() ?? [])
        if kind.needsSecondary {
            guard let secondary else { throw AstrologError.invalidInput }
            try secondary.validate()
            var second = Array(secondary.arguments.prefix(9)); second[0] = "-qb2"
            arguments += second + [kind == .composite ? "-rc" : "-r0", "nul", "nul"]
        }
        arguments += kind.arguments + ["-Xw", String(width), String(height), "=Xr", "-Xs", "200"]
        let result = try await executeProcess(arguments: arguments, timeout: 40, graphics: true)
        guard let data = result.bitmap, data.count >= 54,
              data.prefix(2) == Data([0x42, 0x4d]) else { throw AstrologError.invalidOutput }
        return data
    }

    /// Read-only report switches. No shell, file writes, expression evaluation,
    /// loops, input scripts, web fetching, or executable launching are accepted.
    public func run(arguments: [String], timeout: TimeInterval = 30) async throws -> String {
        guard arguments.count <= 256, arguments.allSatisfy({ $0.utf8.count < 200 && !$0.contains("\n") && !$0.contains("\0") }) else {
            throw AstrologError.unsafeArguments
        }
        let blocked = ["i", "o", "Q", "M", "~", "W", "YQ", "Yq", "YX", "Xn", "XQ", "YI", "zi", "zc", "zL", "bJ"]
        for (index, token) in arguments.enumerated() {
            // FProcessSwitches accepts ':' and switches without a prefix too.
            // Check the same spelling variants before passing anything to it.
            let value = token.first.map { "-=_/:".contains($0) } == true ? String(token.dropFirst()) : token
            if blocked.contains(where: { value.hasPrefix($0) }) { throw AstrologError.unsafeArguments }
            // Raw graphics write files and need an explicit destination API.
            if value.hasPrefix("X") { throw AstrologError.unsafeArguments }
            // The entire family (including rc0, rm0 and rp0/rp1) can read
            // chart files, except ring selection, progression toggles and _r.
            let relationshipWithoutFiles = token.hasPrefix("_r") || value.hasPrefix("rP") ||
                (value.count > 1 && "123456".contains(value[value.index(after: value.startIndex)]))
            if value.hasPrefix("r") && !relationshipWithoutFiles {
                guard index + 2 < arguments.count, arguments[index + 1] == "nul", arguments[index + 2] == "nul" else { throw AstrologError.unsafeArguments }
            }
            if value.hasPrefix("y") {
                guard index + 1 < arguments.count, arguments[index + 1] == "nul" else { throw AstrologError.unsafeArguments }
            }
        }
        return try await execute(arguments: arguments + ["_k", "_k0"], timeout: max(1, min(timeout, 60)))
    }

    private func execute(arguments: [String], timeout: TimeInterval) async throws -> String {
        try await executeProcess(arguments: arguments, timeout: timeout, graphics: false).text
    }

    private func executeProcess(arguments: [String], timeout: TimeInterval, graphics: Bool) async throws -> EngineProcessResult {
        let executable = executableURL, resources = resourceURL
        let control = ProcessControl()
        return try await withTaskCancellationHandler {
            try await Task.detached(priority: .userInitiated) {
                try Task.checkCancellation()
                guard FileManager.default.isExecutableFile(atPath: executable.path) else { throw AstrologError.missingEngine }
                let folder = FileManager.default.temporaryDirectory.appendingPathComponent("AstraGlass-\(UUID().uuidString)", isDirectory: true)
                try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
                defer { try? FileManager.default.removeItem(at: folder) }
                let outputURL = folder.appendingPathComponent("output.txt")
                let errorURL = folder.appendingPathComponent("error.txt")
                let graphicURL = folder.appendingPathComponent("chart.bmp")
                let maximumOutputSize = 16 * 1024 * 1024
                func outputSize() -> Int {
                    [outputURL, errorURL, graphicURL].reduce(0) { total, url in
                        let attributes = try? FileManager.default.attributesOfItem(atPath: url.path)
                        return total + ((attributes?[.size] as? NSNumber)?.intValue ?? 0)
                    }
                }
                FileManager.default.createFile(atPath: outputURL.path, contents: nil)
                FileManager.default.createFile(atPath: errorURL.path, contents: nil)
                let output = try FileHandle(forWritingTo: outputURL)
                let errors = try FileHandle(forWritingTo: errorURL)
                defer { try? output.close(); try? errors.close() }
                let process = Process()
                process.executableURL = executable
                let safePrefix = [graphics ? "-0n~" : "-0on~", "-YQ", "0"]
                process.arguments = arguments.first == "--json" ? ["--json"] + safePrefix + arguments.dropFirst() : safePrefix + arguments
                // Palette BMP uses Astrolog's built-in vector map and needs no
                // external earth.bmp texture for cartography/globe presets.
                if graphics { process.arguments! += ["-Xbb", "-Xo", graphicURL.path] }
                process.standardInput = FileHandle.nullDevice
                process.standardOutput = output
                process.standardError = errors
                process.currentDirectoryURL = resources
                var environment = ProcessInfo.processInfo.environment
                environment["ASTROLOG"] = ".:./ephem"
                environment.removeValue(forKey: "ASTR")
                environment.removeValue(forKey: "ASTR800")
                environment["LC_ALL"] = "C"
                process.environment = environment
                try control.launch(process)
                let deadline = Date().addingTimeInterval(timeout)
                var reason: AstrologError?
                while process.isRunning {
                    if control.isCancelled { control.stop(); break }
                    if Date() > deadline { reason = .timeout; control.stop(); break }
                    if outputSize() > maximumOutputSize { reason = .excessiveOutput; control.stop(); break }
                    try await Task.sleep(nanoseconds: 20_000_000)
                }
                // No unbounded waitUntilExit: give SIGTERM a short grace period,
                // then reap only this task's child with SIGKILL if necessary.
                if process.isRunning {
                    let grace = Date().addingTimeInterval(0.5)
                    while process.isRunning && Date() < grace { try await Task.sleep(nanoseconds: 20_000_000) }
                    if process.isRunning { control.forceStop() }
                    let finalDeadline = Date().addingTimeInterval(1)
                    while process.isRunning && Date() < finalDeadline { try await Task.sleep(nanoseconds: 20_000_000) }
                    if process.isRunning { throw AstrologError.terminationFailed }
                }
                if control.isCancelled { throw CancellationError() }
                if let reason { throw reason }
                // A process may produce its entire report and exit before the
                // next poll. Check all outputs again before allocating Data.
                guard outputSize() <= maximumOutputSize else { throw AstrologError.excessiveOutput }
                let outData = try Data(contentsOf: outputURL)
                let errData = try Data(contentsOf: errorURL)
                let text = String(decoding: outData, as: UTF8.self)
                let detail = String(decoding: errData, as: UTF8.self)
                guard process.terminationStatus == 0 else { throw AstrologError.execution(process.terminationStatus, String((detail + text).prefix(1200))) }
                let bitmap = graphics ? try Data(contentsOf: graphicURL) : nil
                if let bitmap, bitmap.count > maximumOutputSize { throw AstrologError.excessiveOutput }
                return EngineProcessResult(text: text, bitmap: bitmap)
            }.value
        } onCancel: { control.cancel() }
    }
}

/// NSLock protects cancellation that can arrive on another executor before run().
private final class ProcessControl: @unchecked Sendable {
    private let lock = NSLock()
    private var process: Process?
    private var cancelled = false
    var isCancelled: Bool { lock.withLock { cancelled } }
    func launch(_ process: Process) throws {
        try lock.withLock {
            if cancelled { throw CancellationError() }
            self.process = process
            try process.run()
        }
    }
    func stop() { lock.withLock { if process?.isRunning == true { process?.terminate() } } }
    func forceStop() { lock.withLock { if let process, process.isRunning { _ = kill(process.processIdentifier, SIGKILL) } } }
    func cancel() { lock.withLock { cancelled = true; if process?.isRunning == true { process?.terminate() } } }
}
