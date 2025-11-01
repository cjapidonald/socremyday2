import SwiftUI

enum TimeUnit: String, CaseIterable {
    case minutes = "minutes"
    case hours = "hours"
}

enum Currency: String, CaseIterable {
    case usd = "USD"
    case eur = "EUR"
    case gbp = "GBP"
    case jpy = "JPY"
    case cad = "CAD"
    case aud = "AUD"
    case chf = "CHF"
    case cny = "CNY"
    case inr = "INR"
    case mxn = "MXN"
    case brl = "BRL"
    case krw = "KRW"
    case rub = "RUB"
    case zar = "ZAR"
}

struct AddEditDeedSheet: View {
    @Environment(\.dismiss) private var dismiss

    let initialCard: DeedCard?
    let categorySuggestions: [String]
    let onSave: (DeedCard) -> Void

    @State private var name: String
    @State private var emoji: String
    @State private var color: Color
    @State private var textColor: Color
    @State private var category: String
    @State private var polarity: Polarity
    @State private var unitType: UnitType
    @State private var unitLabel: String
    @State private var pointsPerTapValue: Double
    @State private var isPrivate: Bool
    @State private var showOnStats: Bool

    // New simplified state for tap configuration
    @State private var amountPerTap: Int
    @State private var timeUnit: TimeUnit = .minutes
    @State private var currency: Currency = .usd

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
        _emoji = State(initialValue: initialCard?.emoji ?? "")
        _color = State(initialValue: Color(hex: initialCard?.colorHex ?? "#FF9F0A", fallback: .accentColor))
        _textColor = State(initialValue: Color(hex: initialCard?.textColorHex ?? "#FFFFFF", fallback: .white))
        _category = State(initialValue: initialCard?.category ?? "")
        _polarity = State(initialValue: defaultPolarity)
        _unitType = State(initialValue: defaultUnitType)
        _unitLabel = State(initialValue: initialCard?.unitLabel ?? defaults.label)

        // Initialize points per tap
        let startingPoints: Double
        if let card = initialCard {
            startingPoints = abs(card.pointsPerUnit)
        } else {
            startingPoints = defaults.points
        }
        _pointsPerTapValue = State(initialValue: startingPoints)

        _isPrivate = State(initialValue: initialCard?.isPrivate ?? false)
        _showOnStats = State(initialValue: initialCard?.showOnStats ?? true)

        // Initialize amountPerTap and currency based on existing card or defaults
        if let card = initialCard {
            // Extract the amount from the unit label (e.g., "15 min" -> 15, "10 USD" -> 10)
            let components = card.unitLabel.split(separator: " ")
            if let firstComponent = components.first, let value = Int(firstComponent) {
                _amountPerTap = State(initialValue: value)

                // Detect currency or time unit
                if card.unitType == .duration {
                    _timeUnit = State(initialValue: card.unitLabel.contains("hour") ? .hours : .minutes)
                    _currency = State(initialValue: .usd)
                } else if card.unitType == .amount {
                    // Parse currency from label like "10 USD"
                    if components.count > 1, let curr = Currency.allCases.first(where: { $0.rawValue == String(components[1]) }) {
                        _currency = State(initialValue: curr)
                    } else {
                        _currency = State(initialValue: .usd)
                    }
                    _timeUnit = State(initialValue: .minutes)
                } else {
                    _currency = State(initialValue: .usd)
                    _timeUnit = State(initialValue: .minutes)
                }
            } else {
                _amountPerTap = State(initialValue: 1)
                _currency = State(initialValue: .usd)
                _timeUnit = State(initialValue: .minutes)
            }
        } else {
            // New card defaults
            _amountPerTap = State(initialValue: defaultUnitType == .count ? 1 : defaultUnitType == .amount ? 10 : 15)
            _timeUnit = State(initialValue: .minutes)
            _currency = State(initialValue: .usd)
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

                    ColorPicker("Card Color", selection: $color, supportsOpacity: false)

                    HStack {
                        Text("Text Color")
                        Spacer()
                        Button(action: { textColor = .white }) {
                            Circle()
                                .fill(Color.white)
                                .frame(width: 30, height: 30)
                                .overlay(
                                    Circle()
                                        .stroke(textColor == .white ? Color.blue : Color.gray.opacity(0.3), lineWidth: textColor == .white ? 3 : 1)
                                )
                        }
                        .buttonStyle(.plain)

                        Button(action: { textColor = .black }) {
                            Circle()
                                .fill(Color.black)
                                .frame(width: 30, height: 30)
                                .overlay(
                                    Circle()
                                        .stroke(textColor == .black ? Color.blue : Color.gray.opacity(0.3), lineWidth: textColor == .black ? 3 : 1)
                                )
                        }
                        .buttonStyle(.plain)
                    }
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

                Section {
                    VStack(alignment: .leading, spacing: 16) {
                        // Step 1: Good or Bad Habit
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Is this a good or bad habit?")
                                .font(.subheadline.weight(.medium))

                            Picker("Polarity", selection: $polarity) {
                                Label("Good", systemImage: "plus.circle.fill").tag(Polarity.positive)
                                Label("Bad", systemImage: "minus.circle.fill").tag(Polarity.negative)
                            }
                            .pickerStyle(.segmented)
                        }

                        Divider()

                        // Step 2: What are you tracking?
                        VStack(alignment: .leading, spacing: 8) {
                            Text("What are you tracking?")
                                .font(.subheadline.weight(.medium))

                            Picker("Tracking Type", selection: $unitType) {
                                Text("Count").tag(UnitType.count)
                                Text("Time").tag(UnitType.duration)
                                Text("Money").tag(UnitType.amount)
                            }
                            .pickerStyle(.segmented)
                        }

                        Divider()

                        // Step 3: How much is 1 tap?
                        VStack(alignment: .leading, spacing: 8) {
                            Text("How much is 1 tap?")
                                .font(.subheadline.weight(.medium))

                            if unitType == .count {
                                HStack {
                                    Text("1 tap =")
                                    Picker("Amount", selection: $amountPerTap) {
                                        ForEach(1...100, id: \.self) { num in
                                            Text("\(num)").tag(num)
                                        }
                                    }
                                    .pickerStyle(.wheel)
                                    .frame(width: 100, height: 100)
                                    Text("times")
                                        .foregroundStyle(.secondary)
                                }
                            } else if unitType == .duration {
                                VStack(spacing: 8) {
                                    HStack {
                                        Text("1 tap =")
                                        Picker("Amount", selection: $amountPerTap) {
                                            if timeUnit == .minutes {
                                                ForEach([1, 5, 10, 15, 20, 25, 30, 45, 60, 90, 120], id: \.self) { num in
                                                    Text("\(num)").tag(num)
                                                }
                                            } else {
                                                ForEach(1...24, id: \.self) { num in
                                                    Text("\(num)").tag(num)
                                                }
                                            }
                                        }
                                        .pickerStyle(.wheel)
                                        .frame(width: 100, height: 100)
                                        Picker("Unit", selection: $timeUnit) {
                                            ForEach(TimeUnit.allCases, id: \.self) { unit in
                                                Text(unit.rawValue).tag(unit)
                                            }
                                        }
                                        .pickerStyle(.segmented)
                                    }
                                }
                            } else {
                                // Amount/Money
                                VStack(spacing: 8) {
                                    HStack {
                                        Text("1 tap =")
                                        Picker("Amount", selection: $amountPerTap) {
                                            ForEach([1, 5, 10, 15, 20, 25, 30, 40, 50, 75, 100, 150, 200, 250, 500], id: \.self) { num in
                                                Text("\(num)").tag(num)
                                            }
                                        }
                                        .pickerStyle(.wheel)
                                        .frame(width: 100, height: 100)
                                        Picker("Currency", selection: $currency) {
                                            ForEach(Currency.allCases, id: \.self) { curr in
                                                Text(curr.rawValue).tag(curr)
                                            }
                                        }
                                        .pickerStyle(.wheel)
                                        .frame(width: 100, height: 100)
                                    }
                                }
                            }
                        }

                        Divider()

                        // Step 4: Points per tap
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Points per tap")
                                .font(.subheadline.weight(.medium))

                            HStack {
                                Text(polarity == .positive ? "+" : "−")
                                    .foregroundStyle(polarity == .positive ? .green : .red)
                                    .font(.title3.bold())
                                Picker("Points", selection: $pointsPerTapValue) {
                                    ForEach([0.5, 1, 2, 3, 4, 5, 10, 15, 20, 25, 30, 40, 50, 75, 100], id: \.self) { points in
                                        Text(Self.format(points)).tag(points)
                                    }
                                }
                                .pickerStyle(.wheel)
                                .frame(width: 100, height: 100)
                                Text("points")
                                    .foregroundStyle(.secondary)
                            }

                            if let example = simpleExampleText {
                                Text(example)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .padding(.top, 4)
                            }
                        }
                    }
                    .padding(.vertical, 4)
                } header: {
                    Text("Tracking Setup")
                } footer: {
                    Text("Configure how tapping this deed will work. Each tap will log the amount you set and award points.")
                        .font(.caption)
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
            updateUnitLabel()
        }
        .onChange(of: amountPerTap) { _, _ in
            updateUnitLabel()
        }
        .onChange(of: timeUnit) { _, newValue in
            // Adjust amountPerTap when switching between minutes and hours
            if newValue == .hours && amountPerTap > 24 {
                amountPerTap = 1
            } else if newValue == .minutes && ![1, 5, 10, 15, 20, 25, 30, 45, 60, 90, 120].contains(amountPerTap) {
                amountPerTap = 15
            }
            updateUnitLabel()
        }
        .onChange(of: currency) { _, _ in
            updateUnitLabel()
        }
    }

    private var previewSection: some View {
        Section("Preview") {
            VStack(alignment: .leading, spacing: 12) {
                if !previewModel.category.trimmingCharacters(in: .whitespaces).isEmpty {
                    Text(previewModel.category.uppercased())
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(textColor.opacity(0.7))
                }

                if previewModel.isPrivate {
                    Image(systemName: "eye.slash.fill")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(textColor.opacity(0.7))
                        .frame(maxWidth: .infinity, alignment: .topTrailing)
                }

                Text(previewModel.name.isEmpty ? "Deed Name" : previewModel.name)
                    .font(.headline)
                    .foregroundStyle(textColor)

                Text(previewModel.unitLabel.isEmpty ? Self.placeholderLabel(for: previewModel.unitType) : previewModel.unitLabel)
                    .font(.caption)
                    .foregroundStyle(textColor.opacity(0.7))

                Text(pointsSummary)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(textColor)

                if let cap = previewModel.dailyCap {
                    Text("Daily cap: \(Self.format(cap))")
                        .font(.caption2)
                        .foregroundStyle(textColor.opacity(0.7))
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

    private var previewModel: DeedCard {
        let hex = color.toHex(includeAlpha: false) ?? initialCard?.colorHex ?? "#FF9F0A"
        let textHex = textColor.toHex(includeAlpha: false) ?? initialCard?.textColorHex ?? "#FFFFFF"
        let signedPoints = polarity == .positive ? pointsPerTapValue : -pointsPerTapValue
        return DeedCard(
            id: initialCard?.id ?? UUID(),
            name: name,
            emoji: emoji,
            colorHex: hex,
            textColorHex: textHex,
            category: category,
            polarity: polarity,
            unitType: unitType,
            unitLabel: unitLabel,
            pointsPerUnit: signedPoints,
            dailyCap: nil,
            isPrivate: isPrivate,
            showOnStats: showOnStats,
            createdAt: initialCard?.createdAt ?? Date(),
            isArchived: initialCard?.isArchived ?? false,
            sortOrder: initialCard?.sortOrder ?? -1
        )
    }

    private var pointsSummary: String {
        let value = polarity == .positive ? pointsPerTapValue : -pointsPerTapValue
        let sign = value >= 0 ? "+" : "−"
        let formatted = Self.format(abs(value))
        return "\(sign)\(formatted) per \(unitLabel.isEmpty ? Self.placeholderLabel(for: unitType) : unitLabel)"
    }

    private var simpleExampleText: String? {
        let points = polarity == .positive ? pointsPerTapValue : -pointsPerTapValue
        let taps = 3
        let computed = points * Double(taps)
        guard computed != 0 else { return nil }
        let formattedPoints = formattedPointsValue(computed)
        return "Example: \(taps) taps = \(formattedPoints)"
    }

    private func updateUnitLabel() {
        if unitType == .count {
            if amountPerTap == 1 {
                unitLabel = "times"
            } else {
                unitLabel = "\(amountPerTap) times"
            }
        } else if unitType == .duration {
            // Duration
            if timeUnit == .minutes {
                unitLabel = amountPerTap == 1 ? "1 min" : "\(amountPerTap) min"
            } else {
                unitLabel = amountPerTap == 1 ? "1 hour" : "\(amountPerTap) hours"
            }
        } else {
            // Amount/Money
            unitLabel = "\(amountPerTap) \(currency.rawValue)"
        }
    }

    private var isValid: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
            pointsPerTapValue > 0
    }

    private func handleSave() {
        guard pointsPerTapValue > 0 else { return }
        let colorHex = color.toHex(includeAlpha: false) ?? initialCard?.colorHex ?? "#FF9F0A"
        let textColorHex = textColor.toHex(includeAlpha: false) ?? initialCard?.textColorHex ?? "#FFFFFF"
        let points = polarity == .positive ? pointsPerTapValue : -pointsPerTapValue

        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedCategory = category.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedLabel = unitLabel.trimmingCharacters(in: .whitespacesAndNewlines)
        let card = DeedCard(
            id: initialCard?.id ?? UUID(),
            name: trimmedName,
            emoji: emoji.trimmingCharacters(in: .whitespacesAndNewlines),
            colorHex: colorHex,
            textColorHex: textColorHex,
            category: trimmedCategory,
            polarity: polarity,
            unitType: unitType,
            unitLabel: trimmedLabel,
            pointsPerUnit: points,
            dailyCap: nil,
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

        // Set amount per tap
        if unitType == .count {
            amountPerTap = 1
        } else if unitType == .duration {
            amountPerTap = 15
            timeUnit = .minutes
        } else {
            amountPerTap = 10
            currency = .usd
        }

        unitLabel = defaults.label
        pointsPerTapValue = defaults.points
    }

    private func formatAmount(_ amount: Double) -> String {
        return "\(Int(amount)) \(unitLabel.isEmpty ? Self.placeholderLabel(for: unitType) : unitLabel)"
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
        case .amount: return "USD"
        }
    }

    private static func label(for type: UnitType) -> String {
        switch type {
        case .count: return "Count"
        case .duration: return "Duration"
        case .amount: return "Amount"
        }
    }

    private static func defaults(for type: UnitType) -> (label: String, points: Double, dailyCap: Double?, exampleAmount: Double) {
        switch type {
        case .count:
            return ("times", 5, 10, 3)
        case .duration:
            return ("15 min", 1, 60, 30)
        case .amount:
            return ("10 USD", 0.1, nil, 50)
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
