import Foundation

public struct CorpusSource: Codable, Hashable, Sendable, Identifiable {
    public let id: String
    public let fileName: String
    public let title: String
    public let sha256: String
    public let sectionCount: Int
}

public struct InterpretationRecord: Codable, Hashable, Sendable, Identifiable {
    public let id: String
    public let title: String
    public let originalTitle: String
    public let category: String
    public let body: String
    public let source: String
    public let sourceTitle: String
    public let sourceSHA256: String
    public let paragraphStart: Int
    public let paragraphEnd: Int
    public let headingLevel: Int
    public let breadcrumbs: [String]
    public let keywords: [String]
    public let planetIDs: [Int]
    public let signIndices: [Int]
    public let houseNumbers: [Int]
    public let aspectAngle: Double?
    public let bindings: [String]

    public var sourceReference: String {
        "\(sourceTitle) · \(source) · блоки \(paragraphStart)–\(paragraphEnd)"
    }
}

public enum InterpretationError: LocalizedError {
    case missingCorpus
    case invalidCorpus(String)

    public var errorDescription: String? {
        switch self {
        case .missingCorpus:
            return L10n.text("Добавьте библиотеку текстов Подводного в формате interpretations.json. Индекс можно создать из ваших DOCX с помощью импортера проекта.", "Import a Podvodny interpretation library in interpretations.json format. Create the index from your own DOCX files using the project importer.")
        case .invalidCorpus(let detail):
            return L10n.text("Не удалось открыть библиотеку трактовок: ", "Unable to open interpretation library: ") + detail
        }
    }
}

/// Immutable, locally loaded source index. No generated interpretations or network calls.
public struct InterpretationLibrary: Sendable {
    public let records: [InterpretationRecord]
    public let sources: [CorpusSource]
    public var categories: [String] { ["Знаки", "Планеты", "Дома", "Аспекты"] }
    private let index: [String: [Int]]
    private let searchTitles: [String]
    private let searchBodies: [String]

    private struct Corpus: Decodable {
        let schemaVersion: Int
        let sources: [CorpusSource]
        let records: [InterpretationRecord]
    }

    public init(url: URL) throws {
        let size = (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
        guard size < 50_000_000 else { throw InterpretationError.invalidCorpus(L10n.text("Файл превышает 50 МБ.", "The file exceeds 50 MB.")) }
        let corpus: Corpus
        do {
            corpus = try JSONDecoder().decode(Corpus.self, from: Data(contentsOf: url))
        } catch {
            throw InterpretationError.invalidCorpus(error.localizedDescription)
        }
        guard corpus.schemaVersion == 1 else {
            throw InterpretationError.invalidCorpus(L10n.text("Неизвестная версия индекса.", "Unknown index version."))
        }
        guard Set(corpus.records.map(\.id)).count == corpus.records.count else {
            throw InterpretationError.invalidCorpus(L10n.text("Повторяющиеся идентификаторы разделов.", "Duplicate section identifiers."))
        }
        self.records = corpus.records
        self.sources = corpus.sources
        var index: [String: [Int]] = [:]
        for (offset, record) in corpus.records.enumerated() {
            for binding in record.bindings { index[binding, default: []].append(offset) }
        }
        self.index = index
        self.searchTitles = corpus.records.map { Self.normalized($0.title) }
        self.searchBodies = corpus.records.map { Self.normalized($0.body) }
    }

    public static var userCorpusURL: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("AstraGlass", isDirectory: true)
            .appendingPathComponent("interpretations.json")
    }

    public static func loadBundled() throws -> InterpretationLibrary {
        if FileManager.default.fileExists(atPath: userCorpusURL.path) {
            return try InterpretationLibrary(url: userCorpusURL)
        }
        if let url = Bundle.main.url(forResource: "interpretations", withExtension: "json") {
            return try InterpretationLibrary(url: url)
        }
        throw InterpretationError.missingCorpus
    }

    /// Validates before replacing the owner's persistent local index.
    public static func importFile(_ url: URL) throws -> InterpretationLibrary {
        let library = try InterpretationLibrary(url: url)
        let destination = userCorpusURL
        try FileManager.default.createDirectory(at: destination.deletingLastPathComponent(), withIntermediateDirectories: true)
        let data = try Data(contentsOf: url)
        try data.write(to: destination, options: .atomic)
        return library
    }

    public func search(_ query: String, category: String? = nil, limit: Int = 100) -> [InterpretationRecord] {
        guard limit > 0 else { return [] }
        let words = Self.normalized(query).split(whereSeparator: { $0.isWhitespace }).map(String.init)
        if words.isEmpty {
            return Array(records.lazy.filter { category == nil || $0.category == category }.prefix(limit))
        }
        var titleMatches: [InterpretationRecord] = []
        var bodyMatches: [InterpretationRecord] = []
        for i in records.indices where category == nil || records[i].category == category {
            if words.allSatisfy({ searchTitles[i].contains($0) }) {
                titleMatches.append(records[i])
                if titleMatches.count == limit { break }
            } else if bodyMatches.count < limit && words.allSatisfy({ searchTitles[i].contains($0) || searchBodies[i].contains($0) }) {
                bodyMatches.append(records[i])
            }
        }
        return Array((titleMatches + bodyMatches).prefix(limit))
    }

    public func forPlanet(id: Int, sign: Int, house: Int) -> [InterpretationRecord] {
        lookup(["planet-sign:\(id):\(sign)", "planet-house:\(id):\(house)", "planet:\(id)"])
    }

    /// Each endpoint's aspect passage is shown independently, as written by the author.
    /// The supplied books do not contain synthetic two-planet pair interpretations.
    public func forAspect(first: Int, second: Int, angle: Double) -> [InterpretationRecord] {
        let supported = [0, 30, 36, 45, 60, 72, 90, 108, 120, 135, 144, 150, 180]
        guard let exact = supported.first(where: { abs(Double($0) - angle) < 0.01 }) else { return [] }
        return lookup(["aspect-planet:\(exact):\(first)", "aspect-planet:\(exact):\(second)", "aspect:\(exact)"])
    }

    public func forHouse(number: Int, sign: Int) -> [InterpretationRecord] {
        lookup(["house-sign:\(number):\(sign)", "house:\(number)"])
    }

    public func forSign(index: Int) -> [InterpretationRecord] { lookup(["sign:\(index)"]) }

    private func lookup(_ keys: [String]) -> [InterpretationRecord] {
        var seen = Set<String>()
        return keys.flatMap { key in
            (index[key] ?? []).map { records[$0] }.filter { seen.insert($0.id).inserted }
        }
    }

    private static func normalized(_ string: String) -> String {
        string.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "ru_RU"))
    }
}
