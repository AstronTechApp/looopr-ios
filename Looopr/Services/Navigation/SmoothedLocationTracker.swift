import CoreLocation
import Foundation
import QuartzCore

/// Turns the ~1 Hz stream of raw GPS fixes into a continuously moving
/// display position and heading for the navigation map.
///
/// Raw fixes are used unchanged for everything that needs the truth —
/// track recording, off-route detection, step progress. This tracker only
/// decides *where the puck and camera are drawn*, and does three things:
///
/// 1. **Snaps to the route.** A fix within `snapThresholdMeters` of the
///    active polyline is projected onto it, which removes lateral GPS
///    wobble so the puck slides along the line (Google Maps behaviour).
///    Further away than that, the raw fix is shown so a real detour is
///    visible.
/// 2. **Interpolates between fixes.** A 30 fps display loop eases the drawn
///    position toward the latest fix and extrapolates along the current
///    speed and course, so the puck keeps walking instead of jumping every
///    time a fix lands.
/// 3. **Low-passes the heading.** Compass and GPS course are blended into
///    one smoothly rotating heading, so camera rotation never stutters.
@MainActor @Observable
final class SmoothedLocationTracker: NSObject {

    // MARK: - Output (read by the map)

    /// Where to draw the puck and aim the camera. Nil until the first usable fix.
    private(set) var displayCoordinate: CLLocationCoordinate2D?
    /// Direction the map should face, degrees, 0 = north.
    private(set) var displayHeading: CLLocationDirection = 0
    /// Increments every display frame. Observe this (not the coordinate) to
    /// drive the camera, so one observer covers position *and* heading.
    private(set) var frame: Int = 0
    /// True when the drawn position is the route projection rather than the raw fix.
    private(set) var isSnappedToRoute = false
    /// True while the user is walking the route against its planned
    /// direction. The puck arrow then faces route bearing + 180° and
    /// between-fix extrapolation runs backwards along the polyline. Has
    /// hysteresis (see `reversalEnterDegrees` …) so a glance sideways or a
    /// noisy course sample can't flip it. Reset by `setRoute`.
    private(set) var isReversed = false

    // MARK: - Tuning

    /// Fixes less accurate than this are not used for display (metres).
    var displayAccuracyLimitMeters: Double = 30
    /// Fixes older than this on arrival are stale cache and ignored.
    var maxFixAgeSeconds: TimeInterval = 10
    /// Snap to the route when within this many metres (widened for poor accuracy).
    var snapThresholdMeters: Double = 15
    /// Time constant for position easing. Smaller = tighter, larger = smoother.
    var positionTimeConstant: TimeInterval = 0.6
    /// Time constant for heading easing.
    var headingTimeConstant: TimeInterval = 0.35
    /// Don't predict further than this past the last fix (seconds).
    var maxExtrapolationSeconds: TimeInterval = 2.0
    /// A target further than this from the drawn position is a GPS jump or a
    /// reroute: teleport instead of gliding across the map.
    var teleportDistanceMeters: Double = 60
    /// Below this speed (m/s) the user is treated as standing still.
    var movingSpeedThreshold: Double = 0.5
    /// Reversal detection: the user is walking the route backwards once the
    /// GPS course differs from the route bearing by more than
    /// `reversalEnterDegrees` continuously for `reversalEnterSeconds` while
    /// moving (valid course, speed ≥ `movingSpeedThreshold`). It clears again
    /// once the difference stays below `reversalExitDegrees` for
    /// `reversalExitSeconds`. The dead band between the two angles keeps
    /// the state where it is.
    var reversalEnterDegrees: Double = 120
    var reversalExitDegrees: Double = 60
    var reversalEnterSeconds: TimeInterval = 3
    var reversalExitSeconds: TimeInterval = 3

    // MARK: - State

    private var latestFix: CLLocation?
    private var latestFixTime: TimeInterval = 0
    /// Snapped (or raw) position of the latest fix, and the bearing of the
    /// route segment it sits on (nil when not snapped).
    private var anchor: CLLocationCoordinate2D?
    private var anchorRouteBearing: CLLocationDirection?
    private var smoothedSpeed: Double = 0
    private var courseBearing: CLLocationDirection?
    private var compassHeading: CLLocationDirection?
    /// Fix timestamps at which the current run of "against the route" /
    /// "with the route" course samples began (nil = no run in progress).
    private var reversedRunSince: TimeInterval?
    private var forwardRunSince: TimeInterval?

    private var polyline: [CLLocationCoordinate2D] = []
    private var displayLink: CADisplayLink?
    private var lastFrameTime: TimeInterval = 0

    // MARK: - Lifecycle

    override init() {
        super.init()
    }

    /// Starts the display loop. `initialHeading` seeds the camera direction
    /// (typically the route's opening bearing) before any sensor has reported.
    func start(initialCoordinate: CLLocationCoordinate2D?, initialHeading: CLLocationDirection) {
        displayHeading = Self.normalize(initialHeading)
        if let initialCoordinate {
            displayCoordinate = initialCoordinate
            anchor = initialCoordinate
        }
        guard displayLink == nil else { return }
        let link = CADisplayLink(target: self, selector: #selector(tick(_:)))
        link.preferredFrameRateRange = CAFrameRateRange(minimum: 24, maximum: 30, preferred: 30)
        link.add(to: .main, forMode: .common)
        displayLink = link
        lastFrameTime = 0
    }

    func stop() {
        displayLink?.invalidate()
        displayLink = nil
    }

    /// The polyline fixes are snapped to. Call again after a reroute.
    func setRoute(_ coordinates: [CLLocationCoordinate2D]) {
        polyline = coordinates
        isReversed = false
        reversedRunSince = nil
        forwardRunSince = nil
    }

    // MARK: - Input

    func ingest(_ location: CLLocation, now: TimeInterval = CACurrentMediaTime()) {
        guard location.horizontalAccuracy >= 0,
              location.horizontalAccuracy <= displayAccuracyLimitMeters,
              -location.timestamp.timeIntervalSinceNow <= maxFixAgeSeconds
        else { return }
        if let previous = latestFix, location.timestamp <= previous.timestamp { return }

        // Speed: trust the chip when it reports, otherwise derive from the
        // last two fixes. Exponentially smoothed so one odd fix can't make
        // the puck lurch.
        var speed = location.speed
        if speed < 0, let previous = latestFix {
            let dt = location.timestamp.timeIntervalSince(previous.timestamp)
            if dt > 0 { speed = location.distance(from: previous) / dt }
        }
        if speed >= 0 {
            smoothedSpeed = smoothedSpeed == 0 ? speed : smoothedSpeed * 0.6 + speed * 0.4
        }

        // Course from the chip when moving; otherwise from the displacement
        // since the previous fix if it was a real move (not noise).
        if location.course >= 0, speed >= movingSpeedThreshold {
            courseBearing = location.course
        } else if let previous = latestFix, location.distance(from: previous) > 3 {
            courseBearing = previous.coordinate.bearing(to: location.coordinate)
        }

        latestFix = location
        latestFixTime = now

        // Snap to the route when close enough.
        let threshold = max(snapThresholdMeters, location.horizontalAccuracy)
        if let projection = Self.project(location.coordinate, onto: polyline),
           projection.distanceMeters <= threshold {
            anchor = projection.coordinate
            anchorRouteBearing = projection.segmentBearing
            isSnappedToRoute = true
        } else {
            anchor = location.coordinate
            anchorRouteBearing = nil
            isSnappedToRoute = false
        }

        updateReversal(location: location, speed: speed)

        if displayCoordinate == nil { displayCoordinate = anchor }
    }

    /// Hysteresis on the angle between GPS course and route bearing. Only
    /// snapped, moving fixes with a valid course count; anything else breaks
    /// the "continuously" requirement and restarts the timers.
    private func updateReversal(location: CLLocation, speed: Double) {
        guard isSnappedToRoute, let routeBearing = anchorRouteBearing,
              location.course >= 0, speed >= movingSpeedThreshold
        else {
            reversedRunSince = nil
            forwardRunSince = nil
            return
        }
        let difference = abs(Self.angleDelta(location.course, routeBearing))
        let timestamp = location.timestamp.timeIntervalSinceReferenceDate
        if difference > reversalEnterDegrees {
            forwardRunSince = nil
            let since = reversedRunSince ?? timestamp
            reversedRunSince = since
            if !isReversed, timestamp - since >= reversalEnterSeconds { isReversed = true }
        } else if difference < reversalExitDegrees {
            reversedRunSince = nil
            let since = forwardRunSince ?? timestamp
            forwardRunSince = since
            if isReversed, timestamp - since >= reversalExitSeconds { isReversed = false }
        } else {
            reversedRunSince = nil
            forwardRunSince = nil
        }
    }

    /// Route bearing in the user's actual direction of travel.
    private var travelRouteBearing: CLLocationDirection? {
        anchorRouteBearing.map { isReversed ? Self.normalize($0 + 180) : $0 }
    }

    func ingestHeading(_ heading: CLLocationDirection) {
        compassHeading = Self.normalize(heading)
    }

    // MARK: - Display loop

    @objc private func tick(_ link: CADisplayLink) {
        let now = link.timestamp
        defer { lastFrameTime = now }
        guard lastFrameTime > 0 else { return }
        step(now: now, dt: min(now - lastFrameTime, 0.1))
    }

    /// One display frame. Exposed so tests can drive the loop without a
    /// `CADisplayLink`; `now` is on the `CACurrentMediaTime()` clock.
    func step(now: TimeInterval, dt: TimeInterval) {
        updatePosition(now: now, dt: dt)
        updateHeading(dt: dt)
        frame &+= 1
    }

    private func updatePosition(now: TimeInterval, dt: TimeInterval) {
        guard let anchor, var current = displayCoordinate else { return }

        // Predict where the user is *now*, a little past the last fix.
        var target = anchor
        let sinceFix = min(max(now - latestFixTime, 0), maxExtrapolationSeconds)
        let moving = smoothedSpeed >= movingSpeedThreshold
        if moving, sinceFix > 0 {
            // Along the route (backwards when reversed) when snapped, else
            // along the GPS course.
            if let bearing = travelRouteBearing ?? courseBearing {
                target = anchor.coordinate(at: smoothedSpeed * sinceFix, bearing: bearing)
                if isSnappedToRoute,
                   let reprojected = Self.project(target, onto: polyline),
                   reprojected.distanceMeters <= snapThresholdMeters {
                    target = reprojected.coordinate
                }
            }
        }

        let gap = current.distance(to: target)
        if gap > teleportDistanceMeters {
            current = target
        } else if gap > 0.05 {
            // Exponential approach: frame-rate independent.
            let alpha = 1 - exp(-dt / positionTimeConstant)
            current = CLLocationCoordinate2D(
                latitude: current.latitude + (target.latitude - current.latitude) * alpha,
                longitude: current.longitude + (target.longitude - current.longitude) * alpha
            )
        } else {
            return
        }
        displayCoordinate = current
    }

    private func updateHeading(dt: TimeInterval) {
        // While walking along the route the route's own direction is the
        // steadiest reference; standing still (or off route) the compass
        // lets the map turn with the user.
        let moving = smoothedSpeed >= movingSpeedThreshold
        let target: CLLocationDirection?
        if moving, let route = travelRouteBearing {
            target = route
        } else if moving, let course = courseBearing {
            target = course
        } else {
            target = compassHeading ?? courseBearing
        }
        guard let target else { return }

        let delta = Self.angleDelta(displayHeading, target)
        guard abs(delta) > 0.05 else { return }
        let alpha = 1 - exp(-dt / headingTimeConstant)
        displayHeading = Self.normalize(displayHeading + delta * alpha)
    }

    // MARK: - Geometry

    struct RouteProjection {
        let coordinate: CLLocationCoordinate2D
        let distanceMeters: Double
        let segmentBearing: CLLocationDirection
        /// Arc length from the polyline's first vertex to `coordinate`.
        let distanceAlongRouteMeters: Double
    }

    /// Nearest point on `polyline` to `point`, computed in a local
    /// equirectangular frame (accurate to centimetres at walking scales).
    static func project(_ point: CLLocationCoordinate2D,
                        onto polyline: [CLLocationCoordinate2D]) -> RouteProjection? {
        guard polyline.count >= 2 else { return nil }
        let metersPerDegLat = 111_320.0
        let metersPerDegLon = 111_320.0 * cos(point.latitude * .pi / 180)
        func toXY(_ c: CLLocationCoordinate2D) -> (x: Double, y: Double) {
            ((c.longitude - point.longitude) * metersPerDegLon,
             (c.latitude - point.latitude) * metersPerDegLat)
        }

        var best: RouteProjection?
        var walked = 0.0
        for i in 0..<(polyline.count - 1) {
            let a = toXY(polyline[i]), b = toXY(polyline[i + 1])
            let dx = b.x - a.x, dy = b.y - a.y
            let len2 = dx * dx + dy * dy
            let len = len2.squareRoot()
            var t = 0.0
            if len2 > 0 { t = min(max((-a.x * dx + -a.y * dy) / len2, 0), 1) }
            let px = a.x + dx * t, py = a.y + dy * t
            let dist = (px * px + py * py).squareRoot()
            if best == nil || dist < best!.distanceMeters {
                let coord = CLLocationCoordinate2D(
                    latitude: point.latitude + py / metersPerDegLat,
                    longitude: point.longitude + px / metersPerDegLon
                )
                let bearing = normalize(atan2(dx, dy) * 180 / .pi)
                best = RouteProjection(coordinate: coord, distanceMeters: dist,
                                       segmentBearing: bearing,
                                       distanceAlongRouteMeters: walked + len * t)
            }
            walked += len
        }
        return best
    }

    static func normalize(_ degrees: Double) -> Double {
        let d = degrees.truncatingRemainder(dividingBy: 360)
        return d < 0 ? d + 360 : d
    }

    /// Smallest signed angle from `a` to `b`, in degrees (-180…180).
    static func angleDelta(_ a: Double, _ b: Double) -> Double {
        var d = (b - a).truncatingRemainder(dividingBy: 360)
        if d > 180 { d -= 360 }
        if d < -180 { d += 360 }
        return d
    }
}
