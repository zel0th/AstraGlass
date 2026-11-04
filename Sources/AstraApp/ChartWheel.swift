import SwiftUI

/// The snapshot has already been filtered by the user's object/aspect settings.
/// Buttons are separate from the drawing, preserving keyboard/VoiceOver access.
struct ChartWheel: View {
    let snapshot: ChartSnapshot
    let selectedPlanet: Int
    let select: (Int) -> Void
    let selectSign: (Int) -> Void
    let selectAspect: (ChartAspect) -> Void
    let selectHouse: (Int) -> Void
    let selectedAspect: ChartAspect?
    let selectedSign: Int?
    let selectedHouse: Int?
    @Environment(\.colorScheme) private var colorScheme

    init(snapshot: ChartSnapshot, selectedPlanet: Int, select: @escaping (Int) -> Void,
         selectSign: @escaping (Int) -> Void = { _ in },
         selectAspect: @escaping (ChartAspect) -> Void = { _ in },
         selectHouse: @escaping (Int) -> Void = { _ in },
         selectedAspect: ChartAspect? = nil, selectedSign: Int? = nil, selectedHouse: Int? = nil) {
        self.snapshot = snapshot; self.selectedPlanet = selectedPlanet; self.select = select
        self.selectSign = selectSign; self.selectAspect = selectAspect
        self.selectedAspect = selectedAspect; self.selectedSign = selectedSign
        self.selectHouse = selectHouse; self.selectedHouse = selectedHouse
    }

    private var asc: Double { snapshot.houseCusps.first ?? 0 }
    private var visiblePlanets: [PlanetPosition] { snapshot.positions }
    private var positionsByID: [Int: PlanetPosition] {
        Dictionary(snapshot.positions.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
    }
    private var visibleAspects: [ChartAspect] {
        let ids = Set(snapshot.positions.map(\.id))
        return snapshot.aspects.filter { ids.contains($0.first) && ids.contains($0.second) }
    }

    var body: some View {
        GeometryReader { geometry in
            let center = CGPoint(x: geometry.size.width / 2, y: geometry.size.height / 2)
            let diameter = min(geometry.size.width, geometry.size.height)
            let radius = max(1, diameter * 0.452)
            let labelScale = max(0.8, radius / 262)
            let markers = markerPositions(radius: radius, center: center)
            let conjunctions = ChartWheelGeometry.conjunctionMarkers(aspects: visibleAspects, positions: positionsByID, asc: asc, radius: radius, center: center)
            ZStack {
                Canvas { context, _ in
                    drawWheel(context: &context, center: center, radius: radius, markers: markers, conjunctions: conjunctions)
                }.allowsHitTesting(false).accessibilityHidden(true)

                // Reuse the painted annulus for hit testing. Later layers keep
                // planets, signs and aspects independently selectable.
                ForEach(snapshot.houseCusps.indices, id: \.self) { index in
                    let sector = ChartWheelGeometry.houseSector(
                        start: snapshot.houseCusps[index],
                        end: snapshot.houseCusps[(index + 1) % snapshot.houseCusps.count],
                        asc: asc, radius: radius, center: center)
                    Button { selectHouse(index + 1) } label: {
                        sector.fill(Color.clear)
                            .frame(width: geometry.size.width, height: geometry.size.height)
                            .contentShape(sector)
                    }
                    .buttonStyle(.plain)
                    .help(L10n.text("Трактовка \(index + 1) дома", "House \(index + 1) interpretation"))
                    .accessibilityLabel(L10n.text("Дом \(index + 1)", "House \(index + 1)"))
                    .accessibilityHint(L10n.text("Открыть описание дома", "Open the house description"))
                    .accessibilityAddTraits(selectedHouse == index + 1 ? .isSelected : [])
                }

                // A generous transparent corridor follows each real aspect line.
                // Its button is also independently reachable with accessibility.
                ForEach(visibleAspects.filter { abs($0.angle) >= 0.01 }) { aspect in
                    if let pair = aspectEndpoints(aspect, radius: radius, center: center) {
                        let frame = segmentFrame(pair.0, pair.1)
                        let start = CGPoint(x: pair.0.x - frame.minX, y: pair.0.y - frame.minY)
                        let end = CGPoint(x: pair.1.x - frame.minX, y: pair.1.y - frame.minY)
                        Button { selectAspect(aspect) } label: {
                            AspectHitShape(start: start, end: end)
                                .fill(Color.clear)
                                .frame(width: frame.width, height: frame.height)
                                .contentShape(AspectHitShape(start: start, end: end))
                        }
                        .buttonStyle(.plain)
                        .position(x: frame.midX, y: frame.midY)
                        .help(aspectDescription(aspect))
                        .accessibilityLabel(aspectDescription(aspect))
                        .accessibilityHint(L10n.text("Открыть трактовку аспекта", "Open the aspect interpretation"))
                    }
                }

                ForEach(visibleAspects.filter { abs($0.angle) < 0.01 }) { aspect in
                    if let location = conjunctions[aspect.id] {
                        Button { selectAspect(aspect) } label: {
                            Text(AstroStyle.aspectGlyph(aspect.angle))
                                .font(AstroStyle.symbolFont(size: 17 * labelScale))
                                .foregroundStyle(AstroStyle.aspectColor(aspect.angle))
                                .frame(width: 24 * labelScale, height: 24 * labelScale)
                                .background(.background, in: Circle())
                                .background(AstroStyle.aspectColor(aspect.angle).opacity(0.12), in: Circle())
                                .overlay(Circle().strokeBorder(AstroStyle.aspectColor(aspect.angle).opacity(selectedAspect?.id == aspect.id ? 1 : 0.45), lineWidth: selectedAspect?.id == aspect.id ? 2 : 1))
                                .contentShape(Circle())
                        }.buttonStyle(.plain).position(location)
                            .help(aspectDescription(aspect))
                            .accessibilityLabel(aspectDescription(aspect))
                            .accessibilityHint(L10n.text("Открыть трактовку соединения", "Open the conjunction interpretation"))
                    }
                }

                ForEach(0..<12, id: \.self) { sign in
                    Button { selectSign(sign) } label: {
                        Text(AstroStyle.signGlyphs[sign])
                            .font(AstroStyle.symbolFont(size: max(17, radius * 0.09)))
                            .foregroundStyle(AstroStyle.elementColors[sign % 4])
                            .frame(width: max(26, radius * 0.13), height: max(26, radius * 0.13))
                            .background(selectedSign == sign ? AstroStyle.accent.opacity(0.14) : Color.clear, in: Circle())
                            .contentShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .position(point(Double(sign * 30 + 15), radius: radius * 0.925, center: center))
                    .help(AstroStyle.signNames[sign])
                    .accessibilityLabel(AstroStyle.signNames[sign])
                    .accessibilityHint(L10n.text("Открыть описание знака", "Open the zodiac sign description"))
                }

                ForEach(visiblePlanets) { planet in
                    Button { select(planet.id) } label: {
                        VStack(spacing: 0) {
                            Text(AstroStyle.glyph(planet.id)).font(AstroStyle.symbolFont(size: 25 * labelScale))
                            Text("\(Int(planet.degreeInSign))°" + (planet.isRetrograde ? " ℞" : ""))
                                .font(.system(size: 8 * labelScale, weight: .medium))
                        }
                        .foregroundStyle(AstroStyle.objectColor(planet.id))
                        .frame(width: 32 * labelScale, height: 38 * labelScale)
                        .background(planet.id == selectedPlanet ? AstroStyle.objectColor(planet.id).opacity(0.14) : Color.clear, in: RoundedRectangle(cornerRadius: 9))
                        .overlay(RoundedRectangle(cornerRadius: 9).strokeBorder(planet.id == selectedPlanet ? AstroStyle.objectColor(planet.id).opacity(0.7) : .clear, lineWidth: 1))
                        .contentShape(RoundedRectangle(cornerRadius: 9))
                    }
                    .buttonStyle(.plain)
                    .position(markers[planet.id] ?? point(planet.longitude, radius: radius * 0.76, center: center))
                    .help(planetDescription(planet))
                    .accessibilityLabel(planetDescription(planet))
                    .accessibilityHint(L10n.text("Открыть трактовку планеты", "Open the object interpretation"))
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(L10n.text("Зодиакальный круг", "Zodiac chart"))
    }

    private func drawWheel(context: inout GraphicsContext, center: CGPoint, radius: CGFloat, markers: [Int: CGPoint], conjunctions: [String: CGPoint]) {
        let labelScale = max(0.8, radius / 262)
        let ink = Color.primary.opacity(colorScheme == .dark ? 0.22 : 0.14)
        for (index, cusp) in snapshot.houseCusps.enumerated() {
            let next = snapshot.houseCusps[(index + 1) % snapshot.houseCusps.count]
            let sector = ChartWheelGeometry.houseSector(start: cusp, end: next, asc: asc, radius: radius, center: center)
            // Natural house elements: 1/5/9 fire, 2/6/10 earth,
            // 3/7/11 air, 4/8/12 water, independent of the cusp's sign.
            let selected = selectedHouse == index + 1
            context.fill(sector, with: .color(AstroStyle.elementColors[index % 4].opacity(selected ? 0.22 : colorScheme == .dark ? 0.09 : 0.07)))
            if selected {
                context.stroke(sector, with: .color(AstroStyle.elementColors[index % 4].opacity(0.65)), lineWidth: 1.4)
            }
        }
        for scale in [1.0, 0.85, 0.56] {
            let r = radius * scale
            context.stroke(Path(ellipseIn: CGRect(x: center.x-r, y: center.y-r, width: 2*r, height: 2*r)), with: .color(ink), lineWidth: scale == 1 ? 1.3 : 0.7)
        }
        for degree in stride(from: 0, to: 360, by: 5) {
            let p1 = point(Double(degree), radius: radius * (degree % 30 == 0 ? 0.85 : degree % 10 == 0 ? 0.97 : 0.985), center: center)
            let p2 = point(Double(degree), radius: radius, center: center)
            var path = Path(); path.move(to: p1); path.addLine(to: p2)
            context.stroke(path, with: .color(ink), lineWidth: degree % 30 == 0 ? 1 : 0.6)
        }
        for (index, cusp) in snapshot.houseCusps.enumerated() {
            var path = Path()
            path.move(to: point(cusp, radius: radius * 0.56, center: center))
            path.addLine(to: point(cusp, radius: radius * 0.85, center: center))
            context.stroke(path, with: .color(ink), lineWidth: index % 3 == 0 ? 1.3 : 0.7)
            let next = snapshot.houseCusps[(index + 1) % snapshot.houseCusps.count]
            let middle = cusp + ((next - cusp + 360).truncatingRemainder(dividingBy: 360)) / 2
            context.draw(Text("\(index + 1)").font(.system(size: 9 * labelScale, weight: selectedHouse == index + 1 ? .bold : .regular)).foregroundStyle(selectedHouse == index + 1 ? AstroStyle.elementColors[index % 4] : .secondary), at: point(middle, radius: radius * 0.58, center: center))
        }
        for aspect in visibleAspects {
            guard let pair = aspectEndpoints(aspect, radius: radius, center: center) else { continue }
            let selected = selectedAspect?.id == aspect.id
            let highlighted = selected || selectedPlanet == 0 || aspect.first == selectedPlanet || aspect.second == selectedPlanet
            var path = Path(); path.move(to: pair.0); path.addLine(to: pair.1)
            if let badge = conjunctions[aspect.id], let first = positionsByID[aspect.first], let second = positionsByID[aspect.second] {
                path.move(to: point(ChartWheelGeometry.midpoint(first.longitude, second.longitude), radius: radius * 0.55, center: center))
                path.addLine(to: badge)
            }
            context.stroke(path, with: .color(AstroStyle.aspectColor(aspect.angle).opacity(selected ? 1 : highlighted ? 0.65 : 0.20)), style: StrokeStyle(lineWidth: selected ? 2.8 : highlighted ? 1.3 : 0.8, dash: Int(aspect.angle) == 180 ? [4, 3] : []))
        }
        for (label, longitude) in [("ASC", asc), ("DSC", asc + 180)] {
            context.draw(Text(label).font(.system(size: 9 * labelScale, weight: .bold)).foregroundStyle(AstroStyle.accent), at: point(longitude, radius: radius + 15 * labelScale, center: center))
        }
        if snapshot.houseCusps.indices.contains(9) {
            let mc = snapshot.houseCusps[9]
            for (label, longitude) in [("MC", mc), ("IC", mc + 180)] {
                context.draw(Text(label).font(.system(size: 9 * labelScale, weight: .bold)).foregroundStyle(AstroStyle.accent), at: point(longitude, radius: radius + 13 * labelScale, center: center))
            }
        }
        for planet in visiblePlanets {
            let pointOnRing = point(planet.longitude, radius: radius * 0.85, center: center)
            if let marker = markers[planet.id] {
                var leader = Path(); leader.move(to: pointOnRing); leader.addLine(to: marker)
                context.stroke(leader, with: .color(AstroStyle.objectColor(planet.id).opacity(0.4)), lineWidth: 0.6)
            }
            context.fill(Path(ellipseIn: CGRect(x: pointOnRing.x-2, y: pointOnRing.y-2, width: 4, height: 4)), with: .color(AstroStyle.objectColor(planet.id)))
        }
    }

    private func point(_ longitude: Double, radius: CGFloat, center: CGPoint) -> CGPoint {
        ChartWheelGeometry.point(longitude, asc: asc, radius: radius, center: center)
    }

    /// Keep labels apart when extra points or a tight conjunction are enabled.
    /// Leader lines preserve the exact calculated longitude on the outer ring.
    private func markerPositions(radius: CGFloat, center: CGPoint) -> [Int: CGPoint] {
        var placed: [Int: CGPoint] = [:]
        for planet in visiblePlanets.sorted(by: { $0.longitude == $1.longitude ? $0.id < $1.id : $0.longitude < $1.longitude }) {
            var candidates: [CGPoint] = []
            for shift in [0.0, 4, -4, 8, -8, 12, -12, 16, -16] {
                for lane in [0.76, 0.66] {
                    candidates.append(point(planet.longitude + shift, radius: radius * lane, center: center))
                }
            }
            let chosen = candidates.first { candidate in
                placed.values.allSatisfy { hypot($0.x - candidate.x, $0.y - candidate.y) >= 36 * max(0.8, radius / 262) }
            } ?? candidates.max { a, b in
                minimumDistance(a, to: Array(placed.values)) < minimumDistance(b, to: Array(placed.values))
            } ?? point(planet.longitude, radius: radius * 0.76, center: center)
            placed[planet.id] = chosen
        }
        return placed
    }

    private func minimumDistance(_ point: CGPoint, to others: [CGPoint]) -> CGFloat {
        others.map { hypot($0.x - point.x, $0.y - point.y) }.min() ?? .greatestFiniteMagnitude
    }
    private func aspectEndpoints(_ aspect: ChartAspect, radius: CGFloat, center: CGPoint) -> (CGPoint, CGPoint)? {
        guard let first = positionsByID[aspect.first], let second = positionsByID[aspect.second] else { return nil }
        return (point(first.longitude, radius: radius * 0.55, center: center), point(second.longitude, radius: radius * 0.55, center: center))
    }
    private func segmentFrame(_ first: CGPoint, _ second: CGPoint) -> CGRect {
        CGRect(x: min(first.x, second.x) - 7, y: min(first.y, second.y) - 7,
               width: abs(first.x - second.x) + 14, height: abs(first.y - second.y) + 14)
    }
    private func aspectDescription(_ aspect: ChartAspect) -> String {
        "\(AstroStyle.name(aspect.first)) · \(AstroStyle.aspectName(aspect.angle)) · \(AstroStyle.name(aspect.second))"
    }
    private func planetDescription(_ planet: PlanetPosition) -> String {
        "\(AstroStyle.name(planet.id)) · \(AstroStyle.signNames[planet.sign]) \(AstroStyle.position(planet.longitude)) · " + L10n.text("дом", "house") + " \(planet.house)"
    }
}

private struct AspectHitShape: Shape {
    let start: CGPoint
    let end: CGPoint
    func path(in rect: CGRect) -> Path {
        if hypot(end.x-start.x, end.y-start.y) < 2 {
            return Path(ellipseIn: CGRect(x: start.x-7, y: start.y-7, width: 14, height: 14))
        }
        var path = Path(); path.move(to: start); path.addLine(to: end)
        return path.strokedPath(StrokeStyle(lineWidth: 14, lineCap: .round))
    }
}
