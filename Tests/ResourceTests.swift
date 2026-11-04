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
        precondition(!InterpretationPack.txt3.title.contains("Txt3"))
        for id in 0..<40 { precondition(!houseSystemDescription(id).isEmpty) }
        let corpusURL = root.appendingPathComponent("Resources/interpretations-txt3.json")
        if FileManager.default.fileExists(atPath: corpusURL.path) {
            let start = Date(); let library = try InterpretationLibrary(url: corpusURL)
            precondition(library.sources.count == 244 && library.records.count == 22422)
            precondition(library.records.allSatisfy { InterpretationLibrary.isRussianText($0.body) })
            precondition(library.search("Your approach to discipline").isEmpty)
            let opposition = library.forAspect(first: 2, second: 7, angle: 180)
            precondition(!opposition.isEmpty && opposition.allSatisfy { !$0.source.hasPrefix("Engl.") })
            precondition(!library.forPlanet(id: 10, sign: 8, house: 8).isEmpty)
            let a = library.forAspect(first: 1, second: 2, angle: 60)
            precondition(!a.isEmpty && a == library.forAspect(first: 2, second: 1, angle: 60))
            precondition(a.allSatisfy { $0.bindings.contains("aspect-pair:60:1:2") })
            precondition(library.categories.contains("Справочник"))
            print(String(format:"Txt3: %d sources, %d records, loaded in %.3f s",library.sources.count,library.records.count,Date().timeIntervalSince(start)))
        }
        print("Resources: bundled font, all planet/sign/aspect glyphs, traditional Pluto, 40 house descriptions verified")
    }
}
