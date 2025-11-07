import SwiftUI
import UIKit

struct DeedsPage: View {
    @EnvironmentObject private var appEnvironment: AppEnvironment
    @StateObject private var viewModel = DeedsPageViewModel()

    @State private var quickAddState: QuickAddState?
    @State private var floatingDeltas: [FloatingDelta] = []
    @State private var floatingDeltaQueue = FloatingDeltaQueue()
    @State private var particleBursts: [ParticleOverlayView.Event] = []
    @State private var cardFrames: [UUID: CGRect] = [:]
    @State private var headerFrame: CGRect = .zero
    @State private var deedEditorState: DeedEditorState?
    @State private var scorePulsePhase: CGFloat = 0
    @State private var particlesDisabled = UIAccessibility.isReduceMotionEnabled
    @State private var opaqueBackgrounds = UIAccessibility.isReduceTransparencyEnabled
    @State private var moveCardState: MoveCardSheetState?
    @State private var heldActionCard: DeedsPageViewModel.CardState?

    var body: some View {
        ZStack(alignment: .top) {
            GeometryReader { proxy in
                ZStack(alignment: .top) {
                    if opaqueBackgrounds {
                        Color(.systemBackground)
                            .ignoresSafeArea()
                    } else {
                        LiquidBackgroundView()
                            .ignoresSafeArea()
                    }

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

                    if !particlesDisabled {
                        ForEach(floatingDeltas) { delta in
                            FloatingDeltaView(delta: delta)
                        }

                        ParticleOverlayView(events: particleBursts)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .allowsHitTesting(false)
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

        }
        .onAppear {
            viewModel.configureIfNeeded(environment: appEnvironment)

            // Force reload if cards are empty every time view appears
            // This ensures data loads even if initial load failed
            if viewModel.cards.isEmpty {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    if viewModel.cards.isEmpty {
                        viewModel.reload()
                    }
                }
            }
        }
        .onChange(of: appEnvironment.selectedTab) { _, newTab in
            // Reload if switching to deeds tab and no cards are loaded
            if newTab == .deeds && viewModel.cards.isEmpty {
                viewModel.reload()
            }
        }
        .onChange(of: appEnvironment.settings.dayCutoffHour) { _, newValue in
            viewModel.updateCutoffHour(newValue)
        }
        .onChange(of: appEnvironment.settings.dayCutoffMinute) { _, newValue in
            viewModel.updateCutoffMinute(newValue)
        }
        .onChange(of: appEnvironment.dataVersion) {
            viewModel.reload()
        }
        .sheet(item: $quickAddState) { state in
            QuickAddSheet(state: state, onSave: { updated in
                if let result = viewModel.log(cardID: updated.card.id, amount: updated.amount, note: updated.note.isEmpty ? nil : updated.note) {
                    let entry = result.entry
                    handleFeedback(for: updated.card.card.polarity, points: entry.computedPoints, cardID: updated.card.id, startFrameOverride: cardFrames[updated.card.id])
                }
            }) {
                quickAddState = nil
            }
        }
        // Removed rating picker sheet as rating type is no longer supported
        .sheet(item: $deedEditorState, onDismiss: { deedEditorState = nil }) { state in
            AddEditDeedSheet(
                initialCard: state.card,
                categorySuggestions: viewModel.categorySuggestions,
                onSave: { card in
                    viewModel.upsert(card: card)
                    appEnvironment.notifyDataDidChange()
                }
            )
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
        }
        .sheet(item: $moveCardState, onDismiss: { moveCardState = nil }) { state in
            MoveCardSheet(
                cards: viewModel.cards,
                focusCardID: state.cardID,
                onSave: { orderedIDs in
                    viewModel.reorderCards(by: orderedIDs)
                    viewModel.persistCardOrder()
                }
            )
        }
        .modifier(MotionTransparencyEnv(
            disableParticles: { value in
                particlesDisabled = value
                if value {
                    floatingDeltas.removeAll()
                    particleBursts.removeAll()
                }
            },
            setOpaqueBackgrounds: { opaqueBackgrounds = $0 }
        ))
    }

    private var headerView: some View {
        HStack(alignment: .center, spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Points Today")
                    .font(.caption.weight(.semibold))
                    .textCase(.uppercase)
                    .foregroundStyle(.secondary)

                Text(formattedPoints(viewModel.todayNetScore))
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)

                Text("checkpoint at \(formattedCutoffTime())")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            SparklineView(values: viewModel.sparklineValues)
                .frame(width: 120, height: 36)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 18)
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(Color(.secondarySystemBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(Color.primary.opacity(0.05))
        )
        .contentShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .scaleEffect(1 + 0.05 * scorePulsePhase)
        .animation(.spring(response: 0.32, dampingFraction: 0.72, blendDuration: 0.2), value: scorePulsePhase)
    }

    private var cardsGrid: some View {
        let columns = Array(repeating: GridItem(.flexible(), spacing: 14, alignment: .top), count: 3)

        return LazyVGrid(columns: columns, spacing: 14) {
            ForEach(viewModel.cards) { card in
                DeedCardTile(
                    state: card,
                    onTap: { handleTap(on: card) },
                    onUndo: { handleUndo(for: card) }
                )
                .anchorPreference(key: CardFramePreferenceKey.self, value: .bounds) { [card.id: $0] }
                .contextMenu {
                    Button(action: {
                        moveCardState = MoveCardSheetState(cardID: card.id)
                    }) {
                        Label("Move Card", systemImage: "arrow.up.arrow.down")
                    }

                    Button(action: {
                        deedEditorState = DeedEditorState(card: card.card)
                    }) {
                        Label("Edit Card", systemImage: "pencil")
                    }

                    Button(action: {
                        quickAddState = QuickAddState(
                            card: card,
                            amount: viewModel.defaultAmount(for: card),
                            note: "",
                        )
                    }) {
                        Label("Quick Add", systemImage: "plus.circle")
                    }

                    Button(action: {
                        viewModel.setShowOnStats(!card.card.showOnStats, for: card.id)
                    }) {
                        Label(card.card.showOnStats ? "Hide from Stats" : "Show on Stats", systemImage: card.card.showOnStats ? "eye.slash" : "eye")
                    }

                    Button(role: card.card.isArchived ? .none : .destructive, action: {
                        viewModel.toggleArchive(for: card.id)
                    }) {
                        Label(card.card.isArchived ? "Unarchive" : "Archive", systemImage: card.card.isArchived ? "tray.and.arrow.up" : "archivebox")
                    }
                }
            }

            AddCardTile {
                deedEditorState = DeedEditorState(card: nil)
            }
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: viewModel.cards)
    }

    private func handleTap(on card: DeedsPageViewModel.CardState) {
        let startFrame = cardFrames[card.id]
        if let result = viewModel.prepareTap(on: card) {
            let entry = result.entry
            handleFeedback(for: card.card.polarity, points: entry.computedPoints, cardID: card.id, startFrameOverride: startFrame)
        }
    }

    private func handleUndo(for card: DeedsPageViewModel.CardState) {
        guard let deletedEntry = viewModel.undoLastEntry(for: card.id) else {
            // No entry to undo
            HapticsManager.shared.negative()
            return
        }

        // Provide haptic feedback for successful undo
        HapticsManager.shared.negative()

        // Show floating delta for undo (negative of the deleted points)
        let undoPoints = -deletedEntry.computedPoints
        let polarity: Polarity = undoPoints >= 0 ? .positive : .negative
        if undoPoints != 0 {
            enqueueFloatingDelta(points: undoPoints, cardID: card.id, polarity: polarity, startFrameOverride: cardFrames[card.id])
        }
    }

    private func handleFeedback(for polarity: Polarity, points: Double, cardID: UUID, startFrameOverride: CGRect? = nil) {
        switch polarity {
        case .positive:
            HapticsManager.shared.positive()
            SoundManager.shared.positive()
        case .negative:
            HapticsManager.shared.negative()
            SoundManager.shared.negative()
        }

        if points != 0 {
            enqueueFloatingDelta(points: points, cardID: cardID, polarity: polarity, startFrameOverride: startFrameOverride)
        }

        if polarity == .positive, let card = viewModel.cards.first(where: { $0.id == cardID }) {
            handleSparkle(for: card, points: points, startFrame: startFrameOverride)
        }
    }

    private func enqueueFloatingDelta(points: Double, cardID: UUID, polarity: Polarity, startFrameOverride: CGRect? = nil) {
        guard !particlesDisabled else { return }
        guard !headerFrame.isEmpty else { return }
        let headerRect = headerFrame
        guard let startRect = startFrameOverride ?? cardFrames[cardID] else { return }
        let start = CGPoint(x: startRect.midX, y: startRect.midY)
        let end = CGPoint(x: headerRect.midX, y: headerRect.midY)
        let accent = viewModel.cards.first(where: { $0.id == cardID })?.accentColor ?? (polarity == .positive ? Color.green : Color.red)
        let delay = floatingDeltaQueue.nextDelay()
        let duration = FloatingDelta.defaultAnimationDuration
        let delta = FloatingDelta(
            text: formattedPoints(points),
            color: accent.opacity(0.95),
            start: start,
            end: end,
            delay: delay,
            duration: duration
        )
        floatingDeltas.append(delta)
        let removalDelay = delay + duration + 0.35
        DispatchQueue.main.asyncAfter(deadline: .now() + removalDelay) {
            floatingDeltas.removeAll { $0.id == delta.id }
        }
        triggerScorePulse(after: delay + duration)
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

    private func formattedCutoffTime() -> String {
        String(format: "%02d:%02d", viewModel.cutoffHour, viewModel.cutoffMinute)
    }

    private func triggerScorePulse(after delay: TimeInterval) {
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            scorePulsePhase = 0
            DispatchQueue.main.async {
                scorePulsePhase = 1
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.28) {
                    scorePulsePhase = 0
                }
            }
        }
    }

    private func handleSparkle(for card: DeedsPageViewModel.CardState, points: Double, startFrame: CGRect?) {
        guard !particlesDisabled else { return }
        let frame = startFrame ?? cardFrames[card.id] ?? .zero
        guard !frame.isEmpty else { return }
        let style: ParticleOverlayView.Event.Style = abs(points) >= 50 ? .confetti : .sparkle
        let burst = ParticleOverlayView.Event(frame: frame, color: UIColor(card.accentColor), style: style)
        particleBursts.append(burst)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            particleBursts.removeAll { $0.id == burst.id }
        }
    }

    struct QuickAddState: Identifiable {
        let id = UUID()
        let card: DeedsPageViewModel.CardState
        var amount: Double
        var note: String

        var computedPoints: Double {
            normalizedAmount * card.card.pointsPerUnit
        }

        var normalizedAmount: Double {
            return amount
        }
    }

    struct FloatingDelta: Identifiable {
        static let defaultAnimationDuration: TimeInterval = 0.9

        let id = UUID()
        let text: String
        let color: Color
        let start: CGPoint
        let end: CGPoint
        let delay: TimeInterval
        let duration: TimeInterval
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
    @State private var isActive: Bool = false

    var body: some View {
        Text(delta.text)
            .font(.headline.weight(.semibold))
            .foregroundColor(delta.color)
            .shadow(color: Color.black.opacity(0.3), radius: 6, x: 0, y: 2)
            .scaleEffect(1 + 0.18 * (1 - currentProgress))
            .position(position(for: currentProgress))
            .opacity(opacity)
            .onAppear {
                startAnimation()
            }
            .allowsHitTesting(false)
    }

    private var opacity: Double {
        guard isActive else { return 0 }
        let fadeInEnd: CGFloat = 0.2
        let fadeOutStart: CGFloat = 0.55

        if progress <= fadeInEnd {
            return Double(progress / fadeInEnd)
        } else if progress <= fadeOutStart {
            return 1
        } else {
            let fadeProgress = (progress - fadeOutStart) / (1 - fadeOutStart)
            return Double(max(1 - fadeProgress, 0))
        }
    }

    private var currentProgress: CGFloat {
        isActive ? progress : 0
    }

    private func startAnimation() {
        DispatchQueue.main.asyncAfter(deadline: .now() + delta.delay) {
            isActive = true
            withAnimation(.easeInOut(duration: delta.duration)) {
                progress = 1
            }
        }
    }

    private func position(for progress: CGFloat) -> CGPoint {
        guard !UIAccessibility.isReduceMotionEnabled else {
            return CGPoint(
                x: delta.start.x + (delta.end.x - delta.start.x) * progress,
                y: delta.start.y + (delta.end.y - delta.start.y) * progress
            )
        }

        let control = controlPoint
        let x = quadraticBezier(t: progress, start: delta.start.x, control: control.x, end: delta.end.x)
        let y = quadraticBezier(t: progress, start: delta.start.y, control: control.y, end: delta.end.y)
        return CGPoint(x: x, y: y)
    }

    private var controlPoint: CGPoint {
        let midX = (delta.start.x + delta.end.x) / 2
        let verticalDistance = abs(delta.start.y - delta.end.y)
        let arcHeight = max(60, verticalDistance * 0.35)
        let peakY = min(delta.start.y, delta.end.y) - arcHeight
        let horizontalOffset = (delta.end.x - delta.start.x) * 0.2
        return CGPoint(x: midX + horizontalOffset, y: peakY)
    }

    private func quadraticBezier(t: CGFloat, start: CGFloat, control: CGFloat, end: CGFloat) -> CGFloat {
        let oneMinusT = 1 - t
        return oneMinusT * oneMinusT * start + 2 * oneMinusT * t * control + t * t * end
    }
}

private struct DeedEditorState: Identifiable {
    let id = UUID()
    let card: DeedCard?
}

private struct MoveCardSheetState: Identifiable {
    let id = UUID()
    let cardID: UUID
}

private struct MoveCardSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var orderedCards: [DeedsPageViewModel.CardState]

    let focusCardID: UUID
    let onSave: ([UUID]) -> Void

    init(cards: [DeedsPageViewModel.CardState], focusCardID: UUID, onSave: @escaping ([UUID]) -> Void) {
        _orderedCards = State(initialValue: cards)
        self.focusCardID = focusCardID
        self.onSave = onSave
    }

    var body: some View {
        NavigationStack {
            List {
                instructionsSection
                cardsSection
            }
            .listStyle(.insetGrouped)
            .environment(\.editMode, .constant(.active))
            .navigationTitle("Move Card")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        onSave(orderedCards.map(\.id))
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    private var instructionsSection: some View {
        Section {
            Text("Drag the handles to arrange your cards. \(focusCardName) is highlighted so you can place it exactly where you want it.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)
        }
    }

    private var cardsSection: some View {
        Section {
            ForEach(orderedCards) { card in
                cardRow(for: card)
            }
            .onMove(perform: moveCard)
        }
    }

    private func moveCard(from source: IndexSet, to destination: Int) {
        withAnimation {
            orderedCards.move(fromOffsets: source, toOffset: destination)
        }
    }

    private func cardRow(for card: DeedsPageViewModel.CardState) -> some View {
        HStack {
            Text(card.card.name)
                .font(.body)
            Spacer()
            if card.id == focusCardID {
                Image(systemName: "hand.point.up.left.fill")
                    .foregroundStyle(Color.accentColor)
                    .accessibilityLabel("Selected card")
            }
        }
        .padding(.vertical, 8)
        .accessibilityLabel(Text(card.id == focusCardID ? "\(card.card.name), current card" : card.card.name))
        .listRowBackground(card.id == focusCardID ? Color.accentColor.opacity(0.12) : Color(.secondarySystemGroupedBackground))
    }

    private var focusCardName: String {
        orderedCards.first(where: { $0.id == focusCardID })?.card.name ?? "this card"
    }
}

private struct DeedCardTile: View {
    let state: DeedsPageViewModel.CardState
    let onTap: () -> Void
    let onUndo: () -> Void

    var body: some View {
        Button(action: handleTap) {
            ZStack {
                VStack(alignment: .leading, spacing: 8) {
                    // Add spacing at top when badges are visible
                    if hasBadgesAtTop {
                        Spacer()
                            .frame(height: 8)
                    }

                    HStack(alignment: .top, spacing: 12) {
                        if let emoji = leadingEmoji {
                            Text(emoji)
                                .font(.system(size: 30))
                                .frame(width: 36, height: 36)
                                .accessibilityHidden(true)
                        }

                        VStack(alignment: .leading, spacing: 4) {
                            Text(state.card.name)
                                .font(.headline)
                                .foregroundStyle(Color(hex: state.card.textColorHex, fallback: .white))
                                .lineLimit(2)
                                .minimumScaleFactor(0.75)
                                .multilineTextAlignment(.leading)
                                .fixedSize(horizontal: false, vertical: true)
                                .frame(maxWidth: .infinity, alignment: .leading)

                            // Points per tap display
                            Text(pointsPerTapText)
                                .font(.caption.weight(.medium))
                                .foregroundStyle(Color(hex: state.card.textColorHex, fallback: .white).opacity(0.85))
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    Spacer(minLength: 0)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .padding(.horizontal, 16)
                .padding(.vertical, 16)
                .padding(.top, hasBadgesAtTop ? 36 : 0)
            }
            .frame(maxWidth: .infinity, minHeight: 120, maxHeight: 120)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(state.accentColor)
            )
            .contentShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(state.card.accessibilityLabel(lastAmount: state.lastAmount, unit: state.card.unitLabel))
        }
        .buttonStyle(.plain)
        .overlay(alignment: .topLeading) {
            if state.todayCount > 0 {
                Text("\(state.todayCount)")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(Color(hex: state.card.textColorHex, fallback: .white))
                    .frame(minWidth: 28, minHeight: 28)
                    .background(
                        Circle()
                            .fill(Color.black.opacity(0.25))
                    )
                    .padding(8)
                    .accessibilityLabel("Tapped \(state.todayCount) times today")
            }
        }
        .overlay(alignment: .topTrailing) {
            HStack(spacing: 4) {
                // Undo button (when todayCount > 0 and not private, or always show if count > 0)
                if state.todayCount > 0 {
                    Button(action: {
                        onUndo()
                    }) {
                        Image(systemName: "arrow.uturn.backward.circle.fill")
                            .font(.system(size: 24, weight: .semibold))
                            .foregroundStyle(Color(hex: state.card.textColorHex, fallback: .white))
                            .background(
                                Circle()
                                    .fill(Color.black.opacity(0.25))
                                    .frame(width: 28, height: 28)
                            )
                    }
                    .buttonStyle(.plain)
                    .padding(8)
                    .accessibilityLabel("Undo last entry")
                }

                // Private indicator
                if state.card.isPrivate {
                    Image(systemName: "eye.slash.fill")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(Color(hex: state.card.textColorHex, fallback: .white).opacity(0.7))
                        .padding(10)
                        .accessibilityLabel("Private card")
                }
            }
            .padding(state.todayCount > 0 && state.card.isPrivate ? 4 : 0)
        }
    }

    private func handleTap() {
        HapticsManager.shared.cardTap()
        onTap()
    }

    private var leadingEmoji: String? {
        let trimmed = state.card.emoji.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private var hasBadgesAtTop: Bool {
        return state.todayCount > 0 || state.card.isPrivate
    }

    private var pointsPerTapText: String {
        let points = state.card.pointsPerUnit
        let sign = points >= 0 ? "+" : ""
        let formatted = formatPoints(abs(points))
        return "\(sign)\(formatted) pts"
    }

    private func formatPoints(_ value: Double) -> String {
        if value == floor(value) {
            return String(format: "%.0f", value)
        } else if abs(value * 10 - round(value * 10)) < 0.0001 {
            return String(format: "%.1f", value)
        } else {
            return String(format: "%.2f", value)
        }
    }

}

private struct AddCardTile: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: "plus")
                    .font(.system(size: 24, weight: .bold))
                Text("New")
                    .font(.subheadline.weight(.semibold))
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .foregroundStyle(.primary)
            .frame(height: 120)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(Color(.secondarySystemBackground))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(Color.accentColor.opacity(0.3), lineWidth: 1)
            )
            .contentShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        }
        .buttonStyle(.plain)
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
            case .count:
                Stepper(value: $localState.amount, in: 1...100, step: 1) {
                    Text("\(Int(localState.amount)) \(localState.card.card.unitLabel)")
                }
            case .duration:
                VStack(alignment: .leading, spacing: 12) {
                    Stepper(value: $localState.amount, in: 1...1440, step: 5) {
                        Text("\(Int(localState.amount)) \(localState.card.card.unitLabel)")
                    }
                    Text("Set the number of minutes for this activity")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            case .amount:
                VStack(alignment: .leading, spacing: 12) {
                    Stepper(value: $localState.amount, in: 1...1000, step: 5) {
                        Text("\(Int(localState.amount)) \(localState.card.card.unitLabel)")
                    }
                    Text("Set the amount for this transaction")
                        .font(.caption)
                        .foregroundStyle(.secondary)
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
        localState.amount = localState.normalizedAmount
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

// Removed RatingSlider and RatingPickerSheet as rating type is no longer supported

#Preview {
    DeedsPage()
        .environmentObject(AppEnvironment())
}
