import SwiftUI

enum ChartWheelGeometry {
    static let zodiacInner: CGFloat = 0.84
    static let houseOuter: CGFloat = 0.78
    static let houseInner: CGFloat = 0.68
    static let houseMiddle = (houseInner + houseOuter) / 2

    static func houseMidpoint(_ start: Double, _ end: Double) -> Double {
        start + (end - start + 360).truncatingRemainder(dividingBy: 360) / 2
    }

    /// Move labels, never the calculated longitude. All label rectangles remain
    /// inside the house ring; a leader preserves each object's exact position.
    static func planetMarkers(positions: [PlanetPosition], asc: Double, radius: CGFloat,
                              center: CGPoint, secondary: Bool = false, comparison: Bool = false) -> [Int: CGPoint] {
        var placed: [Int: CGPoint] = [:]
        let lanes: [CGFloat] = comparison ? [secondary ? 0.425 : 0.575] : [0.575, 0.44]
        let scale = max(0.8, radius / 262)
        let width = (comparison ? 24.0 : 34.0) * scale
        let height = (comparison ? 28.0 : 40.0) * scale
        for planet in positions.sorted(by: { $0.longitude == $1.longitude ? $0.id < $1.id : $0.longitude < $1.longitude }) {
            var candidates: [CGPoint] = []
            for offset in stride(from: 0.0, through: 180, by: 3) {
                for shift in offset == 0 ? [0] : [offset, -offset] {
                    for lane in lanes { candidates.append(point(planet.longitude + shift, asc: asc, radius: radius * lane, center: center)) }
                }
            }
            let distance: (CGPoint) -> CGFloat = { candidate in
                placed.values.map { hypot($0.x - candidate.x, $0.y - candidate.y) }.min() ?? .greatestFiniteMagnitude
            }
            placed[planet.id] = candidates.first { candidate in
                placed.values.allSatisfy { abs($0.x - candidate.x) >= width || abs($0.y - candidate.y) >= height }
            }
                ?? candidates.max { distance($0) < distance($1) }
        }
        return placed
    }

    static func point(_ longitude: Double, asc: Double, radius: CGFloat, center: CGPoint) -> CGPoint {
        let angle = (180 + asc - longitude) * Double.pi / 180
        return CGPoint(x: center.x + cos(angle) * radius, y: center.y + sin(angle) * radius)
    }

    static func midpoint(_ first: Double, _ second: Double) -> Double {
        let delta = (second - first + 540).truncatingRemainder(dividingBy: 360) - 180
        return first + delta / 2
    }

    /// House sectors follow the actual cusps, including the sector crossing 0°.
    /// The central aspect field and outer zodiac band remain unfilled.
    static func houseSector(start: Double, end: Double, asc: Double, radius: CGFloat, center: CGPoint) -> Path {
        let span = (end - start + 360).truncatingRemainder(dividingBy: 360)
        guard span > 0, span.isFinite else { return Path() }
        let steps = max(1, Int(ceil(span / 2)))
        let longitudes = (0...steps).map { start + span * Double($0) / Double(steps) }
        var path = Path()
        path.move(to: point(start, asc: asc, radius: radius * houseOuter, center: center))
        for longitude in longitudes.dropFirst() {
            path.addLine(to: point(longitude, asc: asc, radius: radius * houseOuter, center: center))
        }
        for longitude in longitudes.reversed() {
            path.addLine(to: point(longitude, asc: asc, radius: radius * houseInner, center: center))
        }
        path.closeSubpath()
        return path
    }

    /// Every conjunction gets its own visible button even for identical
    /// longitudes or a stellium. Keep badges inside the aspect field, away from
    /// house numbers and planet labels; leaders retain the true position.
    static func conjunctionMarkers(aspects: [ChartAspect], positions: [Int: PlanetPosition],
                                   asc: Double, radius: CGFloat, center: CGPoint, secondaryPositions: [Int: PlanetPosition]? = nil) -> [String: CGPoint] {
        var placed: [String: CGPoint] = [:]
        let spacing = 28 * max(0.8, radius / 262)
        for aspect in aspects.filter({ abs($0.angle) < 0.01 }).sorted(by: { $0.id < $1.id }) {
            guard let first = positions[aspect.first], let second = (secondaryPositions ?? positions)[aspect.second] else { continue }
            let middle = midpoint(first.longitude, second.longitude)
            var candidates: [CGPoint] = []
            for offset in stride(from: 0.0, through: 176, by: 8) {
                for shift in offset == 0 ? [0] : [offset, -offset] {
                    for lane in (secondaryPositions == nil ? [0.34, 0.24, 0.14] : [0.27, 0.17, 0.07]) {
                        candidates.append(point(middle + shift, asc: asc, radius: radius * lane, center: center))
                    }
                }
            }
            let distance: (CGPoint) -> CGFloat = { candidate in
                placed.values.map { hypot($0.x - candidate.x, $0.y - candidate.y) }.min() ?? .greatestFiniteMagnitude
            }
            placed[aspect.id] = candidates.first { distance($0) >= spacing }
                ?? candidates.max { distance($0) < distance($1) }
        }
        return placed
    }
}
