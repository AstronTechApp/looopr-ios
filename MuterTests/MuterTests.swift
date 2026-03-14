import XCTest
@testable import Muter

final class MuterTests: XCTestCase {
    func testAppConfigurationExists() {
        let config = AppConfiguration.current
        XCTAssertEqual(config.freemium.freeRouteLimit, 1)
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

    func testUserDefaultsStore() throws {
        let store = UserDefaultsStore(defaults: UserDefaults(suiteName: "test")!)
        try store.save("hello", forKey: "test.key")
        let loaded = try store.load(String.self, forKey: "test.key")
        XCTAssertEqual(loaded, "hello")
        try store.delete(forKey: "test.key")
        XCTAssertFalse(store.exists(forKey: "test.key"))
    }
}
