import Foundation

/// Astrolog IDs remain stable across interface languages and saved settings.
public struct ChartPreferences: Codable, Equatable, Sendable {
    public var enabledObjects: Set<Int>
    public var enabledAspects: Set<Int>
    public init(enabledObjects: Set<Int> = Set(1...10).union([16, 17]), enabledAspects: Set<Int> = Set(1...5)) {
        self.enabledObjects = enabledObjects; self.enabledAspects = enabledAspects
    }
    public static let defaults = ChartPreferences()
    public static let objectIDs = Array(1...21) + [74] // Charon = 74.
    public static let supportedObjectIDs = objectIDs
    public static let majorAspectIDs = Set(1...5)
    public static let minorAspectIDs = Set(6...24)
    public struct AspectDefinition: Identifiable, Sendable {
        public let id: Int
        public let name: String
        public let nameEN: String
        public let angle: Double
        public var nameRU: String { name }
        public var isMajor: Bool { id <= 5 }
    }
    public static let aspectDefinitions: [AspectDefinition] = {
        let names = ["Соединение", "Оппозиция", "Квадрат", "Трин", "Секстиль", "Квинконс", "Полусекстиль", "Полуквадрат", "Полутораквадрат", "Квинтиль", "Биквинтиль", "Полуквинтиль", "Септиль", "Новиль", "Биновиль", "Бисептиль", "Трисептиль", "Квадроновиль", "Тридециль", "Ундециль", "Биундециль", "Триундециль", "Квадроундециль", "Квинтаундециль"]
        let english = ["Conjunction", "Opposition", "Square", "Trine", "Sextile", "Quincunx", "Semisextile", "Semisquare", "Sesquisquare", "Quintile", "Biquintile", "Semiquintile", "Septile", "Novile", "Binovile", "Biseptile", "Triseptile", "Quadranovile", "Tridecile", "Undecile", "Biundecile", "Triundecile", "Quadriundecile", "Quinqueundecile"]
        let angles: [Double] = [0,180,90,120,60,150,30,45,135,72,144,36,360.0/7,40,80,720.0/7,1080.0/7,160,108,360.0/11,720.0/11,1080.0/11,1440.0/11,1800.0/11]
        return names.indices.map { AspectDefinition(id:$0+1, name:names[$0], nameEN:english[$0], angle:angles[$0]) }
    }()
    public var normalized: ChartPreferences {
        ChartPreferences(enabledObjects: enabledObjects.intersection(Self.objectIDs), enabledAspects: enabledAspects.intersection(1...24))
    }
    public func engineArguments(keepPrincipalPlanets: Bool = false) -> [String] {
        let options = normalized
        let objects = keepPrincipalPlanets ? options.enabledObjects.union(1...10) : options.enabledObjects
        let ids = objects.sorted().map(String.init)
        var result = objects.contains(74) ? ["=u8"] : ["_u8"]
        result += ["-R0"] + ids + ["-RT0"] + ids
        result += ["-RA0"] + options.enabledAspects.sorted().map(String.init)
        return result
    }
    public func applying(to snapshot: ChartSnapshot) -> ChartSnapshot {
        let options = normalized
        return ChartSnapshot(engine:snapshot.engine, julianDay:snapshot.julianDay,
            positions:snapshot.positions.filter { options.enabledObjects.contains($0.id) }, houseCusps:snapshot.houseCusps,
            aspects:snapshot.aspects.filter { options.enabledObjects.contains($0.first) && options.enabledObjects.contains($0.second) && options.enabledAspects.contains($0.kind) },
            unavailableObjects:snapshot.unavailableObjects.filter { options.enabledObjects.contains($0) }, rawReport:snapshot.rawReport)
    }
}
