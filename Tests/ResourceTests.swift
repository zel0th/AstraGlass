import Foundation
import AppKit
import CoreText
import SwiftUI

@main @MainActor
struct ResourceTests {
    static func main() throws {
        let root = URL(fileURLWithPath: CommandLine.arguments[1])
        let fontURL = root.appendingPathComponent("Resources/Fonts/AstraGlassAstrology.ttf")
        precondition(CTFontManagerRegisterFontsForURL(fontURL as CFURL, .process, nil))
        let font = AstroStyle.symbolNSFont(size: 24)
        precondition(font.fontName == "AstraGlassAstrology", "Must use the bundled symbol font")
        let text = (AstroStyle.planetGlyphs + AstroStyle.signGlyphs + ["Ch", "℞", "☌", "☍", "□", "△", "✶", "∠"]).joined()
        let codes = Array(text.utf16); var glyphs = [CGGlyph](repeating: 0, count: codes.count)
        precondition(CTFontGetGlyphsForCharacters(font as CTFont, codes, &glyphs, codes.count) && !glyphs.contains(0), "No missing astrology glyphs")
        precondition(AstroStyle.glyph(10) == "⯓", "Traditional Pluto glyph")
        precondition(AstroStyle.objectColor(1) == Color.red && AstroStyle.objectColor(5) == Color.red)
        precondition(AstroStyle.objectColor(4) == Color.green && AstroStyle.objectColor(2) == Color.blue)
        for id in ChartPreferences.objectIDs { precondition(AstroStyle.objectColor(id) != Color.secondary) }
        precondition(AstroStyle.aspectColor(0) == .blue && AstroStyle.aspectColor(90) == .red && AstroStyle.aspectColor(120) == .green)
        // A stellium with all longitudes identical must still expose each pair.
        let positions = Dictionary(uniqueKeysWithValues: (1...5).map { id in
            (id, PlanetPosition(id: id, longitude: 359, latitude: 0, speed: 1, house: 1))
        })
        let conjunctions = (1...4).flatMap { first in ((first + 1)...5).map { second in
            ChartAspect(first: first, second: second, kind: 1, angle: 0, orb: 0)
        } }
        let center = CGPoint(x: 300, y: 300)
        for radius in [CGFloat(210), 262, 500] {
            let markers = ChartWheelGeometry.conjunctionMarkers(aspects: conjunctions, positions: positions, asc: 0, radius: radius, center: center)
            precondition(markers.count == 10)
            for (id, location) in markers {
                precondition(hypot(location.x - center.x, location.y - center.y) <= radius * 0.50)
                for (otherID, other) in markers where id != otherID {
                    precondition(hypot(location.x - other.x, location.y - other.y) >= 28 * max(0.8, radius / 262) - 0.001)
                }
            }
        }
        let wrapMiddle = ChartWheelGeometry.midpoint(359, 1)
        precondition(abs(wrapMiddle - 360) < 0.001, "Conjunction across Aries must not be placed opposite the planets")
        for index in 0..<12 {
            let start = Double(index * 30 + 350).truncatingRemainder(dividingBy: 360)
            let end = (start + 30).truncatingRemainder(dividingBy: 360)
            let sector = ChartWheelGeometry.houseSector(start: start, end: end, asc: 350, radius: 262, center: center)
            precondition(sector.contains(ChartWheelGeometry.point(start + 15, asc: 350, radius: 262 * 0.7, center: center)))
            precondition(!sector.contains(center))
            precondition(!sector.contains(ChartWheelGeometry.point(start + 15, asc: 350, radius: 262 * 0.95, center: center)))
            precondition(!sector.contains(ChartWheelGeometry.point(start + 35, asc: 350, radius: 262 * 0.7, center: center)))
        }
        precondition(AstroStyle.aspectColor(180) == Color(red: 0.72, green: 0.52, blue: 0.94))
        precondition(ChartWheelGeometry.houseOuter - ChartWheelGeometry.houseInner < 0.11)
        precondition(ChartWheelGeometry.houseOuter < ChartWheelGeometry.zodiacInner)
        // All glyph rectangles must be inside the houses, including a dense cluster
        // crossing Aries and the maximum supported number of bodies in two rows.
        let cluster = ChartPreferences.objectIDs.enumerated().map { index, id in
            PlanetPosition(id: id, longitude: (359.0 + Double(index) / 100).truncatingRemainder(dividingBy: 360), latitude: 0, speed: 1, house: 1)
        }
        for comparison in [false, true] {
            for secondary in [false, true] {
                let radius: CGFloat = 210
                let scale = max(0.8, radius / 262)
                let marks = ChartWheelGeometry.planetMarkers(positions: cluster, asc: 352, radius: radius, center: center, secondary: secondary, comparison: comparison)
                precondition(marks.count == cluster.count)
                let halfWidth = (comparison ? 11.0 : 16.0) * scale, halfHeight = (comparison ? 13.0 : 19.0) * scale
                for (id, mark) in marks {
                    for x in [-halfWidth, halfWidth] { for y in [-halfHeight, halfHeight] {
                        precondition(hypot(mark.x + x - center.x, mark.y + y - center.y) < radius * ChartWheelGeometry.houseInner)
                    } }
                    for (otherID, other) in marks where id != otherID {
                        precondition(abs(mark.x - other.x) >= (comparison ? 24 : 34) * scale - 0.001 || abs(mark.y - other.y) >= (comparison ? 28 : 40) * scale - 0.001, "Dense planet labels must not overlap")
                    }
                }
            }
        }
        var date = ChartInput(year: 2024, month: 1, day: 31, hour: 23, minute: 59)
        // Hit regions must partition unequal houses, including the Aries wrap,
        // and leave both the aspect field and zodiac band available to other buttons.
        let cusps = [352.0, 14, 39, 84, 128, 155, 172, 194, 219, 264, 308, 335]
        let sectors = cusps.indices.map { index in
            ChartWheelGeometry.houseSector(start: cusps[index], end: cusps[(index + 1) % 12], asc: 352, radius: 262, center: center)
        }
        for index in cusps.indices {
            let span = (cusps[(index + 1) % 12] - cusps[index] + 360).truncatingRemainder(dividingBy: 360)
            let number = ChartWheelGeometry.point(ChartWheelGeometry.houseMidpoint(cusps[index], cusps[(index + 1) % 12]), asc: 352, radius: 262 * ChartWheelGeometry.houseMiddle, center: center)
            precondition(sectors[index].contains(number), "House number must lie at the angular and radial center of its own sector")
            for fraction in [0.1, 0.5, 0.9] {
                let longitude = cusps[index] + span * fraction
                for lane in [0.69, 0.73, 0.77] {
                    let location = ChartWheelGeometry.point(longitude, asc: 352, radius: 262 * lane, center: center)
                    precondition(sectors.indices.filter { sectors[$0].contains(location) } == [index])
                }
                for lane in [0.5, 0.65, 0.81, 0.93] {
                    let location = ChartWheelGeometry.point(longitude, asc: 352, radius: 262 * lane, center: center)
                    precondition(sectors.allSatisfy { !$0.contains(location) })
                }
            }
        }
        date.setCalendarField(\.month, to: 2)
        precondition(date.day == 29 && date.hour == 23 && date.minute == 59)
        date.setCalendarField(\.year, to: 2025)
        precondition(date.day == 28)
        for (year, days) in [(1900, 28), (2000, 29), (1500, 29)] {
            date.setCalendarField(\.year, to: year)
            precondition(date.daysInMonth == days)
        }
        date.month = 4; date.day = 31
        precondition((try? date.validate()) == nil, "Imported invalid dates must be rejected, not silently clamped")
        precondition(InterpretationPack(rawValue: "txt3") == nil, "Retired collection must not be selectable")
        for id in 0..<40 { precondition(!houseSystemDescription(id).isEmpty) }
        let corpusURL = root.appendingPathComponent("Resources/interpretations.json")
        if FileManager.default.fileExists(atPath: corpusURL.path) {
            let library = try InterpretationLibrary(url: corpusURL)
            precondition(library.sources.count == 4 && library.records.count == 823)
            precondition(library.records.allSatisfy { InterpretationLibrary.isRussianText($0.body) })
            precondition(!library.forPlanet(id: 1, sign: 9, house: 10).isEmpty)
            for house in 1...12 {
                for sign in 0..<12 { precondition(!library.forHouse(number: house, sign: sign).isEmpty) }
            }
            print("Podvodny: 823 sections / 4 sources; retired collection unavailable")
        }
        print("Resources: bundled glyphs, object/aspect colors, 10 separate conjunction targets, 12 exclusive house hit regions, calendar transitions, 40 house-system descriptions verified")
    }
}
