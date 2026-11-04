import Foundation
import Darwin

/// Opt-in local diagnostics. No timer or file write is installed in normal use.
/// Example: AstraGlass --profile-output /tmp/app-idle.json --profile-seconds 30
@MainActor
enum AppProfiler {
    private static var started = false

    /// Local QA builds may include this request when Launch Services cannot pass
    /// arguments. Production bundles must not contain profile-request.json.
    private struct ResourceRequest: Decodable {
        let output: String
        let seconds: Double?
        let delay: Double?
        let label: String?
    }

    static func startIfRequested() {
        guard !started else { return }
        let args = CommandLine.arguments
        func value(_ key: String) -> String? {
            guard let index = args.firstIndex(of: key), args.indices.contains(index + 1) else { return nil }
            return args[index + 1]
        }
        var request: ResourceRequest?
        if value("--profile-output") == nil,
           let requestURL = Bundle.main.url(forResource: "profile-request", withExtension: "json"),
           let size = try? requestURL.resourceValues(forKeys: [.fileSizeKey]).fileSize,
           size < 4096,
           let data = try? Data(contentsOf: requestURL) {
            request = try? JSONDecoder().decode(ResourceRequest.self, from: data)
        }
        guard let path = value("--profile-output") ?? request?.output, path.hasPrefix("/") else { return }
        started = true
        let requestedSeconds = value("--profile-seconds").flatMap(Double.init) ?? request?.seconds ?? 30
        let requestedDelay = value("--profile-delay").flatMap(Double.init) ?? request?.delay ?? 5
        let seconds = requestedSeconds.isFinite ? min(300, max(1, requestedSeconds)) : 30
        let delay = requestedDelay.isFinite ? min(60, max(0, requestedDelay)) : 5
        let label = value("--profile-label") ?? request?.label ?? "idle"
        let url = URL(fileURLWithPath: path)
        Task.detached(priority: .utility) {
            do {
                try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                try await record(to: url, seconds: seconds, label: label, delay: delay)
            } catch {
                FileHandle.standardError.write(Data("AstraGlass profile: \(error.localizedDescription)\n".utf8))
            }
        }
    }

    private struct Sample: Codable, Sendable {
        let elapsedSeconds: Double
        let userCPUSeconds: Double
        let systemCPUSeconds: Double
        let residentBytes: UInt64?
        let peakResidentBytes: Int64
        let cpuPercentSincePrevious: Double?
    }

    private struct Profile: Codable, Sendable {
        let label: String
        let timestampUTC: String
        let pid: Int32
        let durationSeconds: Double
        let delayBeforeSamplingSeconds: Double
        let sampleIntervalSeconds: Double
        let userCPUSeconds: Double
        let systemCPUSeconds: Double
        let averageCPUPercentOfOneCore: Double
        let initialResidentBytes: UInt64?
        let finalResidentBytes: UInt64?
        let maximumSampledResidentBytes: UInt64?
        let peakResidentBytesSinceLaunch: Int64
        let osVersion: String
        let logicalProcessorCount: Int
        let samples: [Sample]
        let scope: String
    }

    nonisolated private static func residentBytes() -> UInt64? {
        var info = mach_task_basic_info_data_t()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info_data_t>.size / MemoryLayout<integer_t>.size)
        let result = withUnsafeMutablePointer(to: &info) { pointer in
            pointer.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { rebound in
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), rebound, &count)
            }
        }
        return result == KERN_SUCCESS ? UInt64(info.resident_size) : nil
    }

    nonisolated private static func snapshot(elapsed: Double, previous: Sample?) throws -> Sample {
        var usage = rusage()
        guard getrusage(RUSAGE_SELF, &usage) == 0 else {
            throw NSError(domain: NSPOSIXErrorDomain, code: Int(errno))
        }
        let user = Double(usage.ru_utime.tv_sec) + Double(usage.ru_utime.tv_usec) / 1_000_000
        let system = Double(usage.ru_stime.tv_sec) + Double(usage.ru_stime.tv_usec) / 1_000_000
        let percent: Double?
        if let previous, elapsed > previous.elapsedSeconds {
            percent = max(0, (user + system - previous.userCPUSeconds - previous.systemCPUSeconds) / (elapsed - previous.elapsedSeconds) * 100)
        } else { percent = nil }
        return Sample(elapsedSeconds: elapsed, userCPUSeconds: user, systemCPUSeconds: system,
                      residentBytes: residentBytes(), peakResidentBytes: Int64(usage.ru_maxrss),
                      cpuPercentSincePrevious: percent)
    }

    nonisolated private static func record(to url: URL, seconds: Double, label: String, delay: Double) async throws {
        let timestamp = ISO8601DateFormatter().string(from: Date())
        let start = DispatchTime.now().uptimeNanoseconds
        var samples = [try snapshot(elapsed: 0, previous: nil)]
        repeat {
            try await Task.sleep(nanoseconds: 500_000_000)
            let elapsed = Double(DispatchTime.now().uptimeNanoseconds - start) / 1_000_000_000
            samples.append(try snapshot(elapsed: elapsed, previous: samples.last))
        } while samples.last!.elapsedSeconds < seconds
        let first = samples.first!, last = samples.last!
        let user = last.userCPUSeconds - first.userCPUSeconds
        let system = last.systemCPUSeconds - first.systemCPUSeconds
        let profile = Profile(label: label, timestampUTC: timestamp, pid: getpid(),
                              durationSeconds: last.elapsedSeconds, delayBeforeSamplingSeconds: delay,
                              sampleIntervalSeconds: 0.5, userCPUSeconds: user, systemCPUSeconds: system,
                              averageCPUPercentOfOneCore: (user + system) / last.elapsedSeconds * 100,
                              initialResidentBytes: first.residentBytes, finalResidentBytes: last.residentBytes,
                              maximumSampledResidentBytes: samples.compactMap(\.residentBytes).max(),
                              peakResidentBytesSinceLaunch: last.peakResidentBytes,
                              osVersion: ProcessInfo.processInfo.operatingSystemVersionString,
                              logicalProcessorCount: ProcessInfo.processInfo.activeProcessorCount,
                              samples: samples,
                              scope: "Main GUI process only; excludes Astrolog child processes. CPU is the getrusage(RUSAGE_SELF) delta during this sample. Resident memory is task_info(MACH_TASK_BASIC_INFO), not total physical footprint. Peak RSS is ru_maxrss in bytes since process launch. A brief sample does not prove absence of long-term leaks.")
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.keyEncodingStrategy = .convertToSnakeCase
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try encoder.encode(profile).write(to: url, options: .atomic)
        FileHandle.standardError.write(Data("AstraGlass profile saved: \(url.path)\n".utf8))
    }
}
