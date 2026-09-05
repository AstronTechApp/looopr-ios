import Foundation

/// Builds a GPX 1.1 file from a walk's recorded GPS track.
///
/// The output is what Strava's uploader (web today, API later), Komoot,
/// Garmin Connect etc. expect: a single `<trk>` with one `<trkseg>`, every
/// `<trkpt>` carrying a UTC `<time>`. Walks without a recorded track
/// (recorded before track recording existed) cannot be exported — the
/// planned route has no timestamps and we don't fabricate them.
enum GPXExporter {

    enum ExportError: LocalizedError {
        case noTrack

        var errorDescription: String? {
            switch self {
            case .noTrack:
                return L10n.GPX.noTrack
            }
        }
    }

    /// GPX 1.1 document for the session, or `nil` when it has no usable track.
    static func gpxString(for session: WalkSession) -> String? {
        guard session.hasTrack, let points = session.trackPoints else { return nil }

        let name = escape(session.routeName.map(L10n.RouteName.localized) ?? "Looopr walk")
        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withInternetDateTime]
        isoFormatter.timeZone = TimeZone(identifier: "UTC")

        var xml = """
        <?xml version="1.0" encoding="UTF-8"?>
        <gpx version="1.1" creator="Looopr" xmlns="http://www.topografix.com/GPX/1/1" \
        xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" \
        xsi:schemaLocation="http://www.topografix.com/GPX/1/1 http://www.topografix.com/GPX/1/1/gpx.xsd">
          <metadata>
            <name>\(name)</name>
            <time>\(isoFormatter.string(from: session.startedAt))</time>
          </metadata>
          <trk>
            <name>\(name)</name>
            <type>walking</type>
            <trkseg>

        """

        for point in points {
            xml += "      <trkpt lat=\"\(format(point.latitude))\" lon=\"\(format(point.longitude))\">\n"
            if let altitude = point.altitude {
                xml += "        <ele>\(format(altitude, decimals: 1))</ele>\n"
            }
            xml += "        <time>\(isoFormatter.string(from: point.timestamp))</time>\n"
            xml += "      </trkpt>\n"
        }

        xml += """
            </trkseg>
          </trk>
        </gpx>

        """
        return xml
    }

    /// Writes the GPX to a temporary file suitable for the system share sheet
    /// (the `.gpx` extension is what lets other apps recognise it).
    static func writeTemporaryFile(for session: WalkSession) throws -> URL {
        guard let gpx = gpxString(for: session) else { throw ExportError.noTrack }

        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("gpx-export", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        let url = directory.appendingPathComponent("\(fileName(for: session)).gpx")
        try gpx.write(to: url, atomically: true, encoding: .utf8)
        return url
    }

    // MARK: - Helpers

    static func fileName(for session: WalkSession) -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.locale = Locale(identifier: "en_US_POSIX")
        dateFormatter.dateFormat = "yyyy-MM-dd_HHmm"
        let date = dateFormatter.string(from: session.startedAt)

        let base = (session.routeName.map(L10n.RouteName.localized) ?? "Looopr walk")
            .components(separatedBy: CharacterSet.alphanumerics.union(.whitespaces).inverted)
            .joined()
            .trimmingCharacters(in: .whitespaces)
            .replacingOccurrences(of: " ", with: "-")
        return "Looopr_\(base.isEmpty ? "walk" : base)_\(date)"
    }

    private static func format(_ value: Double, decimals: Int = 6) -> String {
        String(format: "%.\(decimals)f", locale: Locale(identifier: "en_US_POSIX"), value)
    }

    private static func escape(_ text: String) -> String {
        text
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
    }
}
