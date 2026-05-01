import MapKit
import SwiftUI

/// Compact, non-interactive map preview showing a route polyline.
/// Used by route cards (mini and full-size) for thumbnail map images.
struct RouteMapPreview: View {
    let route: Route
    let color: Color

    var body: some View {
        Map {
            MapPolyline(coordinates: route.pathCoordinates)
                .stroke(color, lineWidth: 3)

            if let start = route.pathCoordinates.first {
                Annotation("", coordinate: start) {
                    Circle()
                        .fill(LoooprTheme.Colors.primary)
                        .frame(width: 8, height: 8)
                        .overlay(Circle().stroke(.white, lineWidth: 1.5))
                }
            }

            if let end = route.pathCoordinates.last,
               route.pathCoordinates.count > 1 {
                Annotation("", coordinate: end) {
                    Circle()
                        .fill(LoooprTheme.Colors.routeDot)
                        .frame(width: 8, height: 8)
                        .overlay(Circle().stroke(.white, lineWidth: 1.5))
                }
            }
        }
        .mapStyle(.standard(elevation: .flat, pointsOfInterest: .excludingAll))
        .disabled(true)
        .allowsHitTesting(false)
        .overlay(
            // Transparent overlay that sits above the UIKit MKMapView layer.
            // Even with allowsHitTesting(false) and disabled(true), MKMapView's
            // internal gesture recognizers can still participate in gesture
            // disambiguation and steal taps from parent Buttons/ScrollViews.
            // This Rectangle creates a SwiftUI hit-test surface that intercepts
            // all touches before they reach the UIKit layer, then lets them
            // propagate up to the parent Button naturally.
            Rectangle().fill(Color.white.opacity(0.001))
        )
    }
}
