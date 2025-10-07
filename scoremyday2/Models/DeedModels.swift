import Foundation

enum UnitType: Int16, CaseIterable, Codable {
    case count
    case duration
    case quantity
    case boolean
    case rating
}

enum Polarity: Int16, CaseIterable, Codable {
    case positive
    case negative
}

struct DeedCard: Identifiable, Equatable {
    var id: UUID
    var name: String
    var emoji: String
    var colorHex: String
    var category: String
    var polarity: Polarity
    var unitType: UnitType
    var unitLabel: String
    var pointsPerUnit: Double
    var dailyCap: Double?
    var isPrivate: Bool
    var showOnStats: Bool
    var createdAt: Date
    var isArchived: Bool

    init(
        id: UUID = UUID(),
        name: String,
        emoji: String,
        colorHex: String,
        category: String,
        polarity: Polarity,
        unitType: UnitType,
        unitLabel: String,
        pointsPerUnit: Double,
        dailyCap: Double?,
        isPrivate: Bool,
        showOnStats: Bool = true,
        createdAt: Date = Date(),
        isArchived: Bool = false
    ) {
        self.id = id
        self.name = name
        self.emoji = emoji
        self.colorHex = colorHex
        self.category = category
        self.polarity = polarity
        self.unitType = unitType
        self.unitLabel = unitLabel
        self.pointsPerUnit = pointsPerUnit
        self.dailyCap = dailyCap
        self.isPrivate = isPrivate
        self.showOnStats = showOnStats
        self.createdAt = createdAt
        self.isArchived = isArchived
    }
}

struct DeedEntry: Identifiable, Equatable {
    var id: UUID
    var deedId: UUID
    var timestamp: Date
    var amount: Double
    var computedPoints: Double
    var note: String?

    init(
        id: UUID = UUID(),
        deedId: UUID,
        timestamp: Date,
        amount: Double,
        computedPoints: Double,
        note: String? = nil
    ) {
        self.id = id
        self.deedId = deedId
        self.timestamp = timestamp
        self.amount = amount
        self.computedPoints = computedPoints
        self.note = note
    }
}

struct AppPrefs: Identifiable, Equatable {
    var id: UUID
    var dayCutoffHour: Int
    var hapticsOn: Bool
    var soundsOn: Bool
    var accentColorHex: String?

    init(
        id: UUID = UUID(),
        dayCutoffHour: Int = 4,
        hapticsOn: Bool = true,
        soundsOn: Bool = true,
        accentColorHex: String? = nil
    ) {
        self.id = id
        self.dayCutoffHour = dayCutoffHour
        self.hapticsOn = hapticsOn
        self.soundsOn = soundsOn
        self.accentColorHex = accentColorHex
    }
}
