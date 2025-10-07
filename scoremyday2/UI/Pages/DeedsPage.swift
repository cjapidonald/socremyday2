import AVFoundation
import SwiftUI
import UIKit

struct DeedsPage: View {
    @EnvironmentObject private var appEnvironment: AppEnvironment
    @StateObject private var viewModel = DeedsPageViewModel()

    @State private var quickAddState: QuickAddState?
    @State private var floatingDeltas: [FloatingDelta] = []
    @State private var sparkleBursts: [SparkleBurst] = []
    @State private var cardFrames: [UUID: CGRect] = [:]
    @State private var headerFrame: CGRect = .zero
    @State private var deedEditorState: DeedEditorState?

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .top) {
                LiquidBackgroundView()
                    .ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 28) {
                        headerView
                            .padding(.top, 32)
                            .anchorPreference(key: HeaderFramePreferenceKey.self, value: .bounds) { $0 }

                        cardsGrid
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 80)
                }

                ForEach(floatingDeltas) { delta in
                    FloatingDeltaView(delta: delta)
                }

                ForEach(sparkleBursts) { burst in
                    SparkleBurstView(burst: burst)
                }
            }
            .onPreferenceChange(CardFramePreferenceKey.self) { anchors in
                var updated: [UUID: CGRect] = [:]
                for (id, anchor) in anchors {
                    updated[id] = proxy[anchor]
                }
                cardFrames = updated
            }
            .onPreferenceChange(HeaderFramePreferenceKey.self) { anchor in
                if let anchor {
                    headerFrame = proxy[anchor]
                }
            }
        }
        .onAppear { viewModel.onAppear() }
        .sheet(item: $quickAddState) { state in
            QuickAddSheet(state: state, onSave: { updated in
                if let entry = viewModel.log(cardID: updated.card.id, amount: updated.amount, note: updated.note.isEmpty ? nil : updated.note) {
                    handleFeedback(for: updated.card.card.polarity, points: entry.computedPoints, cardID: updated.card.id, startFrameOverride: cardFrames[updated.card.id])
                }
            }) {
                quickAddState = nil
            }
        }
        .sheet(item: $viewModel.pendingRatingCard) { card in
            RatingPickerSheet(card: card) { rating in
                if let entry = viewModel.confirmRatingSelection(rating) {
                    handleFeedback(for: card.card.polarity, points: entry.computedPoints, cardID: card.id)
                }
            }
        }
        .sheet(item: $deedEditorState, onDismiss: { deedEditorState = nil }) { state in
            AddEditDeedSheet(
                initialCard: state.card,
                categorySuggestions: viewModel.categorySuggestions,
                onSave: { card in
                    viewModel.upsert(card: card)
                }
            )
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
        }
    }

    private var headerView: some View {
        HStack(alignment: .center, spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                Text("TODAY")
                    .font(.caption.weight(.semibold))
                    .textCase(.uppercase)
                    .foregroundColor(.white.opacity(0.7))

                Text(formattedPoints(viewModel.todayNetScore))
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)

                Text("resets at \(formattedCutoffHour())")
                    .font(.caption2)
                    .foregroundColor(.white.opacity(0.7))
            }

            Spacer()

            SparklineView(values: viewModel.sparklineValues)
                .frame(width: 120, height: 36)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 18)
        .background(.ultraThinMaterial.opacity(0.75))
        .clipShape(Capsule())
        .overlay(
            Capsule()
                .stroke(Color.white.opacity(0.18), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.2), radius: 14, x: 0, y: 12)
    }

    private var cardsGrid: some View {
        let columns = Array(repeating: GridItem(.flexible(), spacing: 14, alignment: .top), count: 5)
        return LazyVGrid(columns: columns, spacing: 14) {
            ForEach(viewModel.cards) { card in
                DeedCardTile(state: card) {
                    handleTap(on: card)
                } onQuickAdd: {
                    quickAddState = QuickAddState(
                        card: card,
                        amount: viewModel.defaultAmount(for: card),
                        note: ""
                    )
                } onEdit: {
                    deedEditorState = DeedEditorState(card: card.card)
                }
                .anchorPreference(key: CardFramePreferenceKey.self, value: .bounds) { [card.id: $0] }
            }

            AddCardTile {
                deedEditorState = DeedEditorState(card: nil)
            }
        }
    }

    private func handleTap(on card: DeedsPageViewModel.CardState) {
        let startFrame = cardFrames[card.id]
        if let entry = viewModel.prepareTap(on: card) {
            handleFeedback(for: card.card.polarity, points: entry.computedPoints, cardID: card.id, startFrameOverride: startFrame)
        }
    }

    private func handleFeedback(for polarity: Polarity, points: Double, cardID: UUID, startFrameOverride: CGRect? = nil) {
        if appEnvironment.settings.hapticsEnabled {
            FeedbackManager.shared.emitHaptic(for: polarity)
        }

        if appEnvironment.settings.soundsEnabled {
            FeedbackManager.shared.playSound(for: polarity)
        }

        if points != 0 {
            enqueueFloatingDelta(points: points, cardID: cardID, polarity: polarity, startFrameOverride: startFrameOverride)
        }

        if polarity == .positive, let card = viewModel.cards.first(where: { $0.id == cardID }) {
            handleSparkle(for: card, startFrame: startFrameOverride)
        }
    }

    private func enqueueFloatingDelta(points: Double, cardID: UUID, polarity: Polarity, startFrameOverride: CGRect? = nil) {
        guard !headerFrame.isEmpty else { return }
        let headerRect = headerFrame
        guard let startRect = startFrameOverride ?? cardFrames[cardID] else { return }
        let start = CGPoint(x: startRect.midX, y: startRect.midY)
        let end = CGPoint(x: headerRect.midX, y: headerRect.midY)
        let accent = viewModel.cards.first(where: { $0.id == cardID })?.accentColor ?? (polarity == .positive ? Color.green : Color.red)
        let delta = FloatingDelta(text: formattedPoints(points), color: accent.opacity(0.95), start: start, end: end)
        floatingDeltas.append(delta)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            floatingDeltas.removeAll { $0.id == delta.id }
        }
    }

    private func formattedPoints(_ value: Double) -> String {
        guard !value.isNaN, !value.isInfinite else { return "0" }
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = abs(value) >= 10 ? 0 : 1
        formatter.minimumFractionDigits = 0
        let number = NSNumber(value: abs(value))
        let base = formatter.string(from: number) ?? String(format: "%.1f", abs(value))
        let sign = value >= 0 ? "+" : "−"
        return "\(sign)\(base)"
    }

    private func formattedCutoffHour() -> String {
        String(format: "%02d:00", viewModel.cutoffHour)
    }

    private func handleSparkle(for card: DeedsPageViewModel.CardState, startFrame: CGRect?) {
        let frame = startFrame ?? cardFrames[card.id] ?? .zero
        guard !frame.isEmpty else { return }
        let center = CGPoint(x: frame.midX, y: frame.midY)
        let burst = SparkleBurst(center: center, color: card.accentColor)
        sparkleBursts.append(burst)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            sparkleBursts.removeAll { $0.id == burst.id }
        }
    }

    struct QuickAddState: Identifiable {
        let id = UUID()
        let card: DeedsPageViewModel.CardState
        var amount: Double
        var note: String

        var computedPoints: Double {
            amount * card.card.pointsPerUnit
        }
    }

    struct FloatingDelta: Identifiable {
        let id = UUID()
        let text: String
        let color: Color
        let start: CGPoint
        let end: CGPoint
    }

    struct SparkleBurst: Identifiable {
        let id = UUID()
        let center: CGPoint
        let color: Color
    }
}

private struct CardFramePreferenceKey: PreferenceKey {
    static var defaultValue: [UUID: Anchor<CGRect>] = [:]

    static func reduce(value: inout [UUID: Anchor<CGRect>], nextValue: () -> [UUID: Anchor<CGRect>]) {
        value.merge(nextValue(), uniquingKeysWith: { $1 })
    }
}

private struct HeaderFramePreferenceKey: PreferenceKey {
    static var defaultValue: Anchor<CGRect>? = nil

    static func reduce(value: inout Anchor<CGRect>?, nextValue: () -> Anchor<CGRect>?) {
        if let next = nextValue() {
            value = next
        }
    }
}

private struct FloatingDeltaView: View {
    let delta: DeedsPage.FloatingDelta
    @State private var progress: CGFloat = 0

    var body: some View {
        Text(delta.text)
            .font(.headline.weight(.semibold))
            .foregroundColor(delta.color)
            .shadow(color: Color.black.opacity(0.3), radius: 6, x: 0, y: 2)
            .position(position)
            .opacity(Double(1 - progress))
            .onAppear {
                withAnimation(.easeInOut(duration: 0.8)) {
                    progress = 1
                }
            }
            .allowsHitTesting(false)
    }

    private var position: CGPoint {
        CGPoint(
            x: delta.start.x + (delta.end.x - delta.start.x) * progress,
            y: delta.start.y + (delta.end.y - delta.start.y) * progress - 40 * progress
        )
    }
}

private struct SparkleBurstView: View {
    let burst: DeedsPage.SparkleBurst
    @State private var progress: CGFloat = 0

    var body: some View {
        ZStack {
            ForEach(0..<6, id: \.self) { index in
                Circle()
                    .fill(burst.color.opacity(Double(1 - progress)))
                    .frame(width: circleSize(for: progress), height: circleSize(for: progress))
                    .offset(
                        x: CGFloat(direction(for: index).dx) * radius(for: progress),
                        y: CGFloat(direction(for: index).dy) * radius(for: progress)
                    )
                    .blur(radius: progress * 2)
            }
        }
        .position(burst.center)
        .opacity(Double(1 - progress * 0.6))
        .onAppear {
            withAnimation(.easeOut(duration: 0.9)) {
                progress = 1
            }
        }
        .allowsHitTesting(false)
    }

    private func circleSize(for progress: CGFloat) -> CGFloat {
        6 + progress * 14
    }

    private func radius(for progress: CGFloat) -> CGFloat {
        12 + progress * 36
    }

    private func direction(for index: Int) -> CGVector {
        let radians = Double(index) / 6.0 * .pi * 2
        return CGVector(dx: cos(radians), dy: sin(radians))
    }
}

private struct DeedEditorState: Identifiable {
    let id = UUID()
    let card: DeedCard?
}

private struct DeedCardTile: View {
    let state: DeedsPageViewModel.CardState
    let onTap: () -> Void
    let onQuickAdd: () -> Void
    let onEdit: () -> Void

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 20, style: .continuous)
        ZStack(alignment: .topLeading) {
            shape
                .fill(.ultraThinMaterial)
                .overlay(
                    shape.stroke(state.accentColor.opacity(0.6), lineWidth: 1.5)
                )

            VStack(alignment: .leading, spacing: 10) {
                DeedIconView(value: state.card.emoji)

                Text(state.card.name)
                    .font(.headline)
                    .foregroundColor(.white)
                    .lineLimit(1)

                Text(state.card.unitLabel)
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.7))
            }
            .padding(16)

            if state.card.isPrivate {
                Image(systemName: "eye.slash.fill")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.white.opacity(0.5))
                    .padding(10)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
            }
        }
        .frame(height: 120)
        .contentShape(shape)
        .onTapGesture { onTap() }
        .contextMenu {
            Button {
                onQuickAdd()
            } label: {
                Label("Quick Add", systemImage: "bolt.badge.clock")
            }

            Button {
                onEdit()
            } label: {
                Label("Edit", systemImage: "pencil")
            }
        }
    }
}

private struct AddCardTile: View {
    let action: () -> Void

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 20, style: .continuous)
        shape
            .fill(.ultraThinMaterial)
            .overlay(
                VStack(spacing: 8) {
                    Image(systemName: "plus")
                        .font(.system(size: 24, weight: .bold))
                    Text("New")
                        .font(.subheadline.weight(.semibold))
                }
                .foregroundColor(.white)
            )
            .overlay(shape.stroke(Color.white.opacity(0.25), lineWidth: 1))
            .frame(height: 120)
            .contentShape(shape)
            .onTapGesture { action() }
    }
}

private struct QuickAddSheet: View {
    @State private var localState: DeedsPage.QuickAddState
    let onSave: (DeedsPage.QuickAddState) -> Void
    let onDismiss: () -> Void

    init(state: DeedsPage.QuickAddState, onSave: @escaping (DeedsPage.QuickAddState) -> Void, onDismiss: @escaping () -> Void) {
        _localState = State(initialValue: state)
        self.onSave = onSave
        self.onDismiss = onDismiss
    }

    var body: some View {
        NavigationStack {
            Form {
                amountSection
                noteSection
                previewSection
            }
            .navigationTitle(localState.card.card.name)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: dismiss)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save)
                        .disabled(localState.amount <= 0)
                }
            }
        }
    }

    private var amountSection: some View {
        Section(header: Text("Amount")) {
            switch localState.card.card.unitType {
            case .boolean:
                Toggle(isOn: Binding(
                    get: { localState.amount > 0.5 },
                    set: { localState.amount = $0 ? 1 : 0 }
                )) {
                    Text(localState.card.card.unitLabel.isEmpty ? "Completed" : localState.card.card.unitLabel)
                }
            case .rating:
                Stepper(value: $localState.amount, in: 1...5, step: 1) {
                    Text("Rating: \(Int(localState.amount))")
                }
            case .count:
                Stepper(value: $localState.amount, in: 0...100, step: 1) {
                    Text("\(Int(localState.amount)) \(localState.card.card.unitLabel)")
                }
            case .duration:
                Stepper(value: $localState.amount, in: 5...1440, step: 5) {
                    Text("\(Int(localState.amount)) min")
                }
            case .quantity:
                Stepper(value: $localState.amount, in: 50...10000, step: 50) {
                    Text("\(Int(localState.amount)) \(localState.card.card.unitLabel)")
                }
            }
        }
    }

    private var noteSection: some View {
        Section(header: Text("Note")) {
            TextField("Optional note", text: $localState.note, axis: .vertical)
        }
    }

    private var previewSection: some View {
        Section(header: Text("Points")) {
            Text(formattedPoints(localState.computedPoints))
                .font(.headline)
        }
    }

    private func save() {
        onSave(localState)
        dismiss()
    }

    private func dismiss() {
        onDismiss()
    }

    private func formattedPoints(_ value: Double) -> String {
        guard !value.isNaN, !value.isInfinite else { return "0" }
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 1
        formatter.minimumFractionDigits = 0
        let number = NSNumber(value: value)
        return formatter.string(from: number) ?? String(format: "%.1f", value)
    }
}

private struct RatingPickerSheet: View {
    let card: DeedsPageViewModel.CardState
    let onSave: (Int) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var rating: Int = 3

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Text("How did it feel?")
                    .font(.headline)

                Picker("Rating", selection: $rating) {
                    ForEach(1..<6) { value in
                        Text("\(value)").tag(value)
                    }
                }
                .pickerStyle(.segmented)

                Spacer()
            }
            .padding()
            .navigationTitle(card.card.name)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        dismiss()
                        onSave(rating)
                    }
                }
            }
        }
        .onAppear {
            rating = Int(card.lastAmount ?? 3)
        }
    }
}

private final class FeedbackManager {
    static let shared = FeedbackManager()
    private var players: [String: AVAudioPlayer] = [:]

    func emitHaptic(for polarity: Polarity) {
        let generator = UINotificationFeedbackGenerator()
        generator.prepare()
        switch polarity {
        case .positive:
            generator.notificationOccurred(.success)
        case .negative:
            generator.notificationOccurred(.warning)
        }
    }

    func playSound(for polarity: Polarity) {
        let resourceName: String
        switch polarity {
        case .positive:
            resourceName = "positive-tone"
        case .negative:
            resourceName = "negative-tone"
        }

        if play(resourceName, ext: "mp3") { return }
        _ = play(resourceName, ext: "wav")
    }

    @discardableResult
    private func play(_ name: String, ext: String) -> Bool {
        let key = "\(name).\(ext)"
        if let player = players[key] {
            player.currentTime = 0
            player.play()
            return true
        }

        guard let url = Bundle.main.url(forResource: name, withExtension: ext) else { return false }
        do {
            let player = try AVAudioPlayer(contentsOf: url)
            player.prepareToPlay()
            player.play()
            players[key] = player
            return true
        } catch {
            return false
        }
    }
}

#Preview {
    DeedsPage()
        .environmentObject(AppEnvironment())
}
