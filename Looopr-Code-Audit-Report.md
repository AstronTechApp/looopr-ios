# Looopr Codebase Audit Report

**Date:** April 2, 2026
**Scope:** All 18 changes made during this session
**Auditor:** Claude (automated code review)

---

## Executive Summary

Audited 30+ files across 18 feature changes. Found **8 Critical**, **7 High**, **8 Medium**, and **12 Low** severity issues. The Apple MapKit migration and POI model changes are clean. The highest-risk areas are `RouteGeometry.swift` (geometry algorithms), `WalkNavigationViewModel.swift` (concurrency), and `GooglePlacesNewFoodService.swift` (silent error handling).

---

## CRITICAL (8 issues)

### C1. Force Unwrap in `GooglePlacesNewFoodService.foodSearchPoints()` — Line 375
```swift
let lastPoint = points.last!
```
**Risk:** App crash if array is empty between guard check and unwrap.
**Fix:** Use `if let lastPoint = points.last { ... }` instead.

### C2. Silent JSON Serialization Failure in `GooglePlacesAPI.swift` — Line 89
```swift
let jsonData = try? JSONSerialization.data(withJSONObject: body)
```
**Risk:** If body can't be encoded, request is sent with nil body — produces cryptic API errors with no diagnostic trail.
**Fix:** Use `try` and propagate the error.

### C3. Race Condition in `WalkNavigationViewModel.handleLocationUpdate()` — Line 241
```swift
if recentLocations.count > 5 { recentLocations.removeFirst() }
```
**Risk:** `recentLocations` is accessed from a Combine sink (RunLoop.main) while `checkMidWalkDirection()` reads it concurrently. Can cause index-out-of-bounds.
**Fix:** Ensure all access is serialized on `@MainActor` or use a lock.

### C4. Potential NaN Propagation in `RouteGeometry.segmentDistance()` — Lines 222-231
The Heron's formula calculation can produce NaN when points are collinear or nearly coincident. `sqrt(max(0, areaSquared))` mitigates negatives but not edge cases where dot product comparisons fail.
**Fix:** Add explicit collinearity check before area computation.

### C5. Retain Cycle in `WalkNavigationViewModel` — Lines 103-107
```swift
self.wrongWayDetector.onWrongWayDetected = { [weak self] in
    Task { @MainActor in self?.onWrongWayDetected() }
}
```
**Risk:** `wrongWayDetector` holds the closure strongly. If the Task outlives the ViewModel, cleanup is incomplete.
**Fix:** Set `wrongWayDetector.onWrongWayDetected = nil` in `stop()` or `deinit`.

### C6. Loop Route Re-routing Missing Bounds Check — Line 427
```swift
let reentryIdx = closestIdx + 1 + candidate.polylineIndex
pathAfterRejoin = Array(activePolyline[reentryIdx...])
```
**Risk:** If `reentryIdx >= activePolyline.count`, this crashes with an out-of-range index.
**Fix:** Add `guard reentryIdx < activePolyline.count else { ... }` before slicing.

### C7. Back-and-Forth Detection Only Checks Spatial Proximity — `RouteGeometry.selfOverlapRatio()` Line 94
The algorithm splits the polyline at the midpoint and checks spatial overlap. This catches A→B→A patterns spatially but doesn't verify traversal direction. A legitimate loop that happens to cross itself would be incorrectly flagged.
**Fix:** Add bearing comparison between overlapping segments to distinguish loops from retracing.

### C8. Missing `todayHoursString` Import in `POICardView.swift` — Line 124
Calls `todayHoursString(from:)` defined in `POIHelpers.swift` but the function may not be visible depending on access control.
**Status:** Needs verification — if `todayHoursString` is `internal` (default) and both files are in the same module, this compiles. If in different modules, it fails.

---

## HIGH (7 issues)

### H1. Race Condition in Google Places Cache — Lines 166-168
After a cache miss, parallel API calls proceed without a "fetch-in-progress" latch. Duplicate concurrent calls for the same polyline waste API quota and could produce cache inconsistency.
**Fix:** Implement a task-coalescing pattern (e.g., `AsyncSemaphore` or in-flight request map).

### H2. Silent API Failure Degradation — `GooglePlacesNewFoodService` Lines 209-212
When API calls fail, errors are logged but empty arrays are returned silently. If 80% of search points fail (quota, network), the user sees zero results with no indication of failure.
**Fix:** Return a result type or error count so the UI can show "search partially failed."

### H3. Unchecked `primaryType` Fallback — Lines 256-261
Unknown `primaryType` values silently default to `.restaurant`. A misclassified venue that leaks through the filter gets mislabeled.
**Fix:** Log unexpected values and consider rejecting unknown types.

### H4. Inefficient Walking Distance Calculation — `RouteGeometry.distanceAlongRoute()`
Walks the entire polyline segment-by-segment for every call — O(n) per invocation. Called on every location update during navigation with potentially 5,000+ point polylines.
**Fix:** Cache cumulative distances or use a spatial index for nearest-segment lookup.

### H5. Backtrack Ratio Calculation Error — `RouteGeometry.backtrackSegmentRatio()` Line 120
`totalWindows` counts stride positions rather than actual windows checked, causing the backtrack ratio to be systematically underestimated.
**Fix:** Count actual iterations in the loop and divide by that.

### H6. CTA Button Style Not Unified — `RouteSelectionView.swift` Lines 247-268
The "Start Walk" button hand-codes a `LinearGradient` instead of using `LoooprPrimaryButtonStyle` from `LoooprTheme.swift`. If theme colors change, this button won't update.
**Fix:** Replace with `.buttonStyle(.loooprPrimary)`.

### H7. Fragile Map Gesture Suppression — `RouteMapPreview.swift`
Uses an invisible `Rectangle().fill(Color.white.opacity(0.001))` overlay to block UIKit gesture recognizers on map previews. Works but is fragile — future developers may remove the seemingly empty rectangle.
**Fix:** Add a prominent `// MARK:` comment, or use `UIViewRepresentable` with explicit gesture disabling.

---

## MEDIUM (8 issues)

### M1. Missing `import UIKit` in `RouteDetailView.swift`
Uses `UIApplication.shared.connectedScenes`, `UIWindowScene`, and `UIImpactFeedbackGenerator` — all require UIKit. SwiftUI's implicit import may cover this on iOS, but it's not guaranteed and is bad practice.

### M2. Hard-coded Sheet Heights — `RouteDetailView.swift` Lines 301-302
```swift
private var expandedHeight: CGFloat { UIScreen.main.bounds.height * 0.65 }
```
Doesn't account for Dynamic Island, varying notch sizes, or iPad.

### M3. Three-Layer Filter Gap for nil `primaryType`
If a Google Places result has `primaryType == nil`, layer 2 of the misclassification filter is skipped entirely. The place relies solely on layer 3 (name heuristics).

### M4. Missing Bounds Check in `MapboxRouteGenerationService.generatePentagonLoop()` — Line 244
`step.maneuver.location[1]` and `[0]` — no validation that the location array has exactly 2 elements.

### M5. Retain Cycle Risk in `RouteGenerationService.generateLoopRoutesStream()` — Line 91
`continuation.onTermination` closure captures `task` which may indirectly hold `self`.

### M6. Walking Time Format Inconsistency
Route cards use `"1h 30min"` format but POI walking info uses `"~30 min walk"` with a tilde and space. These should match.

### M7. Food Proximity Warning Task Lifecycle — `RouteDetailViewModel`
```swift
Task { try? await Task.sleep(for: .seconds(3)); showFoodProximityWarning = false }
```
If user navigates away, the Task outlives the ViewModel.
**Fix:** Use `[weak self]` or cancel on deinit.

### M8. `ShareSheetView` Type Safety — `RouteDetailView.swift`
`[String, URL] as [Any]` bypasses type safety. Use a strongly typed wrapper.

---

## LOW (12 issues)

| # | File | Issue |
|---|------|-------|
| L1 | RouteDetailView | Unused `@GestureState private var dragOffset` — dead code |
| L2 | RouteDetailView | Magic numbers for padding (1.4, 2.0) in `fitMapToRoute()` |
| L3 | RouteDetailView | Multiple `ForEach` loops re-filtering annotations on every render |
| L4 | RouteCardMini | Hardcoded hex colors (`#005c15`, `#7b3100`) not in theme |
| L5 | RouteGeometry | Hardcoded sampling intervals (`.sampled(every: 3)`, `every: 2`) |
| L6 | RouteGeometry | `default: return "North"` for invalid bearings — should log |
| L7 | MapboxRouteGeneration | Asymmetric polyline sampling in overlap detection |
| L8 | AppConfiguration | `freemiumLegCount` and `paidLegCount` defined but never referenced |
| L9 | GooglePlacesNewFood | Inconsistent distance API usage (CLLocation vs coordinate extension) |
| L10 | GooglePlacesNewFood | Logging untrusted place names directly |
| L11 | WalkDetailViewModel | Creates fallback `RouteShareService()` outside DI container |
| L12 | RouteSelectionView | `estimatedElevation` returns Int → converted to Double unnecessarily |

---

## CLEAN AREAS (no issues found)

| Area | Status |
|------|--------|
| **Apple MapKit migration** | Overpass fully disabled in ServiceContainer. No interference possible. |
| **POI model backward compatibility** | New `distanceFromRoute`/`distanceAlongRoute` fields are optional with `decodeIfPresent()` defaults. Old cached data loads safely. |
| **POI deduplication** | `POIAggregatorService` deduplicates by `place_id` with name-based fallback. No duplicate sources. |
| **Actor-based concurrency** | `POIAggregatorService`, `CacheManager`, `GooglePlacesNewFoodService` all use actors correctly. |
| **API key security** | Passed as parameter, sent via header, never logged. |
| **URL encoding (Overpass)** | Restrictive `CharacterSet` correctly percent-encodes semicolons and special chars. |
| **Supabase shared_routes** | Upsert pattern with RLS policy is correct. Service conditionally registered. |
| **Sendable conformance** | POI, Route, Location all conform to `Sendable`. |
| **OverpassAPI dead code** | Still present but fully disconnected — no runtime risk. |

---

## Priority Fix Order

1. **C6** — Bounds check on re-routing index (crash on loop routes)
2. **C1** — Force unwrap in food search points (crash)
3. **C3** — Race condition in location updates (intermittent crash)
4. **C2** — Silent JSON failure (invisible API bugs)
5. **H1** — Cache race condition (wasted API quota)
6. **H2** — Silent API degradation (bad UX)
7. **C5** — Retain cycle cleanup (memory leak)
8. **H4** — Walking distance performance (lag during navigation)
9. **C7** — Back-and-forth detection accuracy (false positives)
10. **H6** — CTA button unification (maintenance debt)

---

## Cross-File Conflict Check

| File | Modified By | Conflicts? |
|------|------------|------------|
| `RouteDetailView.swift` | CTA buttons, map framing, dark mode, bottom sheet | **No conflicts** — changes target different sections |
| `GooglePlacesNewFoodService.swift` | Initial creation, cafes fix, misclassification filter | **No conflicts** — additive changes |
| `RouteGeometry.swift` | Walking distance, back-and-forth fix | **No conflicts** — separate methods added |
| `OverpassAPI.swift` | Art galleries, encoding fix, retry logic | **No conflicts** — Overpass disabled anyway |
| `POIAggregatorService.swift` | Hybrid POI, coverage fix, walking distance | **No conflicts** — changes are complementary |
