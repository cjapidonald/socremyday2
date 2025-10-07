import XCTest
import CoreData
@testable import scoremyday2

final class DemoDataServiceTests: XCTestCase {
    var persistence: PersistenceController!
    var prefsRepository: AppPrefsRepository!

    override func setUpWithError() throws {
        persistence = PersistenceController(inMemory: true)
        prefsRepository = AppPrefsRepository(context: persistence.viewContext)
    }

    override func tearDownWithError() throws {
        persistence = nil
        prefsRepository = nil
    }

    func testResetAllDataPreservesExistingPreferences() throws {
        var prefs = try prefsRepository.fetch()
        prefs.dayCutoffHour = 9
        prefs.hapticsOn = false
        prefs.soundsOn = false
        prefs.accentColorHex = "#123456"
        try prefsRepository.update(prefs)

        let service = DemoDataService(persistenceController: persistence)
        try service.resetAllData()

        let storedPrefs = try prefsRepository.fetch()
        XCTAssertEqual(storedPrefs.dayCutoffHour, 9)
        XCTAssertFalse(storedPrefs.hapticsOn)
        XCTAssertFalse(storedPrefs.soundsOn)
        XCTAssertEqual(storedPrefs.accentColorHex, "#123456")
    }
}
