import XCTest
@testable import Looopr

final class POIOpeningHoursTests: XCTestCase {
    func testPlannedDepartureUsesStructuredOpeningPeriods() throws {
        let calendar = Calendar.current
        let departure = try XCTUnwrap(calendar.date(from: DateComponents(
            year: 2026,
            month: 4,
            day: 30,
            hour: 17,
            minute: 0
        )))
        let day = calendar.component(.weekday, from: departure) - 1
        let periods = [
            OpeningHoursPeriod(
                openDay: day,
                openHour: 16,
                openMinute: 0,
                closeDay: day,
                closeHour: 23,
                closeMinute: 0
            )
        ]

        XCTAssertEqual(
            poiOpenStatus(isOpenNow: false, weekdayText: nil, periods: periods, at: departure),
            .open
        )
    }

    func testPlannedDepartureCanDetectClosedFromStructuredPeriods() throws {
        let calendar = Calendar.current
        let departure = try XCTUnwrap(calendar.date(from: DateComponents(
            year: 2026,
            month: 4,
            day: 30,
            hour: 10,
            minute: 0
        )))
        let day = calendar.component(.weekday, from: departure) - 1
        let periods = [
            OpeningHoursPeriod(
                openDay: day,
                openHour: 16,
                openMinute: 0,
                closeDay: day,
                closeHour: 23,
                closeMinute: 0
            )
        ]

        XCTAssertEqual(
            poiOpenStatus(isOpenNow: true, weekdayText: nil, periods: periods, at: departure),
            .closed
        )
    }

    func testPlannedDepartureFallsBackToWeekdayText() throws {
        let departure = try XCTUnwrap(Calendar.current.date(from: DateComponents(
            year: 2026,
            month: 4,
            day: 30,
            hour: 17,
            minute: 0
        )))
        let weekdayText = [
            "Monday: Closed",
            "Tuesday: Closed",
            "Wednesday: Closed",
            "Thursday: 4:00 PM - 11:00 PM",
            "Friday: Closed",
            "Saturday: Closed",
            "Sunday: Closed"
        ]

        XCTAssertEqual(
            poiOpenStatus(isOpenNow: false, weekdayText: weekdayText, at: departure),
            .open
        )
    }
}
