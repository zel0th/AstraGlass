import AppKit
import CoreGraphics
import CoreText
import SwiftUI

/// A4 report with vector chart rendering and selectable, continuously paginated
/// text. Output is written atomically only after every page has been rendered.
@MainActor
enum ChartPDFExporter {
    static func export(url: URL, snapshot: ChartSnapshot, title: String,
                       subtitle: String, system: String,
                       passages: [InterpretationRecord]) throws {
        let writer = try ReportWriter(title: title)
        try writer.cover(snapshot: snapshot, title: title, subtitle: subtitle, system: system)
        writer.newPage()
        try writer.append(positions(snapshot), title: L10n.text("Положения планет и точек", "Planet and point positions"))
        if !snapshot.houseCusps.isEmpty {
            try writer.append(houses(snapshot), title: L10n.text("Дома карты", "Chart houses"))
        }
        if !snapshot.aspects.isEmpty {
            try writer.append(aspects(snapshot), title: L10n.text("Аспекты карты", "Chart aspects"))
        }

        var seen = Set<String>()
        let unique = passages.filter { seen.insert($0.id).inserted }
        if unique.isEmpty {
            try writer.append(body(L10n.text(
                "Для этой карты нет подключённых текстов. Импортируйте библиотеку трактовок в настройках и повторите экспорт, чтобы добавить описания.",
                "No interpretation texts are available for this chart. Import an interpretation library in Settings and export again to include descriptions.")),
                title: L10n.text("Трактовки", "Interpretations"))
        } else {
            writer.newPage()
            try writer.append(body(L10n.text(
                "Ниже приведены разделы вашей библиотеки, соответствующие выбранным планетам, знакам, домам и аспектам карты. Повторяющиеся разделы включены один раз. Авторский текст сохранён на языке источника; для аспектов приведены отдельные трактовки каждой планеты, когда именно так они представлены в книге.",
                "The following library sections correspond to the selected planets, signs, houses and aspects. Repeated sections appear once. Author texts retain their original language; aspect interpretations are given separately for each planet when the source presents them that way.")),
                title: L10n.text("Библиотека трактовок", "Interpretation library"))
            for record in unique {
                let source = "\(record.sourceTitle) · \(record.source) · " +
                    record.sourceRange
                try writer.append(body(record.body), title: record.title, source: source)
            }
        }
        try writer.finish(at: url)
    }

    private static func body(_ string: String) -> NSAttributedString {
        let paragraph = NSMutableParagraphStyle()
        paragraph.lineSpacing = 3
        paragraph.paragraphSpacing = 8
        paragraph.hyphenationFactor = 0.7
        return NSAttributedString(string: string, attributes: [
            .font: NSFont(name: "Georgia", size: 11) ?? NSFont.systemFont(ofSize: 11),
            .foregroundColor: ReportWriter.ink,
            .paragraphStyle: paragraph
        ])
    }

    private static func table(_ rows: [[String]], stops: [CGFloat]) -> NSAttributedString {
        let paragraph = NSMutableParagraphStyle()
        paragraph.lineSpacing = 4
        paragraph.paragraphSpacing = 5
        paragraph.tabStops = stops.map { NSTextTab(textAlignment: .left, location: $0) }
        paragraph.defaultTabInterval = 80
        return NSAttributedString(string: rows.map { $0.joined(separator: "\t") }.joined(separator: "\n"), attributes: [
            .font: NSFont.systemFont(ofSize: 10),
            .foregroundColor: ReportWriter.ink,
            .paragraphStyle: paragraph
        ])
    }

    private static func positions(_ snapshot: ChartSnapshot) -> NSAttributedString {
        var rows = [[L10n.text("Объект", "Object"), L10n.text("Знак", "Sign"),
                     L10n.text("Положение", "Position"), L10n.text("Дом", "House"), L10n.text("Ход", "Motion")]]
        rows += snapshot.positions.map {
            [AstroStyle.name($0.id), AstroStyle.signNames[$0.sign], AstroStyle.position($0.longitude),
             String($0.house), $0.isRetrograde ? L10n.text("Ретроградный", "Retrograde") : L10n.text("Прямой", "Direct")]
        }
        return table(rows, stops: [130, 230, 320, 365])
    }

    private static func houses(_ snapshot: ChartSnapshot) -> NSAttributedString {
        var rows = [[L10n.text("Дом", "House"), L10n.text("Знак", "Sign"), L10n.text("Куспид", "Cusp")]]
        rows += snapshot.houseCusps.enumerated().map { index, cusp in
            let axis = [0: " · ASC", 3: " · IC", 6: " · DSC", 9: " · MC"][index] ?? ""
            return [String(index + 1) + axis, AstroStyle.signNames[AstroStyle.sign(cusp)], AstroStyle.position(cusp)]
        }
        return table(rows, stops: [130, 260])
    }

    private static func aspects(_ snapshot: ChartSnapshot) -> NSAttributedString {
        var rows = [[L10n.text("Объекты", "Objects"), L10n.text("Аспект", "Aspect"), L10n.text("Орбис", "Orb")]]
        rows += snapshot.aspects.map {
            [AstroStyle.name($0.first) + " · " + AstroStyle.name($0.second),
             AstroStyle.aspectName($0.angle), String(format: "%.2f°", abs($0.orb))]
        }
        return table(rows, stops: [225, 405])
    }
}

@MainActor
private final class ReportWriter {
    static let ink = NSColor(calibratedRed: 0.16, green: 0.15, blue: 0.21, alpha: 1)
    private static let muted = NSColor(calibratedRed: 0.43, green: 0.42, blue: 0.49, alpha: 1)
    private static let purple = NSColor(calibratedRed: 0.40, green: 0.31, blue: 0.69, alpha: 1)
    private static let pageSize = CGSize(width: 595.28, height: 841.89)
    private static let margin: CGFloat = 46
    private static let bottom: CGFloat = 61
    private static let top: CGFloat = 763
    private var cursor = ReportWriter.top
    private var pageNumber = 0
    private let data = NSMutableData()
    private let context: CGContext
    private let documentTitle: String
    private var pageOpen = false

    init(title: String) throws {
        documentTitle = title
        var bounds = CGRect(origin: .zero, size: Self.pageSize)
        guard let consumer = CGDataConsumer(data: data as CFMutableData),
              let context = CGContext(consumer: consumer, mediaBox: &bounds, [
                kCGPDFContextTitle: title,
                kCGPDFContextCreator: "AstraGlass",
                kCGPDFContextSubject: L10n.text("Карта и трактовки", "Chart and interpretations")
              ] as CFDictionary) else { throw CocoaError(.fileWriteUnknown) }
        self.context = context
    }

    func newPage() {
        if pageOpen { endPage() }
        context.beginPDFPage(nil)
        pageOpen = true
        pageNumber += 1
        cursor = Self.top
        context.setFillColor(NSColor.white.cgColor)
        context.fill(CGRect(origin: .zero, size: Self.pageSize))
        context.setFillColor(Self.purple.cgColor)
        context.fill(CGRect(x: 0, y: Self.pageSize.height - 6, width: Self.pageSize.width, height: 6))
        drawLabel("ASTRAGLASS", at: CGPoint(x: Self.margin, y: 799), size: 9, color: Self.purple)
        if pageNumber > 1 {
            // Only this running label is shortened; the complete title is printed
            // in the report body, including unusually long user-provided titles.
            let label = documentTitle.count > 58 ? String(documentTitle.prefix(57)) + "…" : documentTitle
            drawLabel(label, at: CGPoint(x: Self.margin + 115, y: 799), size: 8, color: Self.muted)
        }
    }

    func cover(snapshot: ChartSnapshot, title: String, subtitle: String, system: String) throws {
        newPage()
        let titleStyle = NSMutableParagraphStyle()
        titleStyle.paragraphSpacing = 10
        let heading = NSAttributedString(string: title, attributes: [
            .font: NSFont.systemFont(ofSize: 26, weight: .semibold),
            .foregroundColor: Self.ink, .paragraphStyle: titleStyle
        ])
        try flow(heading)
        let metadataStyle = NSMutableParagraphStyle()
        metadataStyle.lineSpacing = 4
        try flow(NSAttributedString(string: subtitle + "\n" + system, attributes: [
            .font: NSFont.systemFont(ofSize: 10), .foregroundColor: Self.muted, .paragraphStyle: metadataStyle
        ]))
        cursor -= 12
        let side = Self.pageSize.width - Self.margin * 2
        if cursor - side < Self.bottom + 45 { newPage() }
        let chart = ChartWheel(snapshot: snapshot, selectedPlanet: 0, select: { _ in })
            .frame(width: side, height: side)
            .background(Color.white)
            .environment(\.colorScheme, .light)
        let renderer = ImageRenderer(content: chart)
        renderer.proposedSize = ProposedViewSize(width: side, height: side)
        var rendered = false
        renderer.render { size, render in
            context.saveGState()
            context.translateBy(x: Self.margin, y: cursor - size.height)
            render(context)
            context.restoreGState()
            rendered = true
        }
        guard rendered else { throw CocoaError(.fileWriteUnknown) }
        cursor -= side + 12
        try flow(NSAttributedString(string: L10n.text(
            "Карта, положения и трактовки · Подготовлено в AstraGlass",
            "Chart, positions and interpretations · Prepared with AstraGlass"), attributes: [
                .font: NSFont.systemFont(ofSize: 9), .foregroundColor: Self.muted
            ]))
    }

    func append(_ content: NSAttributedString, title: String, source: String? = nil) throws {
        if cursor < Self.bottom + 145 { newPage() }
        let paragraph = NSMutableParagraphStyle()
        paragraph.lineSpacing = 2
        paragraph.paragraphSpacing = 10
        let section = NSMutableAttributedString(string: title + "\n", attributes: [
            .font: NSFont.systemFont(ofSize: 17, weight: .semibold),
            .foregroundColor: Self.purple, .paragraphStyle: paragraph
        ])
        if let source {
            let referenceStyle = NSMutableParagraphStyle()
            referenceStyle.lineSpacing = 2
            referenceStyle.paragraphSpacing = 14
            section.append(NSAttributedString(string: source + "\n", attributes: [
                .font: NSFont.systemFont(ofSize: 8), .foregroundColor: Self.muted,
                .paragraphStyle: referenceStyle
            ]))
        }
        section.append(content)
        try flow(section)
        cursor -= 23
    }

    /// CoreText consumes UTF-16 ranges, never String character counts. It shapes
    /// Cyrillic/emoji and handles long paragraphs and unbroken words across pages.
    private func flow(_ text: NSAttributedString) throws {
        guard text.length > 0 else { return }
        let framesetter = CTFramesetterCreateWithAttributedString(text as CFAttributedString)
        let width = Self.pageSize.width - Self.margin * 2
        var offset = 0
        while offset < text.length {
            if cursor < Self.bottom + 35 { newPage() }
            let available = cursor - Self.bottom
            let path = CGPath(rect: CGRect(x: Self.margin, y: Self.bottom, width: width, height: available), transform: nil)
            let frame = CTFramesetterCreateFrame(framesetter, CFRange(location: offset, length: 0), path, nil)
            let visible = CTFrameGetVisibleStringRange(frame)
            guard visible.length > 0 else { throw CocoaError(.formatting) }
            context.saveGState()
            context.textMatrix = .identity
            CTFrameDraw(frame, context)
            context.restoreGState()
            // Use the lines that were actually placed in this frame. Measuring
            // the visible substring again can change paragraph spacing at a
            // page boundary and make the next section overlap its final line.
            let lines = CTFrameGetLines(frame) as! [CTLine]
            guard let lastLine = lines.last else { throw CocoaError(.formatting) }
            var origins = [CGPoint](repeating: .zero, count: lines.count)
            origins.withUnsafeMutableBufferPointer { buffer in
                CTFrameGetLineOrigins(frame, CFRange(location: 0, length: 0), buffer.baseAddress!)
            }
            var descent: CGFloat = 0
            CTLineGetTypographicBounds(lastLine, nil, &descent, nil)
            let lastCharacter = min(text.length - 1, visible.location + visible.length - 1)
            let paragraph = text.attribute(.paragraphStyle, at: lastCharacter, effectiveRange: nil) as? NSParagraphStyle
            cursor = Self.bottom + origins[origins.count - 1].y - descent - max(3, paragraph?.paragraphSpacing ?? 0)
            offset += visible.length
            if offset < text.length { newPage() }
        }
    }

    private func drawLabel(_ text: String, at point: CGPoint, size: CGFloat, color: NSColor) {
        let attributed = NSAttributedString(string: text, attributes: [
            .font: NSFont.systemFont(ofSize: size, weight: .medium), .foregroundColor: color
        ])
        context.saveGState()
        context.textMatrix = .identity
        context.textPosition = point
        CTLineDraw(CTLineCreateWithAttributedString(attributed as CFAttributedString), context)
        context.restoreGState()
    }

    private func endPage() {
        context.setStrokeColor(NSColor(calibratedWhite: 0.88, alpha: 1).cgColor)
        context.setLineWidth(0.5)
        context.move(to: CGPoint(x: Self.margin, y: 47))
        context.addLine(to: CGPoint(x: Self.pageSize.width - Self.margin, y: 47))
        context.strokePath()
        drawLabel("AstraGlass", at: CGPoint(x: Self.margin, y: 30), size: 8, color: Self.muted)
        drawLabel(String(format: "%02d", pageNumber), at: CGPoint(x: Self.pageSize.width - Self.margin - 14, y: 30), size: 8, color: Self.muted)
        context.endPDFPage()
        pageOpen = false
    }

    func finish(at url: URL) throws {
        if pageOpen { endPage() }
        context.closePDF()
        guard data.length > 100 else { throw CocoaError(.fileWriteUnknown) }
        try data.write(to: url, options: .atomic)
    }
}
