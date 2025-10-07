import CoreData
import Foundation

struct DataExportService {
    private let deedsRepository: DeedsRepository
    private let entriesRepository: EntriesRepository

    init(persistenceController: PersistenceController = .shared) {
        let context = persistenceController.viewContext
        deedsRepository = DeedsRepository(context: context)
        entriesRepository = EntriesRepository(context: context)
    }

    func makeJSONExport() throws -> [String: Data] {
        let cards = try deedsRepository.fetchAll(includeArchived: true)
        let entries = try entriesRepository.fetchEntries()

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601

        let cardsData = try encoder.encode(cards.map { ExportableCard(card: $0) })
        let entriesData = try encoder.encode(entries.map { ExportableEntry(entry: $0) })

        return [
            "deed-cards.json": cardsData,
            "deed-entries.json": entriesData
        ]
    }

    func makeCSVExport() throws -> [String: Data] {
        let cards = try deedsRepository.fetchAll(includeArchived: true)
        let entries = try entriesRepository.fetchEntries()

        let cardsCSV = csvString(rows: cards.map { ExportableCard(card: $0, formatter: Self.doubleFormatter) }.map { $0.csvRow }, headers: ExportableCard.csvHeaders)
        let entriesCSV = csvString(rows: entries.map { ExportableEntry(entry: $0, formatter: Self.doubleFormatter) }.map { $0.csvRow }, headers: ExportableEntry.csvHeaders)

        return [
            "deed-cards.csv": Data(cardsCSV.utf8),
            "deed-entries.csv": Data(entriesCSV.utf8)
        ]
    }

    private func csvString(rows: [[String]], headers: [String]) -> String {
        var lines: [String] = []
        lines.append(headers.joined(separator: ","))
        for row in rows {
            lines.append(row.map(Self.escapeForCSV).joined(separator: ","))
        }
        return lines.joined(separator: "\n") + "\n"
    }

    private static func escapeForCSV(_ value: String) -> String {
        let needsEscaping = value.contains(",") || value.contains("\n") || value.contains("\"")
        let escaped = value.replacingOccurrences(of: "\"", with: "\"\"")
        return needsEscaping ? "\"\(escaped)\"" : escaped
    }

    private static let doubleFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 6
        formatter.minimumFractionDigits = 0
        formatter.usesGroupingSeparator = false
        return formatter
    }()
}

private extension DataExportService {
    struct ExportableCard: Encodable {
        let id: UUID
        let name: String
        let emoji: String
        let colorHex: String
        let category: String
        let polarity: String
        let unitType: String
        let unitLabel: String
        let pointsPerUnit: Double
        let dailyCap: Double?
        let isPrivate: Bool
        let showOnStats: Bool
        let createdAt: Date
        let isArchived: Bool

        private let formatter: NumberFormatter

        init(card: DeedCard, formatter: NumberFormatter = DataExportService.doubleFormatter) {
            id = card.id
            name = card.name
            emoji = card.emoji
            colorHex = card.colorHex
            category = card.category
            polarity = card.polarity == .positive ? "positive" : "negative"
            unitType = String(describing: card.unitType)
            unitLabel = card.unitLabel
            pointsPerUnit = card.pointsPerUnit
            dailyCap = card.dailyCap
            isPrivate = card.isPrivate
            showOnStats = card.showOnStats
            createdAt = card.createdAt
            isArchived = card.isArchived
            self.formatter = formatter
        }

        enum CodingKeys: String, CodingKey {
            case id
            case name
            case emoji
            case colorHex
            case category
            case polarity
            case unitType
            case unitLabel
            case pointsPerUnit
            case dailyCap
            case isPrivate
            case showOnStats
            case createdAt
            case isArchived
        }

        var csvRow: [String] {
            [
                id.uuidString,
                name,
                emoji,
                colorHex,
                category,
                polarity,
                unitType,
                unitLabel,
                formatter.string(from: NSNumber(value: pointsPerUnit)) ?? String(pointsPerUnit),
                dailyCap.flatMap { formatter.string(from: NSNumber(value: $0)) } ?? "",
                String(isPrivate),
                String(showOnStats),
                ISO8601DateFormatter.exportFormatter.string(from: createdAt),
                String(isArchived)
            ]
        }

        static let csvHeaders = [
            "id",
            "name",
            "emoji",
            "colorHex",
            "category",
            "polarity",
            "unitType",
            "unitLabel",
            "pointsPerUnit",
            "dailyCap",
            "isPrivate",
            "showOnStats",
            "createdAt",
            "isArchived"
        ]
    }

    struct ExportableEntry: Encodable {
        let id: UUID
        let deedId: UUID
        let timestamp: Date
        let amount: Double
        let computedPoints: Double
        let note: String?

        private let formatter: NumberFormatter

        init(entry: DeedEntry, formatter: NumberFormatter = DataExportService.doubleFormatter) {
            id = entry.id
            deedId = entry.deedId
            timestamp = entry.timestamp
            amount = entry.amount
            computedPoints = entry.computedPoints
            note = entry.note
            self.formatter = formatter
        }

        enum CodingKeys: String, CodingKey {
            case id
            case deedId
            case timestamp
            case amount
            case computedPoints
            case note
        }

        var csvRow: [String] {
            [
                id.uuidString,
                deedId.uuidString,
                ISO8601DateFormatter.exportFormatter.string(from: timestamp),
                formatter.string(from: NSNumber(value: amount)) ?? String(amount),
                formatter.string(from: NSNumber(value: computedPoints)) ?? String(computedPoints),
                note ?? ""
            ]
        }

        static let csvHeaders = [
            "id",
            "deedId",
            "timestamp",
            "amount",
            "computedPoints",
            "note"
        ]
    }
}

private extension ISO8601DateFormatter {
    static let exportFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()
}
