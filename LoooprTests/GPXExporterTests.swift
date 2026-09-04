import XCTest
import CoreLocation
@testable import Looopr

final class GPXExporterTests: XCTestCase {

    private func makeSession(pointCount: Int) -> WalkSession {
        let start = Date(timeIntervalSince1970: 1_700_000_000)
        var points: [TrackPoint] = []
        var coordinate = CLLocationCoordinate2D(latitude: 52.3676, longitude: 4.9041)
        for i in 0..<pointCount {
            coordinate = coordinate.coordinate(at: 5, bearing: 90)
            points.append(TrackPoint(
                latitude: coordinate.latitude,
                longitude: coordinate.longitude,
                altitude: i % 2 == 0 ? 2.5 : nil,
                timestamp: start.addingTimeInterval(Double(i) * 4),
                horizontalAccuracy: 5
            ))
        }
        return WalkSession(
            routeId: UUID(),
            startedAt: start,
            finishedAt: start.addingTimeInterval(Double(pointCount) * 4),
            distanceWalkedMeters: Double(pointCount) * 5,
            durationSeconds: Double(pointCount) * 4,
            routeName: "Jordaan & Canals <Loop>",
            trackPoints: pointCount > 0 ? points : nil
        )
    }

    func testGPXContainsEveryTrackpointWithUTCTime() throws {
        let session = makeSession(pointCount: 10)
        let gpx = try XCTUnwrap(GPXExporter.gpxString(for: session))

        XCTAssertTrue(gpx.hasPrefix("<?xml version=\"1.0\" encoding=\"UTF-8\"?>"))
        XCTAssertTrue(gpx.contains("<gpx version=\"1.1\" creator=\"Looopr\""))
        XCTAssertEqual(gpx.components(separatedBy: "<trkpt ").count - 1, 10)
        XCTAssertEqual(gpx.components(separatedBy: "<time>").count - 1, 11, "metadata time + one per trackpoint")
        XCTAssertTrue(gpx.contains("<time>2023-11-14T22:13:20Z</time>"), "timestamps must be UTC ISO-8601")
        XCTAssertEqual(gpx.components(separatedBy: "<ele>").count - 1, 5, "altitude only when known")
        XCTAssertTrue(gpx.contains("<type>walking</type>"))
    }

    func testGPXEscapesRouteName() throws {
        let gpx = try XCTUnwrap(GPXExporter.gpxString(for: makeSession(pointCount: 3)))
        XCTAssertTrue(gpx.contains("<name>Jordaan &amp; Canals &lt;Loop&gt;</name>"))
        XCTAssertFalse(gpx.contains("<Loop>"))
    }

    func testGPXUsesDotDecimalSeparatorRegardlessOfLocale() throws {
        let gpx = try XCTUnwrap(GPXExporter.gpxString(for: makeSession(pointCount: 2)))
        XCTAssertTrue(gpx.contains("lat=\"52.36"))
        XCTAssertFalse(gpx.contains("lat=\"52,"))
    }

    func testSessionsWithoutTrackCannotBeExported() {
        XCTAssertNil(GPXExporter.gpxString(for: makeSession(pointCount: 0)))
        XCTAssertNil(GPXExporter.gpxString(for: makeSession(pointCount: 1)), "a single point is not a track")
        XCTAssertThrowsError(try GPXExporter.writeTemporaryFile(for: makeSession(pointCount: 0)))
    }

    func testTemporaryFileHasGPXExtension() throws {
        let url = try GPXExporter.writeTemporaryFile(for: makeSession(pointCount: 5))
        XCTAssertEqual(url.pathExtension, "gpx")
        XCTAssertTrue(url.lastPathComponent.hasPrefix("Looopr_Jordaan-Canals-Loop_"))
        XCTAssertTrue(FileManager.default.fileExists(atPath: url.path))
    }

    func testTrackPointsSurviveSessionCodingRoundTrip() throws {
        let session = makeSession(pointCount: 4)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        let data = try encoder.encode(session)
        let json = try XCTUnwrap(String(data: data, encoding: .utf8))
        XCTAssertTrue(json.contains("\"lat\":"), "compact coding keys keep stored tracks small")

        let decoded = try decoder.decode(WalkSession.self, from: data)
        XCTAssertEqual(decoded.trackPoints?.count, 4)
        XCTAssertEqual(decoded.trackPoints?.first?.horizontalAccuracy, 5)
        XCTAssertTrue(decoded.hasTrack)
    }

    func testLegacySessionsWithoutTrackPointsStillDecode() throws {
        let legacyJSON = """
        {"id":"\(UUID().uuidString)","routeId":"\(UUID().uuidString)","startedAt":700000000,
         "distanceWalkedMeters":1200,"durationSeconds":900,"stepCount":1500,"visitedFoodStops":[]}
        """
        let session = try JSONDecoder().decode(WalkSession.self, from: Data(legacyJSON.utf8))
        XCTAssertNil(session.trackPoints)
        XCTAssertFalse(session.hasTrack)
    }
}
