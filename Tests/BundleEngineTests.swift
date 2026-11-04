import Foundation

/// Run inside a temporary .app hierarchy to exercise default bundle discovery.
@main struct BundleEngineTests {
    static func main() async throws {
        let engine = AstrologEngine()
        let input = ChartInput(utcOffset: 0)
        let chart = try await engine.calculate(input, preferences: .defaults)
        guard chart.positions.count >= 10 else { throw AstrologError.invalidOutput }
        let report = try await engine.relationship(input, secondary: input, preferences: .defaults)
        guard report.count > 50 else { throw AstrologError.invalidOutput }
        for transit in [false, true] {
            let comparison = try await engine.comparison(input, secondary: input, transit: transit)
            guard comparison.primary.positions.count >= 10,
                  comparison.secondary.positions.count >= 10,
                  comparison.aspects.contains(where: { $0.first == 1 && $0.second == 1 && $0.kind == 1 })
            else { throw AstrologError.invalidOutput }
        }
        let bitmap = try await engine.renderGraphic(input, width: 600, height: 500, preferences: .defaults)
        guard bitmap.count > 1000, bitmap.prefix(2) == Data([0x42, 0x4d]) else { throw AstrologError.invalidOutput }
        print("PASS: bundled chart, native synastry/transit grids, report and graphics from \(CommandLine.arguments[0])")
    }
}
