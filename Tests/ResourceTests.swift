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
        precondition(InterpretationPack(rawValue: "txt3") == nil, "Retired collection must not be selectable")
        for id in 0..<40 { precondition(!houseSystemDescription(id).isEmpty) }
        let corpusURL = root.appendingPathComponent("Resources/interpretations.json")
        if FileManager.default.fileExists(atPath: corpusURL.path) {
            let library = try InterpretationLibrary(url: corpusURL)
            precondition(library.sources.count == 4 && library.records.count == 823)
            precondition(library.records.allSatisfy { InterpretationLibrary.isRussianText($0.body) })
            precondition(!library.forPlanet(id: 1, sign: 9, house: 10).isEmpty)
            print("Podvodny: 823 sections / 4 sources; retired collection unavailable")
        }
        print("Resources: bundled font, all planet/sign/aspect glyphs, traditional Pluto, 40 house descriptions verified")
    }
}
