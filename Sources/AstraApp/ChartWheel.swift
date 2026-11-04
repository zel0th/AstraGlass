import SwiftUI

/// The snapshot has already been filtered by the user's object/aspect settings.
/// Buttons are separate from the drawing, preserving keyboard/VoiceOver access.
struct ChartWheel: View {
    let snapshot: ChartSnapshot
    let secondarySnapshot: ChartSnapshot?
    let comparisonAspects: [ChartAspect]
    let selectedSecondaryPlanet: Int?
    let selectSecondary: (Int) -> Void
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
         selectedAspect: ChartAspect? = nil, selectedSign: Int? = nil, selectedHouse: Int? = nil,
         secondarySnapshot: ChartSnapshot? = nil, comparisonAspects: [ChartAspect] = [],
         selectedSecondaryPlanet: Int? = nil, selectSecondary: @escaping (Int) -> Void = { _ in }) {
        self.secondarySnapshot = secondarySnapshot; self.comparisonAspects = comparisonAspects
        self.selectedSecondaryPlanet = selectedSecondaryPlanet; self.selectSecondary = selectSecondary
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
    private var secondaryPositions: [Int: PlanetPosition]? {
        secondarySnapshot.map { Dictionary($0.positions.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first }) }
    }
    private var isComparison: Bool { secondarySnapshot != nil }
    private var aspectRadius: CGFloat { isComparison ? 0.29 : 0.43 }
    private var visibleAspects: [ChartAspect] {
        if isComparison { return comparisonAspects }
        let ids = Set(snapshot.positions.map(\.id))
        return snapshot.aspects.filter { ids.contains($0.first) && ids.contains($0.second) }
    }

    var body: some View {
        GeometryReader { geometry in
            let center = CGPoint(x: geometry.size.width / 2, y: geometry.size.height / 2)
            let diameter = min(geometry.size.width, geometry.size.height)
            let radius = max(1, diameter * 0.452)
            let labelScale = max(0.8, radius / 262)
            let markers = ChartWheelGeometry.planetMarkers(positions: visiblePlanets, asc: asc, radius: radius, center: center, comparison: isComparison)
            let secondaryMarkers = ChartWheelGeometry.planetMarkers(positions: secondarySnapshot?.positions ?? [], asc: asc, radius: radius, center: center, secondary: true, comparison: isComparison)
            let conjunctions = ChartWheelGeometry.conjunctionMarkers(aspects: visibleAspects, positions: positionsByID, asc: asc, radius: radius, center: center, secondaryPositions: secondaryPositions)
            ZStack {
                Canvas { context, _ in
                    drawWheel(context: &context, center: center, radius: radius, markers: markers, secondaryMarkers: secondaryMarkers, conjunctions: conjunctions)
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

                planetButtons(visiblePlanets, markers: markers, labelScale: labelScale, secondary: false)
                if let secondarySnapshot {
                    planetButtons(secondarySnapshot.positions, markers: secondaryMarkers, labelScale: labelScale, secondary: true)
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(L10n.text("Зодиакальный круг", "Zodiac chart"))
    }

    private func drawWheel(context: inout GraphicsContext, center: CGPoint, radius: CGFloat, markers: [Int: CGPoint], secondaryMarkers: [Int: CGPoint], conjunctions: [String: CGPoint]) {
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
        for scale in [1.0, ChartWheelGeometry.zodiacInner, ChartWheelGeometry.houseOuter, ChartWheelGeometry.houseInner] {
            let r = radius * scale
            context.stroke(Path(ellipseIn: CGRect(x: center.x-r, y: center.y-r, width: 2*r, height: 2*r)), with: .color(ink), lineWidth: scale == 1 ? 1.3 : 0.7)
        }
        // A separate 360-degree scale between the zodiac and houses.
        for degree in 0..<360 {
            let length: CGFloat = degree % 10 == 0 ? 0.055 : degree % 5 == 0 ? 0.032 : 0.016
            var tick = Path()
            tick.move(to: point(Double(degree), radius: radius * (ChartWheelGeometry.zodiacInner - length), center: center))
            tick.addLine(to: point(Double(degree), radius: radius * ChartWheelGeometry.zodiacInner, center: center))
            context.stroke(tick, with: .color(ink.opacity(degree % 5 == 0 ? 1 : 0.65)), lineWidth: degree % 10 == 0 ? 0.9 : 0.5)
            if degree % 30 == 0 {
                var boundary = Path()
                boundary.move(to: point(Double(degree), radius: radius * ChartWheelGeometry.zodiacInner, center: center))
                boundary.addLine(to: point(Double(degree), radius: radius, center: center))
                context.stroke(boundary, with: .color(ink), lineWidth: 0.8)
            }
        }
        for (index, cusp) in snapshot.houseCusps.enumerated() {
            var path = Path()
            path.move(to: point(cusp, radius: radius * ChartWheelGeometry.houseInner, center: center))
            path.addLine(to: point(cusp, radius: radius * ChartWheelGeometry.houseOuter, center: center))
            context.stroke(path, with: .color(ink), lineWidth: index % 3 == 0 ? 1.3 : 0.7)
            let next = snapshot.houseCusps[(index + 1) % snapshot.houseCusps.count]
            let middle = ChartWheelGeometry.houseMidpoint(cusp, next)
            context.draw(Text("\(index + 1)").font(.system(size: 10 * labelScale, weight: selectedHouse == index + 1 ? .bold : .regular)).foregroundStyle(selectedHouse == index + 1 ? AstroStyle.elementColors[index % 4] : .secondary), at: point(middle, radius: radius * ChartWheelGeometry.houseMiddle, center: center))
        }
        for aspect in visibleAspects {
            guard let pair = aspectEndpoints(aspect, radius: radius, center: center) else { continue }
            let selected = selectedAspect?.id == aspect.id
            let highlighted = selected || (selectedPlanet == 0 && selectedSecondaryPlanet == nil) || aspect.first == selectedPlanet
                || (isComparison ? aspect.second == selectedSecondaryPlanet : aspect.second == selectedPlanet)
            var path = Path(); path.move(to: pair.0); path.addLine(to: pair.1)
            if let badge = conjunctions[aspect.id], let first = positionsByID[aspect.first], let second = (secondaryPositions ?? positionsByID)[aspect.second] {
                path.move(to: point(ChartWheelGeometry.midpoint(first.longitude, second.longitude), radius: radius * aspectRadius, center: center))
                path.addLine(to: badge)
            }
            let opacity = selected ? 1.0 : isComparison && selectedPlanet == 0 && selectedSecondaryPlanet == nil ? (selectedAspect == nil ? 0.38 : 0.16) : highlighted ? 0.65 : 0.20
            context.stroke(path, with: .color(AstroStyle.aspectColor(aspect.angle).opacity(opacity)), style: StrokeStyle(lineWidth: selected ? 2.8 : highlighted ? 1.3 : 0.8, dash: Int(aspect.angle) == 180 ? [4, 3] : []))
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
        drawLeaders(context: &context, planets: visiblePlanets, markers: markers, radius: radius, center: center, secondary: false)
        if let secondarySnapshot {
            drawLeaders(context: &context, planets: secondarySnapshot.positions, markers: secondaryMarkers, radius: radius, center: center, secondary: true)
        }
    }

    private func point(_ longitude: Double, radius: CGFloat, center: CGPoint) -> CGPoint {
        ChartWheelGeometry.point(longitude, asc: asc, radius: radius, center: center)
    }

    private func drawLeaders(context: inout GraphicsContext, planets: [PlanetPosition], markers: [Int: CGPoint], radius: CGFloat, center: CGPoint, secondary: Bool) {
        for planet in planets {
            // Use the exact aspect vertex, including when a crowded glyph is displaced.
            let anchor = point(planet.longitude, radius: radius * aspectRadius, center: center)
            if let marker = markers[planet.id] {
                var leader = Path(); leader.move(to: anchor); leader.addLine(to: marker)
                context.stroke(leader, with: .color(AstroStyle.objectColor(planet.id).opacity(0.45)), style: StrokeStyle(lineWidth: 0.6, dash: secondary ? [2, 2] : []))
            }
            let dot = Path(ellipseIn: CGRect(x: anchor.x-1.7, y: anchor.y-1.7, width: 3.4, height: 3.4))
            if secondary { context.stroke(dot, with: .color(AstroStyle.objectColor(planet.id)), lineWidth: 0.8) }
            else { context.fill(dot, with: .color(AstroStyle.objectColor(planet.id))) }
        }
    }

    private func planetButtons(_ planets: [PlanetPosition], markers: [Int: CGPoint], labelScale: CGFloat, secondary: Bool) -> some View {
        ForEach(planets) { planet in
            let selected = secondary ? selectedSecondaryPlanet == planet.id : selectedPlanet == planet.id
            Button { if secondary { selectSecondary(planet.id) } else { select(planet.id) } } label: {
                Text(AstroStyle.glyph(planet.id))
                    .font(AstroStyle.symbolFont(size: (isComparison ? 16 : 22) * labelScale))
                    .overlay(alignment: .bottomTrailing) {
                        if planet.isRetrograde {
                            Text("℞")
                                .font(.system(size: (isComparison ? 7 : 8) * labelScale, weight: .medium))
                                .offset(x: 5 * labelScale, y: 2 * labelScale)
                        }
                    }
                .foregroundStyle(AstroStyle.objectColor(planet.id))
                .frame(width: (isComparison ? 22 : 32) * labelScale, height: (isComparison ? 24 : 32) * labelScale)
                .background(.background.opacity(0.85), in: RoundedRectangle(cornerRadius: 7))
                .background(selected ? AstroStyle.objectColor(planet.id).opacity(0.18) : .clear, in: RoundedRectangle(cornerRadius: 7))
                .overlay(RoundedRectangle(cornerRadius: 7).strokeBorder(AstroStyle.objectColor(planet.id).opacity(selected ? 0.9 : secondary ? 0.35 : 0), style: StrokeStyle(lineWidth: selected ? 1.5 : 0.7, dash: secondary ? [2, 2] : [])))
                .contentShape(RoundedRectangle(cornerRadius: 7))
            }
            .buttonStyle(.plain)
            .position(markers[planet.id] ?? .zero)
            .help(planetDescription(planet, secondary: secondary))
            .accessibilityLabel(planetDescription(planet, secondary: secondary))
            .accessibilityHint(L10n.text("Открыть трактовку планеты", "Open the object interpretation"))
        }
    }

    private func aspectEndpoints(_ aspect: ChartAspect, radius: CGFloat, center: CGPoint) -> (CGPoint, CGPoint)? {
        guard let first = positionsByID[aspect.first], let second = (secondaryPositions ?? positionsByID)[aspect.second] else { return nil }
        return (point(first.longitude, radius: radius * aspectRadius, center: center), point(second.longitude, radius: radius * aspectRadius, center: center))
    }
    private func segmentFrame(_ first: CGPoint, _ second: CGPoint) -> CGRect {
        CGRect(x: min(first.x, second.x) - 7, y: min(first.y, second.y) - 7,
               width: abs(first.x - second.x) + 14, height: abs(first.y - second.y) + 14)
    }
    private func aspectDescription(_ aspect: ChartAspect) -> String {
        (isComparison ? "① " : "") + "\(AstroStyle.name(aspect.first)) · \(AstroStyle.aspectName(aspect.angle)) · \(isComparison ? "② " : "")\(AstroStyle.name(aspect.second))"
    }
    private func planetDescription(_ planet: PlanetPosition, secondary: Bool = false) -> String {
        (isComparison ? (secondary ? "② " : "① ") : "") + "\(AstroStyle.name(planet.id)) · \(AstroStyle.signNames[planet.sign]) \(AstroStyle.position(planet.longitude)) · " + L10n.text("дом", "house") + " \(planet.house)"
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
