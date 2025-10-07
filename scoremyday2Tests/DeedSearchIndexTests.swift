import XCTest
@testable import scoremyday2

final class DeedSearchIndexTests: XCTestCase {
    func testFilteredTopDeedsReturnsAllWhenQueryIsEmpty() {
        let hydrate = makeDeed(name: "Drink Water", emoji: "💧", category: "Wellness")
        let stretch = makeDeed(name: "Morning Stretch", emoji: "🧘", category: "Fitness")

        var index = DeedSearchIndex()
        index.updateTopDeeds([hydrate, stretch])

        let results = index.filteredTopDeeds(query: "")
        XCTAssertEqual(results.map(\.id), [hydrate.id, stretch.id])
    }

    func testFilteredTopDeedsMatchesCaseInsensitiveQueries() {
        let hydrate = makeDeed(name: "Drink Water", emoji: "💧", category: "Wellness")
        let journal = makeDeed(name: "Evening Journal", emoji: "📓", category: "Reflection")

        var index = DeedSearchIndex()
        index.updateTopDeeds([hydrate, journal])

        let results = index.filteredTopDeeds(query: "journal")
        XCTAssertEqual(results.map(\.id), [journal.id])
    }

    func testSearchResultsExcludeTopMatchesAndRemainSorted() {
        let hydrate = makeDeed(name: "Drink Water", emoji: "💧", category: "Wellness")
        let sleepTracker = makeDeed(name: "Sleep Tracker", emoji: "😴", category: "Wellness")
        let tea = makeDeed(name: "Tea for Sleep", emoji: "🍵", category: "Wellness")
        let meditation = makeDeed(name: "Meditation for Sleep", emoji: "🧘", category: "Calm")

        var index = DeedSearchIndex()
        index.updateTopDeeds([sleepTracker, hydrate])
        index.updateAllDeeds([tea, hydrate, meditation, sleepTracker])

        let results = index.searchResults(query: "sleep")
        XCTAssertEqual(results.map(\.id), [meditation.id, tea.id])
    }

    func testSearchResultsMatchEmojiAndCategory() {
        let walk = makeDeed(name: "Evening Walk", emoji: "🚶", category: "Fitness")
        let yoga = makeDeed(name: "Morning Yoga", emoji: "🧘", category: "Mindfulness")
        let breathing = makeDeed(name: "Breathing Practice", emoji: "🌬", category: "Mindfulness")

        var index = DeedSearchIndex()
        index.updateTopDeeds([walk])
        index.updateAllDeeds([walk, yoga, breathing])

        let emojiResults = index.searchResults(query: "🧘")
        XCTAssertEqual(emojiResults.map(\.id), [yoga.id])

        let categoryResults = index.searchResults(query: "mindfulness")
        XCTAssertEqual(categoryResults.map(\.id), [breathing.id, yoga.id])
    }

    private func makeDeed(name: String, emoji: String, category: String) -> DeedCard {
        DeedCard(
            name: name,
            emoji: emoji,
            colorHex: "#FFFFFF",
            category: category,
            polarity: .positive,
            unitType: .count,
            unitLabel: "x",
            pointsPerUnit: 1,
            dailyCap: nil,
            isPrivate: false,
            showOnStats: true,
            createdAt: Date(timeIntervalSince1970: 0),
            isArchived: false
        )
    }
}
