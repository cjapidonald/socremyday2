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
    @State private var capHint: CapHintState?
    @State private var draggingCardID: UUID?
    @State private var pendingDragCardID: UUID?
    @State private var dragTranslation: CGSize = .zero
    @State private var dragStartCenter: CGPoint?
    @State private var lastDragTargetID: UUID?
    @State private var moveCardState: MoveCardSheetState?

    private let capHintStore = DailyCapHintStore()

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

            if let hint = capHint {
                CapHintBanner(message: hint.message) {
                    dismissCapHint()
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .transition(.move(edge: .top).combined(with: .opacity))
                .zIndex(1)
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: capHint?.id)
        .onAppear { viewModel.onAppear() }
        .onChange(of: appEnvironment.settings.dayCutoffHour) { _, newValue in
            viewModel.updateCutoffHour(newValue)
        }
        .onChange(of: appEnvironment.dataVersion) {
            viewModel.reload()
        }
        .sheet(item: $quickAddState) { state in
            QuickAddSheet(state: state, onSave: { updated in
                if let result = viewModel.log(cardID: updated.card.id, amount: updated.amount, note: updated.note.isEmpty ? nil : updated.note) {
                    let entry = result.entry
                    handleFeedback(for: updated.card.card.polarity, points: entry.computedPoints, cardID: updated.card.id, startFrameOverride: cardFrames[updated.card.id])
                    handleDailyCapHint(for: updated.card, result: result)
                }
            }) {
                quickAddState = nil
            }
        }
        .sheet(item: $viewModel.pendingRatingCard) { card in
            RatingPickerSheet(card: card) { rating in
                if let result = viewModel.confirmRatingSelection(rating) {
                    let entry = result.entry
                    handleFeedback(for: card.card.polarity, points: entry.computedPoints, cardID: card.id)
                    handleDailyCapHint(for: card, result: result)
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
                Text("LAST 7 DAYS")
                    .font(.caption.weight(.semibold))
                    .textCase(.uppercase)
                    .foregroundStyle(.secondary)

                Text(formattedPoints(viewModel.weeklyNetScore))
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)

                Text("daily reset at \(formattedCutoffHour())")
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
                let isDragging = draggingCardID == card.id
                DeedCardTile(
                    state: card,
                    onTap: { handleTap(on: card) },
                    onQuickAdd: {
                        quickAddState = QuickAddState(
                            card: card,
                            amount: viewModel.defaultAmount(for: card),
                            note: ""
                        )
                    },
                    onEdit: { deedEditorState = DeedEditorState(card: card.card) },
                    onMove: { moveCardState = MoveCardSheetState(cardID: card.id) },
                    onToggleArchive: { viewModel.toggleArchive(for: card.id) },
                    onSetShowOnStats: { value in viewModel.setShowOnStats(value, for: card.id) }
                )
                .scaleEffect(isDragging ? 1.05 : 1)
                .offset(isDragging ? dragTranslation : .zero)
                .zIndex(isDragging ? 1 : 0)
                .disabled(isDragging || pendingDragCardID == card.id)
                .simultaneousGesture(
                    LongPressGesture(minimumDuration: 0.25)
                        .onEnded { _ in beginDrag(for: card) }
                )
                .highPriorityGesture(
                    DragGesture()
                        .onChanged { value in updateDrag(for: card.id, translation: value.translation) }
                        .onEnded { value in finishDrag(for: card.id, translation: value.translation) }
                )
                .anchorPreference(key: CardFramePreferenceKey.self, value: .bounds) { [card.id: $0] }
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
            handleDailyCapHint(for: card, result: result)
        }
    }

    private func beginDrag(for card: DeedsPageViewModel.CardState) {
        pendingDragCardID = card.id
        dragTranslation = .zero
        dragStartCenter = cardFrames[card.id].map(center(of:))
        lastDragTargetID = nil

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            if draggingCardID == nil, pendingDragCardID == card.id {
                pendingDragCardID = nil
                dragStartCenter = nil
            }
        }
    }

    private func updateDrag(for cardID: UUID, translation: CGSize) {
        guard pendingDragCardID == cardID || draggingCardID == cardID else { return }
        if draggingCardID == nil {
            draggingCardID = cardID
            pendingDragCardID = nil
        }
        guard draggingCardID == cardID else { return }
        if dragStartCenter == nil {
            dragStartCenter = cardFrames[cardID].map(center(of:))
        }
        dragTranslation = translation
        handleDragMove(for: cardID, translation: translation)
    }

    private func finishDrag(for cardID: UUID, translation: CGSize) {
        if draggingCardID == cardID {
            dragTranslation = translation
            viewModel.persistCardOrder()
        }

        pendingDragCardID = nil
        draggingCardID = nil
        dragStartCenter = nil
        lastDragTargetID = nil

        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            dragTranslation = .zero
        }
    }

    private func handleDragMove(for cardID: UUID, translation: CGSize) {
        guard let start = dragStartCenter else { return }
        let position = CGPoint(x: start.x + translation.width, y: start.y + translation.height)
        guard let target = cardFrames.first(where: { $0.key != cardID && $0.value.contains(position) }) else {
            lastDragTargetID = nil
            return
        }
        guard lastDragTargetID != target.key else { return }
        lastDragTargetID = target.key

        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            viewModel.moveCard(id: cardID, over: target.key)
        }
    }

    private func center(of rect: CGRect) -> CGPoint {
        CGPoint(x: rect.midX, y: rect.midY)
    }

    private func handleDailyCapHint(for card: DeedsPageViewModel.CardState, result: LogEntryResult) {
        guard result.wasCapped else { return }
        let entry = result.entry
        guard capHintStore.shouldShowHint(for: card.id, on: entry.timestamp, cutoffHour: viewModel.cutoffHour) else { return }
        capHintStore.markHintShown(for: card.id, on: entry.timestamp, cutoffHour: viewModel.cutoffHour)
        let message = "Daily cap reached for \(card.card.name). Additional logs won't earn points today."
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            capHint = CapHintState(message: message)
        }
    }

    private func dismissCapHint() {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            capHint = nil
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

    private func formattedCutoffHour() -> String {
        String(format: "%02d:00", viewModel.cutoffHour)
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
            switch card.card.unitType {
            case .rating:
                let clamped = max(1, min(5, Int(amount.rounded())))
                return Double(clamped)
            default:
                return amount
            }
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

    struct CapHintState: Identifiable {
        let id = UUID()
        let message: String
    }

}

private struct CapHintBanner: View {
    let message: String
    let onDismiss: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(Color.yellow)

            Text(message)
                .font(.subheadline)
                .foregroundStyle(.primary)
                .multilineTextAlignment(.leading)

            Spacer(minLength: 12)

            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .padding(6)
                    .background(Circle().fill(Color.secondary.opacity(0.15)))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Dismiss daily cap hint")
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .shadow(color: Color.black.opacity(0.08), radius: 10, x: 0, y: 8)
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
            .onMove { indices, newOffset in
                orderedCards.move(fromOffsets: indices, toOffset: newOffset)
            }
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
    let onQuickAdd: () -> Void
    let onEdit: () -> Void
    let onMove: () -> Void
    let onToggleArchive: () -> Void
    let onSetShowOnStats: (Bool) -> Void

    var body: some View {
        Button(action: onTap) {
            ZStack(alignment: .topLeading) {
                VStack(alignment: .leading, spacing: 10) {
                    Text(state.card.name)
                        .font(.headline)
                        .foregroundStyle(.white)
                        .lineLimit(1)

                    Text(state.card.unitLabel)
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.7))
                }
                .padding(16)
            }
            .frame(maxWidth: .infinity, minHeight: 120, maxHeight: 120, alignment: .topLeading)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(state.accentColor)
            )
            .contentShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(state.card.accessibilityLabel(lastAmount: state.lastAmount, unit: state.card.unitLabel))
        }
        .buttonStyle(.plain)
        .overlay(alignment: .topTrailing) {
            HStack(spacing: 6) {
                if state.card.isPrivate {
                    Image(systemName: "eye.slash.fill")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(.white.opacity(0.7))
                        .padding(10)
                        .accessibilityLabel("Private card")
                }

                Menu {
                    Button { onQuickAdd() } label: {
                        Label("Quick Add", systemImage: "bolt.badge.clock")
                    }

                    Button { onEdit() } label: {
                        Label("Edit", systemImage: "pencil")
                    }

                    Button { onMove() } label: {
                        Label("Move Card", systemImage: "arrow.up.arrow.down")
                    }

                    Button { onToggleArchive() } label: {
                        Label(
                            state.card.isArchived ? "Unarchive" : "Archive",
                            systemImage: state.card.isArchived ? "tray.and.arrow.up" : "archivebox"
                        )
                    }

                    Button {
                        onSetShowOnStats(!state.card.showOnStats)
                    } label: {
                        Label(
                            state.card.showOnStats ? "Hide from Stats Page" : "Show on Stats Page",
                            systemImage: "chart.bar.xaxis"
                        )
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(10)
                        .background(
                            Circle()
                                .fill(Color.white.opacity(0.2))
                        )
                        .accessibilityLabel("More actions")
                }
                .menuStyle(.borderlessButton)
            }
            .padding(6)
        }
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

            Button {
                onMove()
            } label: {
                Label("Move Card", systemImage: "arrow.up.arrow.down")
            }

            Button {
                onToggleArchive()
            } label: {
                Label(
                    state.card.isArchived ? "Unarchive" : "Archive",
                    systemImage: state.card.isArchived ? "tray.and.arrow.up" : "archivebox"
                )
            }

            Toggle(isOn: Binding(
                get: { state.card.showOnStats },
                set: { newValue in
                    guard newValue != state.card.showOnStats else { return }
                    onSetShowOnStats(newValue)
                }
            )) {
                Label("Show on Stats Page", systemImage: "chart.bar.xaxis")
            }
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
            case .rating:
                RatingSlider(rating: Binding(
                    get: { max(1, min(5, Int(localState.amount.rounded()))) },
                    set: { localState.amount = Double($0) }
                ))
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

private struct RatingSlider: View {
    @Binding var rating: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 6) {
                ForEach(1...5, id: \.self) { value in
                    Image(systemName: value <= rating ? "star.fill" : "star")
                        .foregroundStyle(value <= rating ? Color.yellow : Color.secondary)
                        .font(.title3)
                        .onTapGesture {
                            rating = value
                        }
                }
            }

            Slider(
                value: Binding(
                    get: { Double(rating) },
                    set: { rating = Int(round($0)) }
                ),
                in: 1...5,
                step: 1
            ) {
                Text("Rating")
            }
            .tint(.yellow)

            Text("\(rating) \(rating == 1 ? "star" : "stars")")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
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

#Preview {
    DeedsPage()
        .environmentObject(AppEnvironment())
}
