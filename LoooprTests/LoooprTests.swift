import XCTest
@testable import Looopr

final class LoooprTests: XCTestCase {
    func testAppConfigurationExists() {
        let config = AppConfiguration.current
        XCTAssertEqual(config.freemium.freeRouteLimit, 2)
        XCTAssertEqual(config.freemium.paidRouteLimit, 8)
    }

    func testPOICategoryClassification() {
        XCTAssertTrue(POICategory.museum.isTouristAttraction)
        XCTAssertFalse(POICategory.restaurant.isTouristAttraction)
        XCTAssertTrue(POICategory.cafe.isFood)
        XCTAssertFalse(POICategory.park.isFood)
    }

    func testLocationConversion() {
        let location = Location(latitude: 52.3676, longitude: 4.9041)
        let coordinate = location.clCoordinate
        XCTAssertEqual(coordinate.latitude, 52.3676)
        XCTAssertEqual(coordinate.longitude, 4.9041)
    }

    func testFileStoreRoundTripAndMigration() throws {
        let suite = "filestore-test-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = FileStore(defaults: defaults)
        let key = "test.migration.\(UUID().uuidString)"
        defer { try? store.delete(forKey: key) }

        // Migration path: value planted in UserDefaults, read via FileStore.
        let legacy = try JSONEncoder().encode(["a", "b"])
        defaults.set(legacy, forKey: key)
        XCTAssertEqual(try store.load([String].self, forKey: key), ["a", "b"])
        XCTAssertNil(defaults.data(forKey: key), "migration should remove the UserDefaults copy")

        // Normal round trip now served from the file.
        try store.save(["c"], forKey: key)
        XCTAssertEqual(try store.load([String].self, forKey: key), ["c"])
        XCTAssertTrue(store.exists(forKey: key))
        try store.delete(forKey: key)
        XCTAssertFalse(store.exists(forKey: key))
    }

    func testUserDefaultsStore() throws {
        let store = UserDefaultsStore(defaults: UserDefaults(suiteName: "test")!)
        try store.save("hello", forKey: "test.key")
        let loaded = try store.load(String.self, forKey: "test.key")
        XCTAssertEqual(loaded, "hello")
        try store.delete(forKey: "test.key")
        XCTAssertFalse(store.exists(forKey: "test.key"))
    }
}
