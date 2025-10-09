import SwiftUI

struct AddEditDeedSheet: View {
    @Environment(\.dismiss) private var dismiss

    let initialCard: DeedCard?
    let categorySuggestions: [String]
    let onSave: (DeedCard) -> Void

    @State private var name: String
    @State private var emoji: String
    @State private var color: Color
    @State private var category: String
    @State private var polarity: Polarity
    @State private var unitType: UnitType
    @State private var unitLabel: String
    @State private var pointsPerUnitText: String
    @State private var dailyCapText: String
    @State private var isPrivate: Bool
    @State private var showOnStats: Bool
    @State private var showingSymbolPicker = false

    private let isEditing: Bool

    init(initialCard: DeedCard?, categorySuggestions: [String], onSave: @escaping (DeedCard) -> Void) {
        self.initialCard = initialCard
        self.categorySuggestions = categorySuggestions
        self.onSave = onSave
        self.isEditing = initialCard != nil

        let defaultPolarity = initialCard?.polarity ?? .positive
        let defaultUnitType = initialCard?.unitType ?? .count
        let defaults = Self.defaults(for: defaultUnitType)

        _name = State(initialValue: initialCard?.name ?? "")
        _emoji = State(initialValue: initialCard?.emoji ?? "✨")
        _color = State(initialValue: Color(hex: initialCard?.colorHex ?? "#FF9F0A", fallback: .accentColor))
        _category = State(initialValue: initialCard?.category ?? "")
        _polarity = State(initialValue: defaultPolarity)
        _unitType = State(initialValue: defaultUnitType)
        _unitLabel = State(initialValue: initialCard?.unitLabel ?? defaults.label)
        let startingPoints: Double
        if let card = initialCard {
            startingPoints = card.pointsPerUnit
        } else {
            startingPoints = defaultPolarity == .positive ? defaults.points : -defaults.points
        }
        _pointsPerUnitText = State(initialValue: Self.format(startingPoints))
        if let card = initialCard, let cap = card.dailyCap {
            _dailyCapText = State(initialValue: Self.format(cap))
        } else if let cap = defaults.dailyCap, initialCard == nil {
            _dailyCapText = State(initialValue: Self.format(cap))
        } else {
            _dailyCapText = State(initialValue: "")
        }
        _isPrivate = State(initialValue: initialCard?.isPrivate ?? false)
        _showOnStats = State(initialValue: initialCard?.showOnStats ?? true)

        if defaultUnitType == .boolean {
            if defaultPolarity == .positive {
                _dailyCapText = State(initialValue: Self.format(1))
            } else if initialCard?.dailyCap == nil {
                _dailyCapText = State(initialValue: "")
            }
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                previewSection

                Section("Details") {
                    TextField("Name", text: $name)
                        .textInputAutocapitalization(.words)
                        .disableAutocorrection(true)

                    emojiRow

                    ColorPicker("Color", selection: $color, supportsOpacity: false)
                }

                Section("Category") {
                    TextField("Category", text: $category)
                        .textInputAutocapitalization(.words)
                    if !categorySuggestions.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(categorySuggestions, id: \.self) { suggestion in
                                    Button {
                                        category = suggestion
                                    } label: {
                                        Text(suggestion)
                                            .font(.caption)
                                            .padding(.horizontal, 12)
                                            .padding(.vertical, 6)
                                            .background(
                                                Capsule()
                                                    .fill(category == suggestion ? color.opacity(0.25) : Color.secondary.opacity(0.15))
                                            )
                                            .foregroundStyle(category == suggestion ? color : Color.secondary)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }

                Section("Configuration") {
                    Picker("Polarity", selection: $polarity) {
                        Text("Positive").tag(Polarity.positive)
                        Text("Negative").tag(Polarity.negative)
                    }
                    .pickerStyle(.segmented)

                    Picker("Unit Type", selection: $unitType) {
                        ForEach(UnitType.allCases, id: \.self) { type in
                            Text(Self.label(for: type)).tag(type)
                        }
                    }
                    .pickerStyle(.segmented)

                    if unitType == .boolean {
                        LabeledContent("Unit Label") {
                            Text(unitLabel.isEmpty ? Self.placeholderLabel(for: unitType) : unitLabel)
                                .foregroundStyle(.secondary)
                        }
                    } else {
                        TextField("Unit Label", text: $unitLabel)
                            .textInputAutocapitalization(.never)
                            .disableAutocorrection(true)
                    }

                    TextField("Points per Unit", text: $pointsPerUnitText)
                        .keyboardType(.decimalPad)

                    if let example = exampleText {
                        Text(example)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    if unitType == .boolean && polarity == .positive {
                        LabeledContent("Daily Cap") {
                            Text("1 completion per day")
                                .foregroundStyle(.secondary)
                        }
                    } else {
                        TextField("Daily Cap (optional)", text: $dailyCapText)
                            .keyboardType(.decimalPad)
                    }
                }

                Section("Visibility") {
                    Toggle("Show on Stats Page", isOn: $showOnStats)
                    Toggle("Private", isOn: $isPrivate)
                }
            }
            .navigationTitle(isEditing ? "Edit Deed" : "New Deed")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: handleSave)
                        .disabled(!isValid)
                }
            }
        }
        .onChange(of: unitType) { _, newValue in
            applyDefaults(for: newValue)
        }
        .onChange(of: polarity) { _, newValue in
            syncPointsWithPolarity()
            enforceBooleanDailyCapIfNeeded(force: unitType == .boolean && newValue == .negative)
        }
    }

    private var previewSection: some View {
        Section("Preview") {
            VStack(alignment: .leading, spacing: 12) {
                if !previewModel.category.trimmingCharacters(in: .whitespaces).isEmpty {
                    Text(previewModel.category.uppercased())
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                }

                if previewModel.isPrivate {
                    Image(systemName: "eye.slash.fill")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.white.opacity(0.7))
                        .frame(maxWidth: .infinity, alignment: .topTrailing)
                }

                Text(previewModel.name.isEmpty ? "Deed Name" : previewModel.name)
                    .font(.headline)
                    .foregroundStyle(.white)

                Text(previewModel.unitLabel.isEmpty ? Self.placeholderLabel(for: previewModel.unitType) : previewModel.unitLabel)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.7))

                Text(pointsSummary)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white)

                if previewModel.unitType == .boolean && previewModel.polarity == .positive {
                    Text("Daily cap: 1 completion per day")
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.7))
                } else if let cap = previewModel.dailyCap {
                    Text("Daily cap: \(Self.format(cap))")
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.7))
                }
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(color)
            )
        }
    }

    private var emojiRow: some View {
        // The picker button has been removed. Users can still type emojis.
        TextField("Emoji", text: $emoji)
            .disableAutocorrection(true)
            .textInputAutocapitalization(.never)
    }

    private var previewModel: DeedCard {
        let hex = color.toHex(includeAlpha: false) ?? initialCard?.colorHex ?? "#FF9F0A"
        return DeedCard(
            id: initialCard?.id ?? UUID(),
            name: name,
            emoji: emoji,
            colorHex: hex,
            category: category,
            polarity: polarity,
            unitType: unitType,
            unitLabel: unitLabel,
            pointsPerUnit: pointsPerUnitValue ?? 0,
            dailyCap: dailyCapValue,
            isPrivate: isPrivate,
            showOnStats: showOnStats,
            createdAt: initialCard?.createdAt ?? Date(),
            isArchived: initialCard?.isArchived ?? false,
            sortOrder: initialCard?.sortOrder ?? -1
        )
    }

    private var pointsSummary: String {
        guard let value = signedPointsPerUnit else { return "Points per unit" }
        let sign = value >= 0 ? "+" : "−"
        let formatted = Self.format(abs(value))
        return "\(sign)\(formatted) per \(unitLabel.isEmpty ? Self.placeholderLabel(for: unitType) : unitLabel)"
    }

    private var exampleText: String? {
        guard let points = signedPointsPerUnit else { return nil }
        let amount = Self.defaults(for: unitType).exampleAmount
        let computed = points * amount
        guard computed != 0 else { return nil }
        let amountText = formatAmount(amount)
        let formattedPoints = formattedPointsValue(computed)
        return "Example: \(formattedPoints) for \(amountText)"
    }

    private var pointsPerUnitValue: Double? {
        let sanitized = pointsPerUnitText.replacingOccurrences(of: ",", with: ".")
        return Double(sanitized)
    }

    private var signedPointsPerUnit: Double? {
        guard let value = pointsPerUnitValue else { return nil }
        return polarity == .positive ? abs(value) : -abs(value)
    }

    private var dailyCapValue: Double? {
        if unitType == .boolean && polarity == .positive {
            return 1
        }
        let trimmed = dailyCapText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let sanitized = trimmed.replacingOccurrences(of: ",", with: ".")
        return Double(sanitized)
    }

    private var isValid: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
            (pointsPerUnitValue ?? 0) != 0
    }

    private func handleSave() {
        guard let rawPoints = pointsPerUnitValue, rawPoints != 0 else { return }
        let colorHex = color.toHex(includeAlpha: false) ?? initialCard?.colorHex ?? "#FF9F0A"
        let points = polarity == .positive ? abs(rawPoints) : -abs(rawPoints)

        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedCategory = category.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedLabel = unitLabel.trimmingCharacters(in: .whitespacesAndNewlines)
        let selectedEmoji = emoji.trimmingCharacters(in: .whitespacesAndNewlines)

        let card = DeedCard(
            id: initialCard?.id ?? UUID(),
            name: trimmedName,
            emoji: selectedEmoji.isEmpty ? "✨" : selectedEmoji,
            colorHex: colorHex,
            category: trimmedCategory,
            polarity: polarity,
            unitType: unitType,
            unitLabel: trimmedLabel,
            pointsPerUnit: points,
            dailyCap: dailyCapValue,
            isPrivate: isPrivate,
            showOnStats: showOnStats,
            createdAt: initialCard?.createdAt ?? Date(),
            isArchived: initialCard?.isArchived ?? false,
            sortOrder: initialCard?.sortOrder ?? -1
        )

        onSave(card)
        dismiss()
    }

    private func applyDefaults(for unitType: UnitType) {
        let defaults = Self.defaults(for: unitType)
        unitLabel = defaults.label
        let signedPoints = polarity == .positive ? defaults.points : -defaults.points
        pointsPerUnitText = Self.format(signedPoints)
        if let cap = defaults.dailyCap {
            dailyCapText = Self.format(cap)
        } else {
            dailyCapText = ""
        }
        enforceBooleanDailyCapIfNeeded(force: true)
    }

    private func syncPointsWithPolarity() {
        guard let value = pointsPerUnitValue else { return }
        let magnitude = abs(value)
        let signed = polarity == .positive ? magnitude : -magnitude
        pointsPerUnitText = Self.format(signed)
    }

    private func enforceBooleanDailyCapIfNeeded(force: Bool = false) {
        guard unitType == .boolean else { return }
        if polarity == .positive {
            if force || abs((dailyCapValue ?? 0) - 1) > 0.0001 {
                dailyCapText = Self.format(1)
            }
        } else if force {
            dailyCapText = ""
        }
    }

    private func formatAmount(_ amount: Double) -> String {
        switch unitType {
        case .boolean:
            return unitLabel.isEmpty ? "1 completion" : "1 \(unitLabel)"
        case .count, .rating:
            return "\(Int(amount)) \(unitLabel.isEmpty ? Self.placeholderLabel(for: unitType) : unitLabel)"
        case .duration:
            return "\(Int(amount)) \(unitLabel.isEmpty ? Self.placeholderLabel(for: unitType) : unitLabel)"
        case .quantity:
            let formatted = Self.format(amount)
            return "\(formatted) \(unitLabel.isEmpty ? Self.placeholderLabel(for: unitType) : unitLabel)"
        }
    }

    private func formattedPointsValue(_ value: Double) -> String {
        let sign = value >= 0 ? "+" : "−"
        let formatted = Self.format(abs(value))
        return "\(sign)\(formatted) pts"
    }

    private static func placeholderLabel(for type: UnitType) -> String {
        switch type {
        case .count: return "count"
        case .duration: return "min"
        case .quantity: return "units"
        case .boolean: return "completion"
        case .rating: return "stars"
        }
    }

    private static func label(for type: UnitType) -> String {
        switch type {
        case .count: return "Count"
        case .duration: return "Duration"
        case .quantity: return "Quantity"
        case .boolean: return "Boolean"
        case .rating: return "Rating"
        }
    }

    private static func defaults(for type: UnitType) -> (label: String, points: Double, dailyCap: Double?, exampleAmount: Double) {
        switch type {
        case .count:
            return ("count", 5, 10, 3)
        case .duration:
            return ("min", 1.5, 60, 30)
        case .quantity:
            return ("units", 0.5, nil, 250)
        case .boolean:
            return ("did it", 15, 1, 1)
        case .rating:
            return ("stars", 2, 5, 4)
        }
    }

    private static func format(_ value: Double) -> String {
        if value == floor(value) {
            return String(format: "%.0f", value)
        }
        if abs(value * 10 - round(value * 10)) < 0.0001 {
            return String(format: "%.1f", value)
        }
        return String(format: "%.2f", value)
    }
}

#Preview {
    AddEditDeedSheet(initialCard: nil, categorySuggestions: ["Health", "Learning", "Work"]) { _ in }
}
