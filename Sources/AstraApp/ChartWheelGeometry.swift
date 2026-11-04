import SwiftUI

enum ChartWheelGeometry {
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
        path.move(to: point(start, asc: asc, radius: radius * 0.85, center: center))
        for longitude in longitudes.dropFirst() {
            path.addLine(to: point(longitude, asc: asc, radius: radius * 0.85, center: center))
        }
        for longitude in longitudes.reversed() {
            path.addLine(to: point(longitude, asc: asc, radius: radius * 0.56, center: center))
        }
        path.closeSubpath()
        return path
    }

    /// Every conjunction gets its own visible button even for identical
    /// longitudes or a stellium. Keep badges inside the aspect field, away from
    /// house numbers and planet labels; leaders retain the true position.
    static func conjunctionMarkers(aspects: [ChartAspect], positions: [Int: PlanetPosition],
                                   asc: Double, radius: CGFloat, center: CGPoint) -> [String: CGPoint] {
        var placed: [String: CGPoint] = [:]
        let spacing = 28 * max(0.8, radius / 262)
        for aspect in aspects.filter({ abs($0.angle) < 0.01 }).sorted(by: { $0.id < $1.id }) {
            guard let first = positions[aspect.first], let second = positions[aspect.second] else { continue }
            let middle = midpoint(first.longitude, second.longitude)
            var candidates: [CGPoint] = []
            for offset in stride(from: 0.0, through: 176, by: 8) {
                for shift in offset == 0 ? [0] : [offset, -offset] {
                    for lane in [0.49, 0.39, 0.29, 0.19] {
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
