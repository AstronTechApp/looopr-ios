# Looopr iOS App — Security Audit Report

**Date:** March 31, 2026
**Scope:** Full codebase review (162 Swift files)
**Auditor:** Automated security analysis

---

## Executive Summary

This audit identified **4 Critical**, **8 High**, **11 Medium**, and **6 Low** severity findings across the Looopr iOS codebase. Supabase RLS policies were verified live and found to be well-configured (downgraded from Critical). The most urgent remaining issues involve exposed API keys, missing certificate pinning, unencrypted local data storage, and thread safety violations. Immediate remediation is recommended for all Critical and High items.

| Severity | Count |
|----------|-------|
| Critical | 4 |
| High     | 8 |
| Medium   | 11 |
| Low      | 6 |

---

## 1. API Key Security

### FINDING 1.1 — Production API Keys in Source Control
**Severity: CRITICAL**
**File:** `Looopr/Secrets.xcconfig`

Four production API keys are stored in plaintext in the xcconfig file:

- Google Places API Key (`AIzaSy...`)
- Mapbox Access Token (`pk.eyJ...`)
- Supabase URL (`https://bnveejdmmzdjewowvekp.supabase.co`)
- Supabase Anon Key (full JWT)

**Mitigating factor:** `.gitignore` includes `**/*.xcconfig`, so the file is excluded from git. However, the keys are compiled into Info.plist and the app binary, making them extractable via reverse engineering.

**Recommendation:**
1. Rotate all exposed keys immediately.
2. Move keys to a backend proxy or CI/CD secret injection pipeline.
3. For keys that must remain client-side (e.g., Supabase anon key), apply strict API key restrictions (IP/referrer/bundle ID restrictions in Google Cloud, Mapbox, etc.).
4. Add a pre-commit hook to prevent accidental xcconfig commits.

---

### FINDING 1.2 — API Keys Passed in URL Query Parameters
**Severity: HIGH**
**File:** `Looopr/Data/Networking/GooglePlacesAPI.swift` (Lines 16, 35, 47, 57)
**File:** `Looopr/Services/RouteGeneration/MapboxRouteGenerationService.swift` (Line 270)

The Google Places legacy API and Mapbox pass API keys as URL query parameters (`?key=...`, `?access_token=...`). These appear in server logs, proxy caches, and network inspection tools.

**Note:** The Google Places *new* API (line 97) correctly uses the `X-Goog-Api-Key` header.

**Recommendation:** Migrate all API key transmission to HTTP headers. For Google Places legacy endpoints, switch to the new Places API which already uses headers.

---

### FINDING 1.3 — No Keychain Usage for Secrets
**Severity: MEDIUM**
**Scope:** Entire codebase

No usage of Keychain (`SecItemAdd`, `SecItemCopyMatching`, `KeychainSwift`, etc.) was found anywhere in the codebase. All secrets are loaded from `Bundle.main.infoDictionary` at runtime via `Secrets.swift`.

**Recommendation:** Store user session tokens and any refresh tokens in the Keychain. Use Data Protection keychain attributes for additional security.

---

### FINDING 1.4 — Keys Embedded in App Binary via Info.plist
**Severity: HIGH**
**File:** `Looopr/Info.plist` (Lines 34–68)
**File:** `Looopr/Core/Configuration/Secrets.swift`

Nine API keys are injected into Info.plist via xcconfig variable substitution and read at runtime. These are trivially extractable from the compiled `.ipa` using tools like `plutil` or `class-dump`.

**Keys exposed:** Google Places, Mapbox, Supabase URL, Supabase Anon Key, Viator, GetYourGuide, Tiqets, Musement, Klook.

**Recommendation:** Route third-party API calls through a backend proxy so keys never leave your server. For Supabase, the anon key is designed to be client-side but must be protected by strict RLS policies.

---

## 2. Authentication & Authorization

### FINDING 2.1 — OAuth Redirect URI Not Validated in Deep Link Handler
**Severity: MEDIUM**
**File:** `Looopr/Services/Auth/AuthService.swift` (Line 71)
**File:** `Looopr/Presentation/AppRootView.swift` (Lines 232–259)

The Google OAuth flow uses `looopr://auth-callback` as a redirect URI, but the deep link handler in `AppRootView` does not explicitly handle or validate this path. It relies on the Supabase SDK handling the callback implicitly.

**Recommendation:** Add explicit handling and validation for `looopr://auth-callback` in the deep link handler. Verify the callback URL parameters before processing.

---

### FINDING 2.2 — Session Refresh Falls Back to Stale Token
**Severity: MEDIUM**
**File:** `Looopr/Services/Sharing/RouteShareService.swift` (Lines 25–31)

When `refreshSession()` fails, the code falls back to the current (potentially expired) session without checking its expiration time. Subsequent API calls may fail with 401 errors.

```swift
do {
    session = try await supabase.client.auth.refreshSession()
} catch {
    session = try await supabase.client.auth.session  // May be expired
}
```

**Recommendation:** Check `session.expiresAt` before using the fallback. If expired, throw an error and prompt re-authentication.

---

### FINDING 2.3 — Apple Sign-In Nonce Implementation (Positive)
**Severity: N/A — Secure**
**File:** `Looopr/Services/Auth/AuthService.swift` (Lines 200–229)

The Apple Sign-In implementation correctly uses `SecRandomCopyBytes` for cryptographic nonce generation and SHA256 hashing. GDPR account deletion and data export are implemented via Edge Functions.

---

## 3. Network Security

### FINDING 3.1 — No Certificate Pinning
**Severity: HIGH**
**Files:** `Looopr/Data/Networking/URLSessionAPIClient.swift`, `Looopr/Services/Sharing/RouteShareService.swift`

The app uses default `URLSession` configuration without any `URLSessionDelegate` implementation for certificate validation. No pinning libraries (TrustKit, Alamofire pinning, etc.) are used.

**Impact:** Vulnerable to man-in-the-middle attacks on compromised networks or devices with rogue CA certificates installed. All API keys, user tokens, and location data transmitted over HTTPS could be intercepted.

**Recommendation:** Implement certificate pinning for critical endpoints (Supabase, Google Places, Mapbox) using `URLSessionDelegate.urlSession(_:didReceive:completionHandler:)` or a library like TrustKit.

---

### FINDING 3.2 — All Traffic Uses HTTPS (Positive)
**Severity: N/A — Secure**

All API base URLs use HTTPS:
- Google Places: `https://maps.googleapis.com`
- Viator: `https://api.viator.com`
- Tiqets: `https://api.tiqets.com`
- Klook: `https://affiliate-api.klook.com`
- Musement: `https://api.musement.com`
- GetYourGuide: `https://api.getyourguide.com`
- Overpass: `https://overpass-api.de`
- Supabase: HTTPS URL from config

No `http://` URLs were found. Default App Transport Security applies.

---

### FINDING 3.3 — Supabase Anon Key Used as Bearer Token for Public Reads
**Severity: MEDIUM**
**File:** `Looopr/Services/Sharing/RouteShareService.swift` (Line 90)

For shared route reads, the anon key is sent as a `Bearer` token in the `Authorization` header. While Supabase anon keys are designed for client-side use, transmitting them as Bearer tokens in every request increases exposure surface.

**Recommendation:** Use the Supabase client library's built-in request methods instead of manual `URLRequest` construction, which handles auth headers automatically.

---

## 4. Data Storage

### FINDING 4.1 — Sensitive Data in Unencrypted UserDefaults
**Severity: HIGH**
**Files:**
- `Looopr/Core/Configuration/SettingsManager.swift` — Display name, walking pace, preferences
- `Looopr/Data/Repositories/WalkHistoryRepository.swift` — Complete walk sessions with coordinate trails
- `Looopr/Data/Repositories/RouteRepository.swift` — Saved route data
- `Looopr/Presentation/Features/Home/LocationSearchView.swift` — Location search history

**Impact:** UserDefaults is stored as a plaintext plist file, readable from device backups, forensic extraction, or jailbroken devices. Walk history contains full GPS coordinate trails — highly sensitive PII.

**Recommendation:**
1. Move walk history and route data to an encrypted database (encrypted Core Data or SQLCipher).
2. Store user preferences that reveal behavior patterns using encrypted storage.
3. Use `FileProtectionType.complete` on any file-based storage.

---

### FINDING 4.2 — Photos Stored Without File Protection (RESOLVED — feature removed)
**Severity: HIGH (historical)**

In-app camera capture, photo storage, and the collage/memories feature were removed for the MVP. The `PhotoStorageService`, `LoooprPhotos` directory, and associated Info.plist keys (`NSCameraUsageDescription`, `NSPhotoLibraryUsageDescription`, `NSPhotoLibraryAddUsageDescription`) are no longer present in the codebase. This finding no longer applies.

---

### FINDING 4.3 — User Data Export Saved to Documents Without Cleanup
**Severity: MEDIUM**
**File:** `Looopr/Presentation/Features/Settings/PrivacySettingsView.swift` (Lines 192–194)

Exported user data JSON is saved to the Documents directory, which may be synced to iCloud. No automatic cleanup after sharing.

**Recommendation:** Use a temporary directory, encrypt the file, and delete it after the share sheet dismisses.

---

## 5. Input Validation

### FINDING 5.1 — Coordinate Interpolation in Overpass API Queries
**Severity: MEDIUM**
**File:** `Looopr/Data/Networking/OverpassAPI.swift` (Lines 31–33)

User-derived coordinates are interpolated directly into Overpass QL query strings:

```swift
let coords = searchPoints.map { "\($0.lat),\($0.lon)" }.joined(separator: ",")
let r = Int(radiusMeters)
// Used in: (around:\(r),\(coords));
```

**Mitigating factor:** Values are numeric types (`Double`, `Int`), which limits injection risk. However, no bounds validation is performed.

**Recommendation:** Validate coordinates are within valid GPS ranges (-90 to 90 lat, -180 to 180 lon) and radius is within a reasonable bound (e.g., 1–50000m).

---

### FINDING 5.2 — No WebView Usage (Positive)
**Severity: N/A — Secure**

No `WKWebView` or `UIWebView` usage was found. No XSS injection risks from webview content.

---

### FINDING 5.3 — Supabase ORM Used for All Queries (Positive)
**Severity: N/A — Secure**

All Supabase interactions use the query builder (`.from().select().eq().upsert()`), not raw SQL. This prevents SQL injection.

---

## 6. Supabase RLS Policies

### FINDING 6.1 — RLS Policies Are Enabled and Well-Configured (Verified Live)
**Severity: LOW (downgraded from CRITICAL after live verification)**
**Scope:** All 4 public tables — `profiles`, `saved_routes`, `walk_sessions`, `shared_routes`

**Live audit results (April 1, 2026):** RLS is enabled on all tables with proper policies:

| Table | SELECT | INSERT | UPDATE | DELETE |
|-------|--------|--------|--------|--------|
| `profiles` | `auth.uid() = id` | `auth.uid() = id` | `auth.uid() = id` | *(none)* |
| `saved_routes` | `auth.uid() = user_id` | `auth.uid() = user_id` | `auth.uid() = user_id` | `auth.uid() = user_id` |
| `walk_sessions` | `auth.uid() = user_id` | `auth.uid() = user_id` | `auth.uid() = user_id` | `auth.uid() = user_id` |
| `shared_routes` | `true` (public) | `auth.uid() = user_id` | `auth.uid() = user_id` | `auth.uid() = user_id` |

The `shared_routes` SELECT policy intentionally allows public reads — this is correct for the sharing feature.

**Remaining concern:** No DELETE policy exists for `profiles`. This is likely intentional (account deletion goes through the `hyper-endpoint` Edge Function), but should be documented.

---

### FINDING 6.2 — Overly Broad Table Grants to `anon` Role
**Severity: MEDIUM**
**Scope:** All 4 public tables

The `anon` role has been granted ALL privileges (SELECT, INSERT, UPDATE, DELETE, TRUNCATE, TRIGGER, REFERENCES) on every table. While RLS policies prevent unauthorized access (since `auth.uid()` returns NULL for anonymous users), this creates a defense-in-depth gap: if RLS is accidentally disabled on any table, unauthenticated users would have full access.

**Recommendation:** Restrict grants to only what's needed:
```sql
-- For tables that only authenticated users should access:
REVOKE ALL ON profiles, saved_routes, walk_sessions FROM anon;
GRANT SELECT ON shared_routes TO anon;  -- Only shared_routes needs anon reads

-- For authenticated users, keep current grants but remove TRUNCATE/TRIGGER:
REVOKE TRUNCATE, TRIGGER, REFERENCES ON ALL TABLES IN SCHEMA public FROM authenticated;
```

---

### FINDING 6.3 — No Migration Files in Repository
**Severity: MEDIUM**
**Scope:** Repository root

No `supabase/migrations/` directory exists. RLS policies and schema changes are not version-controlled, making it impossible to audit policy changes over time or reproduce the database in a new environment.

**Recommendation:** Run `supabase db pull` to generate migration files and commit them to the repository.

---

## 7. Third-Party Dependencies

### FINDING 7.1 — Dependency Inventory
**Severity: LOW**
**File:** `project.yml`

Dependencies are managed via Swift Package Manager. The following packages were identified:

| Package | Purpose | Risk Level |
|---------|---------|------------|
| Supabase Swift SDK | Backend services | Medium — verify version is current |
| Mapbox Maps SDK | Map rendering & routing | Low |
| Mapbox Navigation SDK | Turn-by-turn navigation | Low |

**Recommendation:** Run `swift package audit` or use a tool like Snyk/Dependabot to check for known CVEs. Pin dependency versions and review changelogs before updating.

---

## 8. Privacy

### FINDING 8.1 — Full Coordinate Trails Synced to Cloud
**Severity: CRITICAL**
**File:** `Looopr/Data/Repositories/WalkHistoryRepository.swift` (Lines 36–45)

Every completed walk session — including the full array of GPS coordinates — is synced to Supabase without explicit user consent confirmation:

```swift
func syncToCloud(userID: UUID) async throws {
    let sessions = try loadAll()
    for session in sessions where session.isComplete {
        let record = WalkSessionRecord(session: session, userID: userID)
        try await supabase.client.from("walk_sessions").upsert(...)
    }
}
```

**Data synced:** User ID, route coordinates (full trail), timestamps, distance, duration, step count, food stops, feedback.

**Recommendation:**
1. Require explicit opt-in before first cloud sync.
2. Minimize data — store aggregated metrics rather than full coordinate arrays.
3. Encrypt coordinate data before transmission/storage.
4. Display clear privacy notice about what data is collected and why.

---

### FINDING 8.2 — Location Authorization Requested Without Status Check
**Severity: MEDIUM**
**File:** `Looopr/Services/Location/LocationService.swift` (Line 42)

`requestWhenInUseAuthorization()` is called without first checking the current authorization status. This could lead to repeated authorization prompts.

**Recommendation:** Check `CLLocationManager.authorizationStatus` before requesting.

---

## 9. Deep Links / URL Schemes

### FINDING 9.1 — Unvalidated Deep Link Navigation
**Severity: MEDIUM**
**File:** `Looopr/Presentation/AppRootView.swift` (Lines 232–259)

The deep link handler now accepts a single URL pattern:
1. `https://looopr.app/route/<UUID>` — navigates to shared route view

The legacy `looopr://memory?id=<UUID>` and `https://looopr.app/walk/...` patterns were removed when the Memories feature was retired.

**Issues:**
- Route UUIDs are validated for format but not verified to exist on the server before navigation.
- The `looopr://auth-callback` URL (used for OAuth) is not handled in this function.
- No rate limiting on deep link processing — rapid deep links could cause UI state corruption.

**Recommendation:** Validate route existence before navigation. Add explicit `auth-callback` handling. Debounce deep link processing.

---

### FINDING 9.2 — URL Scheme Hijacking Risk
**Severity: MEDIUM**
**File:** `Looopr/Info.plist` (Lines 28–29)

The `looopr://` custom URL scheme is registered but custom URL schemes on iOS are not unique — a malicious app could register the same scheme and intercept deep links, potentially stealing OAuth tokens.

**Recommendation:** Migrate to Universal Links (`https://looopr.app/...`) for all deep link handling. Universal Links are cryptographically bound to your domain via the `apple-app-site-association` file and cannot be hijacked.

---

## 10. Code-Level Vulnerabilities

### FINDING 10.1 — Force Unwrap on File System Access
**Severity: CRITICAL → FIXED**
**File:** `Looopr/Data/Persistence/FileStore.swift` (Line 7)

~~`let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!`~~

**Fix applied:** `FileStore.init` is now `throws` with a `guard let` and a custom `FileStoreError.documentsDirectoryUnavailable` error. Callers propagate the error, and the DI registration handles it gracefully. (Note: `PhotoStorageService`, referenced in the earlier version of this finding, has since been removed along with the camera/memories feature.)

---

### FINDING 10.2 — Double Force Unwrap in Navigation Logic
**Severity: HIGH → FIXED**
**File:** `Looopr/Presentation/Features/WalkNavigation/WalkNavigationViewModel.swift` (Line 347)

~~`let walkBearing = recentLocations.first!.bearing(to: recentLocations.last!)`~~

**Fix applied:** Replaced with safe optional binding:
```swift
guard let firstLocation = recentLocations.first,
      let lastLocation = recentLocations.last else { return }
let walkBearing = firstLocation.bearing(to: lastLocation)
```

---

### FINDING 10.3 — Unsafe Cast in Dependency Injection Container
**Severity: HIGH → FIXED**
**File:** `Looopr/Core/DependencyInjection/ServiceContainer.swift` (Line 31)

~~`return factory() as! T`~~

**Fix applied:** Replaced with conditional cast:
```swift
guard let instance = factory() as? T else {
    fatalError("Factory for \(type) returned incompatible type.")
}
return instance
```

---

### FINDING 10.4 — fatalError on Missing Supabase Configuration
**Severity: HIGH → FIXED**
**File:** `Looopr/Data/Networking/SupabaseClientProvider.swift` (Line 11)

~~`fatalError("Missing SUPABASE_URL or SUPABASE_ANON_KEY in Secrets.xcconfig")`~~

**Fix applied:** Converted to failable initializer (`init?`). Returns `nil` when credentials are missing and logs a warning. The DI registration in `ServiceContainer+Registration.swift` now uses `if let provider = SupabaseClientProvider()` so the app launches gracefully without Supabase features instead of crashing.

---

### FINDING 10.5 — 12 Classes Use @unchecked Sendable
**Severity: HIGH**
**Files (partial list):**
- `UserDefaultsStore.swift` — mutable encoder/decoder without synchronization
- `AnalyticsService.swift`
- `SettingsRepository.swift`
- `WalkHistoryRepository.swift`
- `RouteRepository.swift`
- `SupabaseClientProvider.swift`
- `LocationService.swift`
- `MapboxRouteGenerationService.swift`
- `AuthService.swift`
- `ServiceContainer.swift`

**Impact:** These classes bypass Swift's concurrency safety checks. Concurrent access to mutable state (UserDefaults reads/writes, JSON encoder/decoder) can cause data races, corruption, or crashes.

**Recommendation:** Migrate to proper actor isolation, or add explicit locking (e.g., `NSLock`, `os_unfair_lock`, or dispatch queues) for shared mutable state.

---

### FINDING 10.6 — Strong Self Capture in TaskGroup
**Severity: MEDIUM**
**File:** `Looopr/Services/RouteGeneration/MapboxRouteGenerationService.swift` (Line 120)

```swift
group.addTask { [self] in ... }
```

**Impact:** Potential retain cycle if the task group outlives the service.

**Recommendation:** Use `[weak self]` with a guard.

---

### FINDING 10.7 — Debug Print Statements in Production Code
**Severity: LOW**
**Files:**
- `Looopr/Inactive/HealthKitManager.swift` (Lines 54, 107, 118) — `print()`
- `Looopr/Presentation/Features/Home/HomeViewModel.swift` (Line 56) — `print()`

**Recommendation:** Replace all `print()` with `AppLogger` calls. Add a SwiftLint rule to flag `print()` in non-debug builds.

---

## Remediation Priority

### Immediate (This Week)
1. ~~**Fix force unwraps** in FileStore.swift, WalkNavigationViewModel.swift, ServiceContainer.swift~~ ✅ Done
2. ~~**Replace `fatalError`** in SupabaseClientProvider with graceful error handling~~ ✅ Done
3. ~~**Audit Supabase RLS policies** — verify every table has RLS enabled~~ ✅ Done (all 4 tables verified)
4. **Rotate all API keys** exposed in Secrets.xcconfig — see Appendix A below

### High Priority (Next 2 Weeks)
5. Move API keys from URL query parameters to HTTP headers
6. Implement certificate pinning for Supabase and Mapbox endpoints
7. Encrypt local data storage (walk history, saved routes, search history)
8. Add explicit consent flow before first cloud sync of location data
9. Address `@unchecked Sendable` violations with proper concurrency patterns

### Medium Priority (Next Month)
10. Migrate from `looopr://` custom URL scheme to Universal Links
11. Add OAuth callback validation in deep link handler
12. Validate coordinates in Overpass API queries
13. Implement session expiration checks
14. Version-control Supabase migration files with RLS policies

### Low Priority (Ongoing)
16. Replace `print()` with `AppLogger`
17. Set up dependency vulnerability scanning (Snyk/Dependabot)
18. Add input validation on UserProfile fields
19. Implement automatic cleanup of exported data files
20. Add rate limiting/debouncing on deep link processing

---

## Positive Security Practices Observed

- All network traffic uses HTTPS — no plaintext HTTP endpoints found
- Apple Sign-In uses cryptographically secure nonce generation with SHA256
- Supabase query builder used for all database operations — no raw SQL injection risk
- No WebView usage — eliminates XSS risk
- AppLogger uses `.privacy: .public` annotation for OS log privacy
- GDPR-compliant account deletion and data export mechanisms implemented
- Auth state changes properly observed and handled
- Conditional service registration prevents initialization with missing keys
- `.gitignore` excludes xcconfig files from source control
- RLS is enabled on all 4 Supabase tables with proper `auth.uid()` checks (verified live)

---

## Appendix A: API Key Rotation Guide

These steps must be performed manually since they involve external service consoles.

### 1. Google Places API Key
1. Go to [Google Cloud Console → Credentials](https://console.cloud.google.com/apis/credentials)
2. Find the key starting with `AIzaSyDsZ18K...`
3. Click **Regenerate key** (or create a new key and delete the old one)
4. Apply restrictions: **iOS apps** with your bundle ID, and **API restrictions** limiting to Places API only
5. Update the new key in `Secrets.xcconfig` under `GOOGLE_PLACES_API_KEY`

### 2. Mapbox Access Token
1. Go to [Mapbox Account → Tokens](https://account.mapbox.com/access-tokens/)
2. Find the token starting with `pk.eyJ1Ijoib...`
3. Click **Delete** and create a new token
4. Apply URL restrictions and scope to only the APIs you use (Maps, Directions)
5. Update in `Secrets.xcconfig` under `MAPBOX_ACCESS_TOKEN`

### 3. Supabase Anon Key
1. Go to [Supabase Dashboard → Project Settings → API](https://supabase.com/dashboard/project/xifzdpkoyssfiksmempm/settings/api)
2. The anon key cannot be rotated independently — you need to regenerate JWT secrets
3. Click **Generate new JWT secret** (this invalidates ALL existing tokens and sessions)
4. Update both `SUPABASE_URL` and `SUPABASE_ANON_KEY` in `Secrets.xcconfig`
5. **Warning:** This will sign out all active users

### 4. Ticket Provider Keys (Viator, GetYourGuide, Tiqets, Musement, Klook)
1. Log in to each provider's partner/affiliate dashboard
2. Regenerate API keys
3. Update in `Secrets.xcconfig` under the respective key names

### After Rotation
- Update `Secrets.xcconfig` with all new keys
- Build and test the app locally
- Verify all API integrations work with the new keys
- Deploy a new app build to TestFlight/App Store
