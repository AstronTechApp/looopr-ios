# Looopr — Apple App Store Submission Checklist

*Last updated: April 2, 2026*

This checklist covers everything needed to get Looopr approved on the Apple App Store. Items are organized by priority: **MUST-HAVE** items will block approval; **RECOMMENDED** items reduce rejection risk and improve quality; **NICE-TO-HAVE** items polish the experience.

---

## 1. Apple Developer Program — MUST-HAVE

- [ ] Enroll in the Apple Developer Program ($99/year) at [developer.apple.com/programs](https://developer.apple.com/programs)
- [ ] Verify your Apple ID has two-factor authentication enabled
- [ ] If publishing under a company name: complete D-U-N-S Number registration (can take 5–14 business days)
- [ ] Create an iOS Distribution Certificate in Certificates, Identifiers & Profiles
- [ ] Create an App ID (Bundle Identifier) for Looopr — e.g., `com.looopr.app`
- [ ] Register the `looopr://` URL scheme in your App ID configuration (Associated Domains if using universal links)
- [ ] Create a Distribution Provisioning Profile linked to your App ID and certificate
- [ ] Ensure all team members who need access are added to your developer account with appropriate roles

---

## 2. App Store Connect Setup — MUST-HAVE

### App Listing

- [ ] Create a new app record in App Store Connect
- [ ] Set the Bundle ID to match your Xcode project
- [ ] Choose primary language and localization(s)
- [ ] Select primary category: **Navigation** (or **Travel**)
- [ ] Select secondary category: **Health & Fitness** or **Lifestyle** (if applicable)
- [ ] Write the app name (max 30 characters): e.g., "Looopr — Walking Routes"
- [ ] Write the subtitle (max 30 characters): e.g., "Discover Walks & Hidden Gems"

### App Description & Metadata

- [ ] Write the full description (up to 4,000 characters) — lead with your strongest value proposition
- [ ] Write the promotional text (up to 170 characters) — this can be updated without a new build
- [ ] Add relevant keywords (max 100 characters, comma-separated) — target: walking, routes, tourist, explore, POI, city walks, maps
- [ ] Set the "What's New in This Version" text
- [ ] Provide a support URL (must be a working link)
- [ ] Provide a marketing URL (optional but recommended)

### Age Rating

- [ ] Complete the age rating questionnaire in App Store Connect
- [ ] Expected rating: 4+ (no mature content, violence, or gambling)
- [ ] If users can share routes publicly, consider whether "User Generated Content" applies (may require 12+ rating and content moderation)

### Screenshots — MUST-HAVE

Provide screenshots for at minimum:

- [ ] **iPhone 6.9"** (1320 × 2868 px) — iPhone 16 Pro Max — required as the primary set
- [ ] **iPhone 6.7"** (1290 × 2796 px) — iPhone 15 Plus/Pro Max (auto-downscales from 6.9" if not provided)
- [ ] **iPhone 6.5"** (1284 × 2778 px) — older Pro Max models (auto-downscales if not provided)
- [ ] Minimum 3 screenshots, maximum 10 per localization
- [ ] Screenshots should showcase: route discovery, map view with POIs, active walking/tracking, cafe/restaurant recommendations, shared routes

### App Preview Videos — RECOMMENDED

- [ ] Create a 15–30 second app preview video showing the core walk experience
- [ ] Ensure video meets Apple's format requirements (H.264, 30fps)

### App Icon for App Store

- [ ] Provide a 1024 × 1024 px app icon (PNG, no transparency, no rounded corners — Apple applies the mask automatically)

---

## 3. Privacy & Legal — MUST-HAVE

### Privacy Policy — MUST-HAVE (Blocks Submission)

- [ ] Create a privacy policy covering all data collection and usage
- [ ] Host the privacy policy at a publicly accessible URL
- [ ] Enter the privacy policy URL in App Store Connect
- [ ] Privacy policy must cover:
  - [ ] Location data collection (GPS coordinates during walks)
  - [ ] Account data (name, email from Google OAuth / Apple Sign-In)
  - [ ] Route data (created, saved, and shared routes)
  - [ ] Data shared with third parties: Google Places API, Mapbox, Supabase
  - [ ] Data retention and deletion policies
  - [ ] User rights (access, correction, deletion)
  - [ ] Contact information for privacy inquiries
  - [ ] GDPR compliance section (if serving EU users)

### Terms of Service — RECOMMENDED

- [ ] Create Terms of Service / Terms of Use
- [ ] Host at a publicly accessible URL
- [ ] Enter the URL in App Store Connect
- [ ] Cover: acceptable use, user-generated content rights, route sharing liability, intellectual property

### App Privacy Details (Nutrition Labels) — MUST-HAVE (Blocks Submission)

You must declare ALL data collection in App Store Connect, including data collected by third-party SDKs (Google Places, Mapbox, Supabase).

**Data types to declare:**

- [ ] **Location — Precise Location**: Used for core app functionality (walking routes, nearby POIs). Linked to user.
- [ ] **Location — Coarse Location**: If Mapbox or Google collects approximate location.
- [ ] **Contact Info — Email Address**: Collected via Google OAuth / Apple Sign-In for account creation. Linked to user.
- [ ] **Contact Info — Name**: Collected via authentication. Linked to user.
- [ ] **Identifiers — User ID**: Supabase user ID. Linked to user.
- [ ] **Usage Data — Product Interaction**: If you track which routes users view/complete.
- [ ] **Diagnostics — Crash Data**: If using any crash reporting SDK.
- [ ] **Diagnostics — Performance Data**: Mapbox telemetry collects performance data.

**For each data type, declare:**

- [ ] Whether it's used for tracking (following users across apps/websites owned by other companies)
- [ ] Whether it's linked to the user's identity
- [ ] The purpose: App Functionality, Analytics, Product Personalization, Third-Party Advertising, etc.

**Third-party SDK data collection to account for:**

- [ ] Google Places SDK: review Google's [data disclosure documentation](https://developers.google.com/maps/documentation/places/ios-sdk/policies)
- [ ] Mapbox SDK: collects telemetry (location, device info) — review [Mapbox privacy docs](https://docs.mapbox.com/help/glossary/attribution/)
- [ ] Supabase: data you store (routes, profiles, auth tokens)

### Usage Description Strings (Info.plist) — MUST-HAVE (Blocks Submission)

These strings are shown to users when requesting permissions. They must clearly explain WHY you need access. Vague descriptions cause rejections.

- [ ] `NSLocationWhenInUseUsageDescription` — e.g., *"Looopr uses your location to show nearby walking routes, points of interest, and to track your walk progress in real time."*
- [ ] `NSLocationAlwaysAndWhenInUseUsageDescription` — Only if tracking walks in background. e.g., *"Looopr uses your location in the background to continue tracking your walk even when the app is minimized, ensuring your route is recorded accurately."* **Note:** If you don't need background location, don't request it — it draws extra scrutiny from reviewers.
- [ ] `NSMotionUsageDescription` — e.g., *"Looopr counts your steps during walks to show your activity."*

### App Tracking Transparency (ATT) — CONDITIONAL

- [ ] Determine if any SDK tracks users across apps (as defined by Apple's tracking policy)
- [ ] If Google Places, Mapbox telemetry, or any analytics SDK tracks users: implement the ATT prompt (`ATTrackingManager.requestTrackingAuthorization`)
- [ ] Add `NSUserTrackingUsageDescription` to Info.plist if ATT is required
- [ ] If NO tracking occurs: you likely don't need ATT, but verify with each SDK's documentation

### Account Deletion — MUST-HAVE

- [ ] Implement in-app account deletion (Apple requires this if your app supports account creation)
- [ ] Account deletion must actually delete data from Supabase (not just deactivate)
- [ ] Clearly explain to users what data will be deleted
- [ ] Confirm deletion with the user before proceeding

---

## 4. Technical Requirements — MUST-HAVE

### App Icons

- [ ] Provide a single 1024 × 1024 px icon in your asset catalog — Xcode auto-generates all required sizes
- [ ] Icon must not contain transparency or alpha channel
- [ ] Icon must not be a duplicate of another app's icon
- [ ] Verify icon renders well at small sizes (Settings, Spotlight, Notifications)

### Launch Screen

- [ ] Implement a launch screen using a Storyboard (not a static image) — required
- [ ] Launch screen should match the initial state of the app (not a splash/ad screen)
- [ ] Test that launch screen displays correctly on all supported device sizes

### SDK & Build Requirements

- [ ] Build with Xcode 16+ and the iOS 18 SDK (or later — check Apple's [upcoming requirements](https://developer.apple.com/news/upcoming-requirements/) as iOS 26 SDK may be required after April 28, 2026)
- [ ] Set a minimum deployment target — recommended: iOS 17.0+ (covers ~95% of devices)
- [ ] Justify your minimum iOS version: SwiftUI features used, MapKit APIs, etc.
- [ ] Archive and export using your Distribution certificate and provisioning profile

### Device Support

- [ ] Decide: Universal (iPhone + iPad) vs. iPhone only
- [ ] If iPhone only: ensure your `Info.plist` declares `UIRequiredDeviceCapabilities` correctly
- [ ] Required device capabilities to declare:
  - [ ] `location-services` — GPS is core to the app
  - [ ] `gps` — if you require GPS specifically (not just Wi-Fi location)
  - [ ] `arm64` — all modern iPhones
- [ ] Support all current iPhone screen sizes (SE through Pro Max)
- [ ] Test on at minimum: iPhone SE (3rd gen), iPhone 15, iPhone 16 Pro Max

### UI/UX Requirements

- [ ] **Dark Mode support**: App must render correctly in both light and dark mode — use semantic/system colors
- [ ] **Dynamic Type support**: Text should scale with the user's accessibility text size preference
- [ ] **Safe area compliance**: No content cut off by the Dynamic Island, notch, or home indicator
- [ ] **Orientation**: If portrait-only, declare `UISupportedInterfaceOrientations` correctly
- [ ] **No private APIs**: Ensure no use of undocumented Apple APIs (instant rejection)

### Deep Links

- [ ] Register `looopr://` custom URL scheme in Info.plist under `CFBundleURLTypes`
- [ ] Handle incoming deep links gracefully (including malformed URLs)
- [ ] If using Universal Links (`looopr.app/route/123`): configure Associated Domains entitlement and host `apple-app-site-association` file on your server

---

## 5. Authentication — MUST-HAVE

### Sign in with Apple — MUST-HAVE (Guideline 4.8)

- [ ] **If you offer Google Sign-In, you MUST also offer Sign in with Apple** — this is a hard requirement
- [ ] Implement Sign in with Apple using `AuthenticationServices` framework
- [ ] Handle all Sign in with Apple scenarios:
  - [ ] First-time sign-in (user shares or hides email)
  - [ ] Returning sign-in
  - [ ] Credential revocation (user removes your app from their Apple ID settings)
- [ ] Sign in with Apple button must follow [Apple's HIG for the button style](https://developer.apple.com/design/human-interface-guidelines/sign-in-with-apple)
- [ ] Sign in with Apple must be presented as an **equivalent** option to Google Sign-In (not hidden or de-emphasized)
- [ ] Add the "Sign in with Apple" capability in your Xcode project
- [ ] Enable Sign in with Apple in your App ID configuration

### Google OAuth

- [ ] Implement Google Sign-In following Google's iOS SDK guidelines
- [ ] Handle sign-in failures gracefully with clear error messages

### Guest/Test Access for Review

- [ ] Provide a demo account in App Store Connect's "App Review Information" section (username + password)
- [ ] Alternatively: ensure the reviewer can create a new account and access all features
- [ ] If location-dependent features exist: provide reviewer notes explaining how to test (e.g., "The app works in any location — POIs will load for the reviewer's current city")

---

## 6. API Key Management & Security — MUST-HAVE

- [ ] **Google Places API key**: Do NOT embed directly in the binary. Use:
  - [ ] Restrict the key in Google Cloud Console to your iOS bundle ID
  - [ ] Store in a `.xcconfig` file excluded from version control
  - [ ] Or fetch from Supabase edge function at runtime
- [ ] **Mapbox access token**: Restrict to your bundle ID in the Mapbox dashboard
  - [ ] Use a public/scoped token (not your secret token) in the app
- [ ] **Supabase anon key**: This is designed to be public, but ensure Row Level Security (RLS) policies are properly configured
- [ ] **Supabase service role key**: NEVER include in the app binary — use only server-side
- [ ] Run a scan of your built `.ipa` for exposed secrets before submission (e.g., `strings YourApp | grep -i "key\|secret\|token"`)
- [ ] Ensure `.gitignore` excludes all config files containing API keys
- [ ] Enable App Transport Security (ATS) — all network requests must use HTTPS

---

## 7. Third-Party Attribution Requirements — MUST-HAVE

### Google Places API

- [ ] Display the "Powered by Google" logo when showing Places results
- [ ] Display third-party attributions returned by the Places API for each place
- [ ] Include a link to Google's Terms of Service in your app or settings
- [ ] Do not cache Places data beyond Google's permitted duration
- [ ] Ensure reviews display author name, profile photo, and profile link when available (data returned by the Places API)
- [ ] Do not mix Google Places results with other providers' results without clear distinction

### Mapbox

- [ ] Display the Mapbox wordmark/logo on any map view powered by Mapbox
- [ ] Display text attribution: "© Mapbox", "© OpenStreetMap", and "Improve this map" link
- [ ] Do NOT remove or hide the attribution control — it also provides the required telemetry opt-out
- [ ] If you customize the attribution control position: ensure it remains visible and legible
- [ ] Provide a way for users to opt out of Mapbox Telemetry (built into the default attribution control)

### Apple MapKit

- [ ] Apple MapKit attribution is handled automatically by the `MKMapView` — do not remove it
- [ ] Include the Apple Maps legal notice link (provided automatically by MapKit)
- [ ] Comply with Apple's MapKit usage guidelines — no caching map tiles

---

## 8. Location Handling — MUST-HAVE

- [ ] Request location permission at the right moment (not on first launch — wait until the user wants to see a map or start a walk)
- [ ] Handle all permission states gracefully:
  - [ ] **Not Determined**: Show explanation screen before triggering the system prompt
  - [ ] **Authorized (When In Use)**: Full functionality
  - [ ] **Authorized (Always)**: Full functionality including background tracking
  - [ ] **Denied**: Show a friendly message explaining why location is needed, with a button to open Settings
  - [ ] **Restricted**: Handle edge case (parental controls, MDM)
- [ ] If the user denies location: the app must not crash or show a blank screen — provide degraded functionality (e.g., browse pre-made routes, search by city name)
- [ ] If using background location (`Always`): you must declare `location` in `UIBackgroundModes` and justify it in the review notes
- [ ] Display the blue location indicator in the status bar during active background tracking
- [ ] Minimize battery drain: use appropriate `desiredAccuracy` and `distanceFilter` settings
- [ ] Handle location errors (no GPS signal, airplane mode) with user-friendly messaging

---

## 9. Common Rejection Reasons to Avoid — CHECKLIST

### Guideline 1.0 — Safety

- [ ] If users can share routes publicly: implement content moderation or reporting mechanism
- [ ] Include a way for users to report inappropriate content

### Guideline 2.1 — Performance: App Completeness

- [ ] No placeholder content (Lorem ipsum, "Coming Soon" sections, empty screens)
- [ ] All features listed in the description must be functional
- [ ] No test data or debug menus in the release build
- [ ] All links in the app work (no 404s, no dead ends)
- [ ] No TestFlight or beta references in the app or metadata

### Guideline 2.3 — Performance: Accurate Metadata

- [ ] App screenshots must reflect the actual app experience
- [ ] Description must accurately describe what the app does
- [ ] Don't reference other platforms (e.g., "also available on Android")
- [ ] Don't mention price in the description (including "free")

### Guideline 4.0 — Design

- [ ] App must not look like a web wrapper or minimal effort
- [ ] Use standard iOS UI patterns (navigation, tab bars, sheets)
- [ ] No custom alert dialogs that mimic system alerts
- [ ] Support the latest device sizes and screen types

### Guideline 4.8 — Sign in with Apple

- [ ] ✅ Covered above — Sign in with Apple must be offered alongside Google Sign-In

### Guideline 5.1.1 — Data Collection and Storage

- [ ] Only collect data that is necessary for app functionality
- [ ] Clearly explain data collection in-app (not just in the privacy policy)
- [ ] Obtain consent before collecting sensitive data
- [ ] Store data securely (Supabase RLS, encrypted connections)
- [ ] Implement account deletion as described above

### Guideline 5.1.2 — Data Use and Sharing

- [ ] Do not share user data with third parties for purposes users wouldn't expect
- [ ] Disclose all third-party data sharing in the privacy policy
- [ ] If using analytics: disclose in the App Privacy nutrition label
- [ ] Do not use location data for advertising without explicit consent

### Guideline 5.1.3 — Health and Health Research (if applicable)

- [ ] If you track steps, distance, or health metrics: disclose clearly and consider HealthKit integration guidelines

---

## 10. TestFlight Beta Testing — RECOMMENDED (Strongly)

- [ ] Upload a build to App Store Connect via Xcode or `xcodebuild`
- [ ] Add internal testers (up to 100, no review needed)
- [ ] Set up an external testing group:
  - [ ] Write beta test description and feedback instructions
  - [ ] Submit for Beta App Review (usually faster than full review)
  - [ ] Add external testers (up to 10,000)
- [ ] Test core flows on TestFlight:
  - [ ] Sign up with Apple Sign-In
  - [ ] Sign up with Google Sign-In
  - [ ] Browse and search for routes
  - [ ] Start and complete a walk with GPS tracking
  - [ ] View POIs (tourist attractions via MapKit + cafes/restaurants via Google Places)
  - [ ] Save a route and find it again under the Saved Routes tab
  - [ ] Share a route via deep link
  - [ ] Open a `looopr://` deep link
  - [ ] Delete account
  - [ ] Deny location permission and verify graceful degradation
  - [ ] Test on slow/no network connection
  - [ ] Test on oldest supported device (iPhone SE) and newest (iPhone 16 Pro Max)
- [ ] Fix all crashes reported in TestFlight/Xcode Organizer

---

## 11. App Review Submission — FINAL STEPS

- [ ] Select the build in App Store Connect
- [ ] Fill in the **App Review Information** section:
  - [ ] Contact person: name, phone, email
  - [ ] Demo account credentials (or clear instructions for sign-up)
  - [ ] Review notes explaining: location-based features, how to test walks, any special configuration
  - [ ] If applicable: explain why background location is needed
- [ ] Set the release option: Manual release (recommended for first launch) or Automatic
- [ ] Double-check all metadata, screenshots, and URLs
- [ ] Submit for review
- [ ] Monitor App Store Connect for reviewer questions or rejection feedback — respond within 24 hours

---

## 12. Post-Submission Monitoring — NICE-TO-HAVE

- [ ] Set up App Store Connect notifications for review status changes
- [ ] Prepare responses for common reviewer questions about location usage
- [ ] Have a hotfix build ready in case the reviewer finds a bug
- [ ] Set up crash monitoring (e.g., Firebase Crashlytics, Sentry) to catch launch-day issues
- [ ] Monitor App Store reviews and respond to user feedback

---

## Quick Reference: Rejection Risk Summary

| Risk Area | Priority | Status |
|---|---|---|
| Sign in with Apple missing | 🔴 Will reject | ⬜ |
| Privacy policy URL missing | 🔴 Will reject | ⬜ |
| App Privacy nutrition labels incomplete | 🔴 Will reject | ⬜ |
| Location usage descriptions missing/vague | 🔴 Will reject | ⬜ |
| Account deletion not implemented | 🔴 Will reject | ⬜ |
| Placeholder content or broken features | 🔴 Will reject | ⬜ |
| No demo account for reviewer | 🟡 Likely reject | ⬜ |
| Google Places attribution missing | 🟡 Likely reject | ⬜ |
| Mapbox attribution removed/hidden | 🟡 Likely reject | ⬜ |
| Crash on location permission denial | 🟡 Likely reject | ⬜ |
| API keys exposed in binary | 🟡 Security risk | ⬜ |
| No Dark Mode support | 🟠 May flag | ⬜ |
| No Dynamic Type support | 🟠 May flag | ⬜ |
| Background location without justification | 🟠 May flag | ⬜ |

---

*Sources: [Apple App Store Review Guidelines](https://developer.apple.com/app-store/review/guidelines/), [Apple HIG — App Icons](https://developer.apple.com/design/human-interface-guidelines/app-icons/), [Google Places SDK Policies](https://developers.google.com/maps/documentation/places/ios-sdk/policies), [Mapbox Attribution Requirements](https://docs.mapbox.com/help/glossary/attribution/), [App Store Connect Screenshot Specs](https://developer.apple.com/help/app-store-connect/reference/app-information/screenshot-specifications/)*
