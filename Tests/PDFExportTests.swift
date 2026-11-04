import AppKit
import PDFKit

/// Run on macOS with all application sources and ASTRAGLASS_WORKSPACE_TESTS.
/// Exercises actual PDF rendering, text extraction, page bounds and pagination.
@main @MainActor
struct PDFExportTests {
    private static func require(_ condition: Bool, _ message: String) throws {
        if !condition { throw NSError(domain: "PDFExportTests", code: 1, userInfo: [NSLocalizedDescriptionKey: message]) }
    }

    static func main() throws {
        _ = NSApplication.shared
        let root = URL(fileURLWithPath: CommandLine.arguments.dropFirst().first ?? FileManager.default.currentDirectoryPath)
        let output = root.appendingPathComponent(".build/tests/pdf-export.pdf")
        try FileManager.default.createDirectory(at: output.deletingLastPathComponent(), withIntermediateDirectories: true)
        let positions = (1...10).map {
            PlanetPosition(id: $0, longitude: Double($0 * 31 % 360), latitude: 0, speed: $0 == 3 ? -0.7 : 0.7, house: $0)
        }
        let snapshot = ChartSnapshot(engine: "test fixture", julianDay: 2451545,
            positions: positions, houseCusps: (0..<12).map { Double($0 * 30) },
            aspects: [ChartAspect(first: 1, second: 7, kind: 2, angle: 180, orb: 1.25)],
            unavailableObjects: [])
        let paragraphs = (0..<45).map { index in
            "PARAGRAPH-\(String(format: "%03d", index)). " + String(repeating:
                "Кириллица должна оставаться доступной для поиска. Длинный авторский абзац переносится между страницами без потери последней строки. ", count: 8)
        }
        let passage = InterpretationRecord(id: "pdf-fixture", title: "Проверка многостраничной трактовки",
            originalTitle: "Проверка", category: "Планеты",
            body: paragraphs.joined(separator: "\n\n") + "\nФИНАЛЬНЫЙМАРКЕР",
            source: "fixture.docx", sourceTitle: "Синтетический источник", sourceSHA256: "fixture",
            paragraphStart: 1, paragraphEnd: 45, headingLevel: 1, breadcrumbs: [], keywords: [],
            planetIDs: [1], signIndices: [], houseNumbers: [], aspectAngle: nil, bindings: ["planet:1"])
        try ChartPDFExporter.export(url: output, snapshot: snapshot,
            title: "Тест карты · Unicode", subtitle: "Москва · 01.01.2000 · 12:00 · UTC+03:00",
            system: "Тропический зодиак · Плацидус", passages: [passage, passage])
        guard let document = PDFDocument(url: output) else {
            throw NSError(domain: "PDFExportTests", code: 2, userInfo: [NSLocalizedDescriptionKey: "Unreadable PDF"])
        }
        try require(document.pageCount > 3, "Long interpretation was not paginated")
        let extracted = (document.string ?? "").filter { !$0.isWhitespace }
        try require(extracted.contains("ФИНАЛЬНЫЙМАРКЕР"), "Final Cyrillic text was lost")
        try require(extracted.components(separatedBy: "ФИНАЛЬНЫЙМАРКЕР").count == 2, "Duplicate library section was exported")
        try require(extracted.contains("fixture.docx"), "Source attribution was lost")
        for index in 0..<45 {
            try require(extracted.contains("PARAGRAPH-\(String(format: "%03d", index))."), "Paragraph \(index) is missing")
        }
        for index in 0..<document.pageCount {
            guard let page = document.page(at: index) else { continue }
            let bounds = page.bounds(for: .mediaBox)
            try require(abs(bounds.width - 595.28) < 0.1 && abs(bounds.height - 841.89) < 0.1,
                "PDF page \(index + 1) is not A4")
            try require(!(page.string ?? "").isEmpty, "Blank PDF page \(index + 1)")
        }
        print("PDF export: A4, \(document.pageCount) pages, all 45 paragraphs and final Cyrillic marker preserved; deduplication passed.")
    }
}
