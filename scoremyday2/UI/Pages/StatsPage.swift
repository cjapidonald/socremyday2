import Charts
import Combine
import CoreData
import SwiftUI

struct StatsPage: View {
    @EnvironmentObject private var appEnvironment: AppEnvironment
    @StateObject private var viewModel = StatsPageViewModel()
    @State private var deedSearchText: String = ""

    var body: some View {
        ZStack {
            LiquidBackgroundView()

            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    Text("Stats")
                        .font(.largeTitle)
                        .fontWeight(.bold)

                    if viewModel.isLoading {
                        ProgressView()
                            .frame(maxWidth: .infinity, alignment: .center)
                    } else if !viewModel.hasAnyEntries {
                        emptyStateView
                    } else {
                        Picker("Range", selection: $viewModel.selectedRange) {
                            ForEach(StatsRange.allCases) { range in
                                Text(range.label)
                                    .tag(range)
                            }
                        }
                        .pickerStyle(.segmented)

                        mainNetScoreSection
                        perCardTrendSection
                        insightsSection
                        contributionSection
                    }
                }
                .padding()
            }
        }
        .task {
            await viewModel.configureIfNeeded(environment: appEnvironment)
        }
        .onChange(of: appEnvironment.settings.dayCutoffHour, initial: false) { oldValue, newValue in
            Task { await viewModel.updateCutoffHour(newValue) }
        }
        .onChange(of: appEnvironment.dataVersion, initial: false) { _, _ in
            Task { await viewModel.forceReload() }
        }
    }

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "chart.pie")
                .font(.system(size: 44))
                .foregroundStyle(.secondary)

            Text("No stats yet")
                .font(.title3)
                .fontWeight(.semibold)

            Text("Log your first deed to unlock insights and charts.")
                .font(.callout)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)

            Button {
                appEnvironment.selectedTab = .deeds
            } label: {
                Text("Log your first deed")
                    .fontWeight(.semibold)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(24)
        .frame(maxWidth: .infinity)
        .glassBackground(cornerRadius: 20, tint: Color.accentColor, warpStrength: 2.5)
    }

    private var mainNetScoreSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Main Net Score")
                .font(.title2)
                .fontWeight(.semibold)

            if viewModel.dailyNetSeries.isEmpty {
                Text("No score activity yet. Start logging deeds to see insights.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                StatsChartContainer(points: viewModel.dailyNetSeries) {
                    Chart(viewModel.dailyNetSeries) { point in
                        LineMark(
                            x: .value("Day", point.date),
                            y: .value("Net Score", point.value)
                        )
                        .interpolationMethod(.catmullRom)

                        AreaMark(
                            x: .value("Day", point.date),
                            y: .value("Net Score", point.value)
                        )
                        .interpolationMethod(.catmullRom)
                        .foregroundStyle(Color.accentColor.gradient.opacity(0.25))

                        if point.date == viewModel.todayPoint?.date, let todayPoint = viewModel.todayPoint {
                            PointMark(
                                x: .value("Today", todayPoint.date),
                                y: .value("Today Value", todayPoint.value)
                            )
                            .symbolSize(100)
                            .foregroundStyle(Color.accentColor)
                            .annotation(position: .top) {
                                VStack(spacing: 4) {
                                    Text("TODAY")
                                        .font(.caption)
                                        .fontWeight(.semibold)
                                        .foregroundStyle(.secondary)
                                    Text(todayPoint.formattedValue)
                                        .font(.headline)
                                        .fontWeight(.semibold)
                                }
                                .padding(8)
                                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                            }
                        }
                    }
                    .chartYAxis {
                        AxisMarks(position: .leading)
                    }
                    .frame(height: 240)
                }
            }
        }
    }

    private var perCardTrendSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Per-Card Trend")
                .font(.title2)
                .fontWeight(.semibold)

            if viewModel.topDeeds.isEmpty {
                Text("Log some deeds to unlock per-card insights.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            } else {
                ScrollViewReader { proxy in
                    let trimmedSearch = deedSearchText.trimmingCharacters(in: .whitespacesAndNewlines)
                    let filteredTop = viewModel.filteredTopDeeds(matching: trimmedSearch)
                    let searchResults = viewModel.searchResults(for: trimmedSearch)

                    VStack(alignment: .leading, spacing: 12) {
                        deedSearchField(text: $deedSearchText)

                        if filteredTop.isEmpty, !trimmedSearch.isEmpty {
                            Text("No top cards match \"\(trimmedSearch)\".")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        } else {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 8) {
                                    ForEach(filteredTop) { card in
                                        Button {
                                            viewModel.selectedDeedId = card.id
                                        } label: {
                                            HStack(spacing: 6) {
                                                Text(card.emoji)
                                                Text(card.name)
                                                    .lineLimit(1)
                                            }
                                            .font(.subheadline)
                                            .padding(.horizontal, 12)
                                            .padding(.vertical, 8)
                                            .background(
                                                Capsule(style: .continuous)
                                                    .fill(
                                                        viewModel.selectedDeedId == card.id ? Color.accentColor.opacity(0.2) : Color(.systemBackground).opacity(0.6)
                                                    )
                                            )
                                            .overlay(
                                                Capsule(style: .continuous)
                                                    .stroke(viewModel.selectedDeedId == card.id ? Color.accentColor : Color.clear, lineWidth: 1.5)
                                            )
                                            .foregroundStyle(viewModel.selectedDeedId == card.id ? Color.accentColor : .primary)
                                        }
                                        .id(card.id)
                                        .buttonStyle(.plain)
                                    }
                                }
                            }
                        }

                        if !trimmedSearch.isEmpty {
                            if searchResults.isEmpty {
                                Text("No cards found.")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            } else {
                                VStack(alignment: .leading, spacing: 0) {
                                    ForEach(Array(searchResults.enumerated()), id: \.element.id) { index, result in
                                        Button {
                                            viewModel.focusOnDeed(withId: result.id)
                                            deedSearchText = ""
                                        } label: {
                                            HStack(spacing: 12) {
                                                Text(result.emoji)
                                                VStack(alignment: .leading, spacing: 2) {
                                                    Text(result.name)
                                                        .font(.subheadline)
                                                        .fontWeight(.semibold)
                                                    Text(result.category)
                                                        .font(.caption)
                                                        .foregroundStyle(.secondary)
                                                }
                                                Spacer()
                                            }
                                            .padding(.vertical, 10)
                                            .padding(.horizontal, 12)
                                            .contentShape(Rectangle())
                                        }
                                        .buttonStyle(.plain)

                                        if index < searchResults.count - 1 {
                                            Divider()
                                                .padding(.leading, 36)
                                        }
                                    }
                                }
                                .background(
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .fill(Color(.systemBackground).opacity(0.6))
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .stroke(Color(.separator).opacity(0.5), lineWidth: 0.5)
                                )
                            }
                        }
                    }
                    .onChange(of: viewModel.selectedDeedId, initial: false) { _, id in
                        guard let id else { return }
                        withAnimation {
                            proxy.scrollTo(id, anchor: .center)
                        }
                    }
                }

                if viewModel.cardTrendSeries.isEmpty {
                    Text("No activity for \(viewModel.selectedDeedName) in this range.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    StatsChartContainer(points: viewModel.cardTrendSeries) {
                        Chart(viewModel.cardTrendSeries) { point in
                            LineMark(
                                x: .value("Day", point.date),
                                y: .value("Points", point.value)
                            )
                            .foregroundStyle(Color.accentColor)
                            .interpolationMethod(.catmullRom)

                            AreaMark(
                                x: .value("Day", point.date),
                                y: .value("Points", point.value)
                            )
                            .interpolationMethod(.catmullRom)
                            .foregroundStyle(Color.accentColor.gradient.opacity(0.2))
                        }
                        .frame(height: 200)
                        .chartYAxis {
                            AxisMarks(position: .leading)
                        }
                    }
                }
            }
        }
    }

    private func deedSearchField(text: Binding<String>) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)

            TextField("Search deeds", text: text)
                .textFieldStyle(.plain)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 12)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(.systemBackground).opacity(0.6))
        )
    }

    private var insightsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Insights")
                .font(.title2)
                .fontWeight(.semibold)

            VStack(alignment: .leading, spacing: 8) {
                if let comparative = viewModel.comparativeInsight {
                    Label(comparative.message, systemImage: "chart.line.uptrend.xyaxis")
                        .labelStyle(.titleAndIcon)
                } else {
                    Label("Keep logging to see month-over-month momentum.", systemImage: "chart.line.uptrend.xyaxis")
                        .labelStyle(.titleAndIcon)
                        .foregroundStyle(.secondary)
                }

                if let correlation = viewModel.correlationInsight {
                    Label(correlation.message, systemImage: "circle.grid.cross")
                        .labelStyle(.titleAndIcon)
                }
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .glassBackground(cornerRadius: 16, tint: Color.accentColor, warpStrength: 2.5)
        }
    }

    private var contributionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Contribution Breakdown")
                .font(.title2)
                .fontWeight(.semibold)

            ContributionChartView(
                title: "Sources of Positives",
                slices: viewModel.positiveSlices,
                selectedDeedId: viewModel.selectedDeedId,
                onSelectSlice: { slice in
                    if let id = slice.deedId {
                        viewModel.focusOnDeed(withId: id)
                    }
                }
            )
            ContributionChartView(
                title: "Sources of Negatives",
                slices: viewModel.negativeSlices,
                selectedDeedId: viewModel.selectedDeedId,
                onSelectSlice: { slice in
                    if let id = slice.deedId {
                        viewModel.focusOnDeed(withId: id)
                    }
                }
            )
        }
    }
}

private struct ContributionChartView: View {
    var title: String
    var slices: [ContributionSlice]
    var selectedDeedId: UUID?
    var onSelectSlice: ((ContributionSlice) -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)

            if slices.isEmpty {
                Text("No contributions in this range yet.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            } else {
                Chart(slices) { slice in
                    SectorMark(
                        angle: .value("Value", slice.value),
                        innerRadius: .ratio(0.6)
                    )
                    .cornerRadius(4)
                    .foregroundStyle(by: .value("Label", slice.legendLabel))
                    .annotation(position: .overlay) {
                        Text(slice.emoji)
                            .font(.caption)
                    }
                    .opacity(slice.deedId == nil || slice.deedId == selectedDeedId || selectedDeedId == nil ? 1 : 0.35)
                }
                .chartOverlay { proxy in
                    GeometryReader { geometry in
                        if let plotFrame: Anchor<CGRect> = proxy.plotFrame {
                            let origin = geometry[plotFrame].origin
                            Rectangle()
                                .fill(.clear)
                                .contentShape(Rectangle())
                                .gesture(
                                    DragGesture(minimumDistance: 0)
                                        .onEnded { value in
                                            guard let onSelectSlice = onSelectSlice else { return }
                                            let location = CGPoint(
                                                x: value.location.x - origin.x,
                                                y: value.location.y - origin.y
                                            )
                                            if let (series, _) = proxy.value(at: location, as: (String, Double).self) {
                                                if let slice = slices.first(where: { $0.legendLabel == series }) {
                                                    onSelectSlice(slice)
                                                }
                                            }
                                        }
                                )
                        }
                    }
                }
                .chartLegend(.hidden)
                .frame(height: 220)

                VStack(alignment: .leading, spacing: 6) {
                    ForEach(slices) { slice in
                        if let deedId = slice.deedId, let onSelectSlice {
                            Button {
                                onSelectSlice(slice)
                            } label: {
                                HStack {
                                    Text(slice.emoji)
                                    Text(slice.legendLabel)
                                        .fontWeight(.semibold)
                                    Spacer()
                                    Text("\(slice.pointsString) • \(slice.percentageString)")
                                        .font(.caption)
                                        .foregroundStyle(
                                            deedId == selectedDeedId ? Color.accentColor : Color.secondary
                                        )
                                }
                                .font(.subheadline)
                                .foregroundStyle(
                                    deedId == selectedDeedId ? Color.accentColor : Color.primary
                                )
                            }
                            .buttonStyle(.plain)
                        } else {
                            HStack {
                                Text(slice.emoji)
                                Text(slice.legendLabel)
                                    .fontWeight(.semibold)
                                Spacer()
                                Text("\(slice.pointsString) • \(slice.percentageString)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity)
        .glassBackground(cornerRadius: 16, tint: Color.accentColor, warpStrength: 2.5)
    }
}

enum StatsRange: String, CaseIterable, Identifiable {
    case oneWeek
    case oneMonth
    case threeMonths
    case sixMonths
    case oneYear

    var id: String { rawValue }

    var days: Int {
        switch self {
        case .oneWeek: return 7
        case .oneMonth: return 30
        case .threeMonths: return 90
        case .sixMonths: return 180
        case .oneYear: return 365
        }
    }

    var label: String {
        switch self {
        case .oneWeek: return "1W"
        case .oneMonth: return "1M"
        case .threeMonths: return "3M"
        case .sixMonths: return "6M"
        case .oneYear: return "1Y"
        }
    }

    static var maxDays: Int {
        allCases.map { $0.days }.max() ?? 365
    }
}

struct DailyStatPoint: Identifiable, Equatable {
    let date: Date
    let value: Double

    var id: Date { date }

    var formattedValue: String {
        let formatter = NumberFormatter()
        formatter.maximumFractionDigits = 1
        formatter.minimumFractionDigits = 0
        return formatter.string(from: NSNumber(value: value)) ?? "\(value)"
    }
}

struct ContributionSlice: Identifiable, Equatable {
    let id = UUID()
    let deedId: UUID?
    let emoji: String
    let legendLabel: String
    let value: Double
    let percentage: Double

    var pointsString: String {
        let formatter = NumberFormatter()
        formatter.maximumFractionDigits = 1
        formatter.minimumFractionDigits = 0
        return "\(formatter.string(from: NSNumber(value: value)) ?? "0") pts"
    }

    var percentageString: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .percent
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: percentage)) ?? "0%"
    }
}

struct ComparativeInsight: Equatable {
    let message: String
}

struct CorrelationInsight: Equatable {
    let message: String
    let coefficient: Double
}

struct DeedSearchIndex {
    private(set) var allDeeds: [DeedCard] = []
    private(set) var topDeeds: [DeedCard] = []

    mutating func updateAllDeeds(_ deeds: [DeedCard]) {
        allDeeds = deeds.sorted { lhs, rhs in
            lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
        }
    }

    mutating func updateTopDeeds(_ deeds: [DeedCard]) {
        topDeeds = deeds
    }

    func filteredTopDeeds(query: String) -> [DeedCard] {
        guard let components = prepareQuery(from: query) else { return topDeeds }
        return filterTopDeeds(normalized: components.normalized, raw: components.raw)
    }

    func searchResults(query: String) -> [DeedCard] {
        guard let components = prepareQuery(from: query) else { return [] }

        let matchingTopIds = Set(filterTopDeeds(normalized: components.normalized, raw: components.raw).map(\.id))

        return allDeeds.filter { deed in
            matches(deed, normalizedQuery: components.normalized, rawQuery: components.raw) && !matchingTopIds.contains(deed.id)
        }
    }

    private func filterTopDeeds(normalized: String, raw: String) -> [DeedCard] {
        topDeeds.filter { matches($0, normalizedQuery: normalized, rawQuery: raw) }
    }

    private func prepareQuery(from query: String) -> (normalized: String, raw: String)? {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        return (normalize(trimmed), trimmed)
    }

    private func matches(_ deed: DeedCard, normalizedQuery: String, rawQuery: String) -> Bool {
        let normalizedName = normalize(deed.name)
        if normalizedName.contains(normalizedQuery) { return true }

        let normalizedCategory = normalize(deed.category)
        if normalizedCategory.contains(normalizedQuery) { return true }

        if deed.emoji.contains(rawQuery) { return true }

        return false
    }

    private func normalize(_ value: String) -> String {
        value.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale.current)
    }
}

@MainActor
final class StatsPageViewModel: ObservableObject {
    @Published var selectedRange: StatsRange = .oneMonth {
        didSet {
            guard isReady, oldValue != selectedRange else { return }
            updateForRangeChange()
        }
    }

    @Published var selectedDeedId: UUID? {
        didSet {
            guard isReady, oldValue != selectedDeedId else { return }
            updateCardTrend()
            updateInsights()
        }
    }

    @Published private(set) var isLoading: Bool = true
    @Published private(set) var dailyNetSeries: [DailyStatPoint] = []
    @Published private(set) var todayPoint: DailyStatPoint?
    @Published private(set) var cardTrendSeries: [DailyStatPoint] = []
    @Published private(set) var topDeeds: [DeedCard] = [] {
        didSet { searchIndex.updateTopDeeds(topDeeds) }
    }
    @Published private(set) var positiveSlices: [ContributionSlice] = []
    @Published private(set) var negativeSlices: [ContributionSlice] = []
    @Published private(set) var comparativeInsight: ComparativeInsight?
    @Published private(set) var correlationInsight: CorrelationInsight?
    @Published private(set) var hasAnyEntries: Bool = false

#if DEBUG
    static var correlationLogHandler: ((String, Double, Int) -> Void)?
#endif

    var selectedDeedName: String {
        guard let id = selectedDeedId, let deed = deedsById[id] else { return "this card" }
        return deed.name
    }

    func filteredTopDeeds(matching query: String) -> [DeedCard] {
        searchIndex.filteredTopDeeds(query: query)
    }

    func searchResults(for query: String) -> [DeedCard] {
        searchIndex.searchResults(query: query)
    }

    private var calendar: Calendar
    private var cutoffHour: Int = 4
    private var isReady = false
    private var deedsById: [UUID: DeedCard] = [:]
    private var dailyNetValues: [Date: Double] = [:]
    private var perDeedPoints: [UUID: [Date: Double]] = [:]
    private var perDeedPositivePoints: [UUID: [Date: Double]] = [:]
    private var perDeedNegativePoints: [UUID: [Date: Double]] = [:]
    private var perCategoryPositivePoints: [String: [Date: Double]] = [:]
    private var searchIndex = DeedSearchIndex()
    private var persistenceController: PersistenceController?

    init() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone.current
        calendar.locale = Locale.current
        self.calendar = calendar
    }

    func configureIfNeeded(environment: AppEnvironment) async {
        cutoffHour = environment.settings.dayCutoffHour
        persistenceController = environment.persistenceController

        await reloadData()
    }

    func updateCutoffHour(_ hour: Int) async {
        guard hour != cutoffHour else { return }
        cutoffHour = hour
        // Re-ingest entries to respect the new cutoff boundaries.
        await reloadData()
    }

    func forceReload() async {
        await reloadData()
    }

    private func reloadData() async {
        guard let persistence = persistenceController else { return }
        isReady = false
        isLoading = true
        hasAnyEntries = false

        do {
            try loadData(context: persistence.viewContext)
            isReady = true
            isLoading = false
            updateForRangeChange()
            updateCardTrend()
            updateInsights()
        } catch {
            isLoading = false
            print("Failed to load stats: \(error)")
        }
    }

    private func loadData(context: NSManagedObjectContext) throws {
        let deeds = try DeedsRepository(context: context).fetchAll(includeArchived: true)
        deedsById = Dictionary(uniqueKeysWithValues: deeds.map { ($0.id, $0) })
        searchIndex.updateAllDeeds(deeds.filter { $0.showOnStats })

        let range = dateRange(forDays: StatsRange.maxDays)
        let entries = try EntriesRepository(context: context).fetchEntries(in: range)

        hasAnyEntries = !entries.isEmpty

        ingest(entries: entries)
        rebuildTopDeeds()
    }

    private func ingest(entries: [DeedEntry]) {
        dailyNetValues = [:]
        perDeedPoints = [:]
        perDeedPositivePoints = [:]
        perDeedNegativePoints = [:]
        perCategoryPositivePoints = [:]

        for entry in entries {
            guard let deed = deedsById[entry.deedId] else { continue }
            let dayStart = dayStart(for: entry.timestamp)
            let value = entry.computedPoints

            dailyNetValues[dayStart, default: 0] += value
            guard deed.showOnStats else { continue }

            perDeedPoints[deed.id, default: [:]][dayStart, default: 0] += value

            if value > 0 {
                perDeedPositivePoints[deed.id, default: [:]][dayStart, default: 0] += value
                perCategoryPositivePoints[deed.category, default: [:]][dayStart, default: 0] += value
            } else if value < 0 {
                perDeedNegativePoints[deed.id, default: [:]][dayStart, default: 0] += abs(value)
            }
        }
    }

    private func rebuildTopDeeds() {
        let ranked = perDeedPoints.compactMap { id, daily -> (DeedCard, Double)? in
            guard let deed = deedsById[id] else { return nil }
            let total = daily.values.reduce(0) { $0 + abs($1) }
            return (deed, total)
        }
        .sorted { $0.1 > $1.1 }
        .prefix(10)

        var updated = ranked.map { $0.0 }

        if let selected = selectedDeedId,
           let deed = deedsById[selected],
           !updated.contains(where: { $0.id == selected }) {
            updated.insert(deed, at: 0)
        }

        if updated.count > 10 {
            updated = Array(updated.prefix(10))
        }

        topDeeds = updated

        if topDeeds.isEmpty {
            selectedDeedId = nil
        } else if let current = selectedDeedId, topDeeds.contains(where: { $0.id == current }) {
            return
        } else {
            selectedDeedId = topDeeds.first?.id
        }
    }

    private func updateForRangeChange() {
        updateDailyNetSeries()
        updateContributionSlices()
        updateCardTrend()
        updateInsights()
    }

    func focusOnDeed(withId id: UUID) {
        guard let deed = deedsById[id] else { return }

        var updated = topDeeds
        if let existingIndex = updated.firstIndex(where: { $0.id == id }) {
            updated.remove(at: existingIndex)
        }
        updated.insert(deed, at: 0)
        if updated.count > 10 {
            updated = Array(updated.prefix(10))
        }
        topDeeds = updated
        selectedDeedId = id
    }

    private func updateDailyNetSeries() {
        let dayStarts = daySequence(for: selectedRange)
        dailyNetSeries = dayStarts.map { start in
            DailyStatPoint(date: start, value: dailyNetValues[start] ?? 0)
        }

        let todayStart = dayStart(for: Date())
        if let value = dailyNetValues[todayStart] {
            todayPoint = DailyStatPoint(date: todayStart, value: value)
        } else if dayStarts.contains(todayStart) {
            todayPoint = DailyStatPoint(date: todayStart, value: 0)
        } else {
            todayPoint = nil
        }
    }

    private func updateCardTrend() {
        guard let selectedId = selectedDeedId else {
            cardTrendSeries = []
            return
        }
        let dayStarts = daySequence(for: selectedRange)
        let daily = perDeedPoints[selectedId] ?? [:]
        cardTrendSeries = dayStarts.map { start in
            DailyStatPoint(date: start, value: daily[start] ?? 0)
        }
    }

    private func updateContributionSlices() {
        let dayStarts = daySequence(for: selectedRange)

        positiveSlices = buildSlices(
            totals: perDeedPositivePoints.mapValues { dayMap in
                dayStarts.reduce(0) { $0 + (dayMap[$1] ?? 0) }
            },
            includeEmoji: true
        )

        negativeSlices = buildSlices(
            totals: perDeedNegativePoints.mapValues { dayMap in
                dayStarts.reduce(0) { $0 + (dayMap[$1] ?? 0) }
            },
            includeEmoji: true
        )
    }

    private func buildSlices(totals: [UUID: Double], includeEmoji: Bool) -> [ContributionSlice] {
        let filtered = totals.compactMap { id, value -> (DeedCard, Double)? in
            guard let deed = deedsById[id], value > 0 else { return nil }
            return (deed, value)
        }
        .sorted { $0.1 > $1.1 }

        guard !filtered.isEmpty else { return [] }

        let top = filtered.prefix(6)
        let remainder = filtered.dropFirst(6).reduce(0) { $0 + $1.1 }
        let total = top.reduce(remainder) { $0 + $1.1 }

        var slices: [ContributionSlice] = top.map { deed, value in
            ContributionSlice(
                deedId: deed.id,
                emoji: includeEmoji ? deed.emoji : "",
                legendLabel: deed.name,
                value: value,
                percentage: total > 0 ? value / total : 0
            )
        }

        if remainder > 0 {
            slices.append(
                ContributionSlice(
                    deedId: nil,
                    emoji: "…",
                    legendLabel: "Others",
                    value: remainder,
                    percentage: total > 0 ? remainder / total : 0
                )
            )
        }

        return slices
    }

    private func updateInsights() {
        comparativeInsight = buildComparativeInsight()
        correlationInsight = buildCorrelationInsight()
    }

    private func buildComparativeInsight() -> ComparativeInsight? {
        guard !perCategoryPositivePoints.isEmpty else { return nil }

        let todayStart = dayStart(for: Date())
        guard let dayIndex = calendar.dateComponents([.day], from: monthStart(for: todayStart), to: todayStart).day else {
            return nil
        }

        let currentDays = dayIndex + 1
        let currentStarts = daySequence(startingAt: monthStart(for: todayStart), count: currentDays)
        let previousMonthStart = previousMonthStart(for: todayStart)
        let previousStarts = daySequence(startingAt: previousMonthStart, count: currentDays)

        let comparisons: [CategoryComparison] = perCategoryPositivePoints.map { category, dayMap in
            let currentTotal = currentStarts.reduce(0) { $0 + (dayMap[$1] ?? 0) }
            let previousTotal = previousStarts.reduce(0) { $0 + (dayMap[$1] ?? 0) }
            return CategoryComparison(category: category, current: currentTotal, previous: previousTotal)
        }

        guard let best = StatsMath.bestImprovement(from: comparisons) else { return nil }

        if best.percent <= 0 {
            return ComparativeInsight(message: "You’re slightly behind last month.")
        }

        let formatter = NumberFormatter()
        formatter.numberStyle = .percent
        formatter.maximumFractionDigits = 0
        let percentString = formatter.string(from: NSNumber(value: best.percent)) ?? "0%"
        return ComparativeInsight(message: "You’re doing \(percentString) better than last month in \(best.category)")
    }

    private func buildCorrelationInsight() -> CorrelationInsight? {
        let positiveDeeds = deedsById.values.filter { $0.polarity == .positive }
        guard !positiveDeeds.isEmpty else { return nil }

        let dayStarts = daySequence(forDays: 60)
        let netSeries = dayStarts.map { dailyNetValues[$0] ?? 0 }

        var bestResult: (DeedCard, Double, Int)?

        for deed in positiveDeeds {
            let positivePoints = perDeedPositivePoints[deed.id] ?? [:]
            let sampleCount = dayStarts.reduce(into: 0) { count, dayStart in
                guard dailyNetValues[dayStart] != nil, positivePoints[dayStart] != nil else { return }
                count += 1
            }

            guard sampleCount >= 20 else { continue }

            let deedSeries = dayStarts.map { positivePoints[$0] ?? 0 }
            guard deedSeries.contains(where: { $0 != 0 }) else { continue }
            guard let r = StatsMath.pearsonCorrelation(x: netSeries, y: deedSeries) else { continue }
            guard abs(r) >= 0.35 else { continue }

            logCorrelation(deedName: deed.name, coefficient: r, sampleSize: sampleCount)

            if bestResult == nil || abs(r) > abs(bestResult!.1) {
                bestResult = (deed, r, sampleCount)
            }
        }

        guard let result = bestResult else { return nil }
        let deedName = result.0.name.lowercased()
        let message: String
        if result.1 >= 0 {
            message = "You tend to score higher on days you \(deedName)"
        } else {
            message = "You tend to score lower on days you \(deedName)"
        }

        return CorrelationInsight(
            message: message,
            coefficient: result.1
        )
    }

    private func logCorrelation(deedName: String, coefficient: Double, sampleSize: Int) {
        let formatted = String(format: "%.4f", coefficient)
        let message = "Correlation candidate for \(deedName): r=\(formatted), samples=\(sampleSize)"
#if DEBUG
        StatsPageViewModel.correlationLogHandler?(deedName, coefficient, sampleSize)
#endif
        print(message)
    }

    private func daySequence(for range: StatsRange) -> [Date] {
        daySequence(forDays: range.days)
    }

    private func daySequence(forDays dayCount: Int) -> [Date] {
        let todayStart = dayStart(for: Date())
        let start = calendar.date(byAdding: .day, value: -(dayCount - 1), to: todayStart) ?? todayStart
        return daySequence(startingAt: start, count: dayCount)
    }

    private func daySequence(startingAt start: Date, count: Int) -> [Date] {
        guard count > 0 else { return [] }
        return (0..<count).compactMap { offset in
            calendar.date(byAdding: .day, value: offset, to: start)
        }
    }

    private func dayRange(for date: Date) -> (start: Date, end: Date) {
        appDayRange(for: date, cutoffHour: cutoffHour, calendar: calendar)
    }

    private func dayStart(for date: Date) -> Date {
        dayRange(for: date).start
    }

    private func monthStart(for date: Date) -> Date {
        let components = calendar.dateComponents([.year, .month], from: date)
        let midnight = calendar.date(from: components) ?? date
        return calendar.date(bySettingHour: cutoffHour, minute: 0, second: 0, of: midnight) ?? midnight
    }

    private func previousMonthStart(for date: Date) -> Date {
        let currentMonthStart = monthStart(for: date)
        let previousMidnight = calendar.date(byAdding: .month, value: -1, to: currentMonthStart) ?? currentMonthStart
        return calendar.date(bySettingHour: cutoffHour, minute: 0, second: 0, of: previousMidnight) ?? previousMidnight
    }

    private func dateRange(forDays days: Int) -> ClosedRange<Date> {
        let todayRange = dayRange(for: Date())
        let start = calendar.date(byAdding: .day, value: -(days - 1), to: todayRange.start) ?? todayRange.start
        return start...todayRange.end
    }
}

#if DEBUG
extension StatsPageViewModel {
    func testInjectCorrelationData(
        deeds: [UUID: DeedCard],
        dailyNet: [Date: Double],
        positivePoints: [UUID: [Date: Double]]
    ) {
        deedsById = deeds
        dailyNetValues = dailyNet
        perDeedPositivePoints = positivePoints
    }

    func testCorrelationInsight() -> CorrelationInsight? {
        buildCorrelationInsight()
    }

    func testDaySequence(forDays dayCount: Int) -> [Date] {
        daySequence(forDays: dayCount)
    }
}
#endif

struct CategoryComparison: Equatable {
    let category: String
    let current: Double
    let previous: Double
}

enum StatsMath {
    static func bestImprovement(from comparisons: [CategoryComparison]) -> (category: String, percent: Double)? {
        let evaluated = comparisons.compactMap { comparison -> (String, Double)? in
            let previous = comparison.previous
            let current = comparison.current

            if previous == 0 {
                if current == 0 { return nil }
                return (comparison.category, current > 0 ? 1 : -1)
            }

            let percentChange = (current - previous) / previous
            return (comparison.category, percentChange)
        }

        return evaluated.max { lhs, rhs in lhs.1 < rhs.1 }
    }

    static func pearsonCorrelation(x: [Double], y: [Double]) -> Double? {
        guard x.count == y.count, x.count >= 2 else { return nil }
        let meanX = x.reduce(0, +) / Double(x.count)
        let meanY = y.reduce(0, +) / Double(y.count)

        var numerator: Double = 0
        var sumSqX: Double = 0
        var sumSqY: Double = 0

        for (xi, yi) in zip(x, y) {
            let dx = xi - meanX
            let dy = yi - meanY
            numerator += dx * dy
            sumSqX += dx * dx
            sumSqY += dy * dy
        }

        let denominator = sqrt(sumSqX) * sqrt(sumSqY)
        guard denominator != 0 else { return nil }
        return numerator / denominator
    }
}

#Preview {
    StatsPage()
        .environmentObject(AppEnvironment())
}

