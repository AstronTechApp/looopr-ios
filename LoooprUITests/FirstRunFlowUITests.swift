import XCTest
import CoreLocation

/// Walks the 1.5 first-run flow the way a new user would and saves a
/// screenshot at each step (to ~/Muter/.claude/uitest-shots on the Mac when
/// run on the simulator), so the result can be checked by eye as well.
///
/// Needs network (Mapbox, RevenueCat test store). Runs as a guest: the
/// simulator must not hold a signed-in Looopr session.
final class FirstRunFlowUITests: XCTestCase {

    private var app: XCUIApplication!
    private var shotPrefix = ""

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    override func tearDown() {
        XCUIDevice.shared.appearance = .light
        super.tearDown()
    }

    private func launchFresh(appearance: XCUIDevice.Appearance) {
        XCUIDevice.shared.appearance = appearance
        shotPrefix = appearance == .dark ? "dark-" : ""
        // Marylebone, London: a dense street grid, the kind of place a
        // UK user starts from.
        XCUIDevice.shared.location = XCUILocation(location: CLLocation(latitude: 51.5226, longitude: -0.1571))
        app = XCUIApplication()
        app.launchArguments += [
            // A brand-new install, as far as the app's own flags go.
            "-onboarding.hasCompleted", "NO",
            "-auth.continuedAsGuest", "NO",
            "-paywall.firstSearchShown", "NO",
            "-accountPrompt.afterWalkOffered", "NO",
            "-AppleLanguages", "(en)", "-AppleLocale", "en_GB",
            "-uiTest.appearance", appearance == .dark ? "dark" : "light"
        ]
        app.launch()
    }

    func testFirstRunGoesFromIntroToLoopsWithoutASignInWall() throws {
        launchFresh(appearance: .light)
        try runFirstRunFlow()
    }

    /// The same flow in dark mode (1.5): every screen must stay readable.
    func testFirstRunInDarkMode() throws {
        launchFresh(appearance: .dark)
        try runFirstRunFlow()
    }

    /// Settings in the longest-label languages: no row value may wrap.
    func testSettingsInDutchAndGerman() throws {
        for lang in ["nl", "de"] {
            XCUIDevice.shared.appearance = .light
            shotPrefix = "settings-"
            app = XCUIApplication()
            app.launchArguments += [
                "-onboarding.hasCompleted", "YES",
                "-auth.continuedAsGuest", "YES",
                "-AppleLanguages", "(\(lang))", "-AppleLocale", lang == "nl" ? "nl_NL" : "de_DE",
                "-uiTest.appearance", "light"
            ]
            app.launch()
            let profile = app.buttons[lang == "nl" ? "Profiel" : "Profil"].firstMatch
            XCTAssertTrue(profile.waitForExistence(timeout: 10))
            profile.tap()
            let gear = app.buttons["profileSettingsButton"]
            XCTAssertTrue(gear.waitForExistence(timeout: 5))
            gear.tap()
            sleep(2)
            shot(lang)
            app.swipeUp()
            sleep(1)
            shot("\(lang)-2")
            app.terminate()
        }
    }

    // MARK: - 13 Nov: blank screen in front of Home after a search
    //
    // After a search, going back to Home showed a blank screen with only
    // the system back button; Home appeared after pressing back once more.

    func testHomeTabFromRouteListShowsHome() throws {
        try searchAsGuest(shot: "a")
        app.buttons["Home"].firstMatch.tap()
        assertHomeShown(shot: "a")
        // The blank screen came and went; repeat the round trip.
        for round in 2...5 {
            sleep(1)
            app.buttons["Find My Looopr"].tap()
            let loaded = app.buttons["routeCardMap"].firstMatch.waitForExistence(timeout: 60)
            shot("a\(round)-loops")
            XCTAssertTrue(loaded, "loops should load (round \(round))")
            app.buttons["Home"].firstMatch.tap()
            assertHomeShown(shot: "a\(round)")
        }
    }

    func testHomeTabFromRouteDetailShowsHome() throws {
        try searchAsGuest(shot: "b")
        app.buttons.matching(identifier: "routeCardMap").firstMatch.tap()
        sleep(2)
        shot("b-detail")
        app.buttons["Home"].firstMatch.tap()
        assertHomeShown(shot: "b")
    }

    func testBackFromRouteListShowsHome() throws {
        try searchAsGuest(shot: "c")
        app.buttons["routeListBack"].tap()
        assertHomeShown(shot: "c")
    }

    func testBackFromDetailThenListShowsHome() throws {
        try searchAsGuest(shot: "d")
        app.buttons.matching(identifier: "routeCardMap").firstMatch.tap()
        sleep(2)
        app.buttons["routeDetailBack"].tap()
        sleep(1)
        app.buttons["routeListBack"].tap()
        assertHomeShown(shot: "d")
    }

    private func searchAsGuest(shot prefix: String) throws {
        XCUIDevice.shared.appearance = .light
        shotPrefix = "home-after-search-"
        XCUIDevice.shared.location = XCUILocation(location: CLLocation(latitude: 52.0907, longitude: 5.1214))
        app = XCUIApplication()
        app.launchArguments += [
            "-onboarding.hasCompleted", "YES",
            "-auth.continuedAsGuest", "YES",
            "-paywall.firstSearchShown", "YES",
            "-AppleLanguages", "(en)", "-AppleLocale", "en_GB",
            "-uiTest.appearance", "light"
        ]
        app.launch()
        let find = app.buttons["Find My Looopr"]
        XCTAssertTrue(find.waitForExistence(timeout: 10))
        find.tap()
        allowLocationIfAsked()
        XCTAssertTrue(app.buttons["routeCardMap"].firstMatch.waitForExistence(timeout: 60), "loops should load")
    }

    private func assertHomeShown(shot prefix: String) {
        let find = app.buttons["Find My Looopr"]
        let shown = find.waitForExistence(timeout: 3) && find.isHittable
        shot("\(prefix)-after")
        XCTAssertTrue(shown, "Home must show straight away, not a blank screen with a back button")
    }

    // MARK: - 13 Nov: Settings > Appearance (System / Light / Dark)

    /// The phone stays in light mode; the app must turn dark when Dark is
    /// chosen, light again on Light, and end on System.
    func testAppearanceCanBeChosenInSettings() throws {
        XCUIDevice.shared.appearance = .light
        shotPrefix = "appearance-"
        app = XCUIApplication()
        // No -uiTest.appearance here: that override would hide the setting.
        app.launchArguments += [
            "-onboarding.hasCompleted", "YES",
            "-auth.continuedAsGuest", "YES",
            "-AppleLanguages", "(en)", "-AppleLocale", "en_GB"
        ]
        app.launch()
        let profile = app.buttons["Profile"].firstMatch
        XCTAssertTrue(profile.waitForExistence(timeout: 10))
        profile.tap()
        let gear = app.buttons["profileSettingsButton"]
        XCTAssertTrue(gear.waitForExistence(timeout: 5))
        gear.tap()

        let menu = app.buttons["settingsAppearanceMenu"]
        XCTAssertTrue(menu.waitForExistence(timeout: 5), "Settings should have an Appearance row")
        for (choice, name) in [("Dark", "1-dark"), ("Light", "2-light"), ("System", "3-system")] {
            scrollTo(menu, attempts: 3)
            menu.tap()
            let option = app.buttons[choice]
            XCTAssertTrue(option.waitForExistence(timeout: 3), "the menu should offer \(choice)")
            option.tap()
            sleep(1)
            shot(name)
        }
        app.terminate()
    }

    // MARK: - 13 Nov: route card row and equal POI tabs
    //
    // The card's map says "View map" and the card has a row that opens the
    // route detail. On the detail, the POI tabs are equal-width, so Food &
    // Drinks no longer sits cut off on the right.

    func testRouteCardRowOpensDetailWithAllTabsOnScreen() throws {
        try checkRouteCardAndTabs(lang: "en", appearance: .light, pro: false, shot: "en")
    }

    func testRouteCardRowAndTabsInDarkMode() throws {
        try checkRouteCardAndTabs(lang: "en", appearance: .dark, pro: false, shot: "en-dark")
    }

    /// The longest tab names: they may wrap to two lines but stay in the tab.
    func testRouteCardRowAndTabsInDutch() throws {
        try checkRouteCardAndTabs(lang: "nl", appearance: .light, pro: false, shot: "nl")
    }

    func testRouteCardRowAndTabsInGerman() throws {
        try checkRouteCardAndTabs(lang: "de", appearance: .light, pro: false, shot: "de")
    }

    func testRouteCardRowAndTabsAsPro() throws {
        try checkRouteCardAndTabs(lang: "en", appearance: .light, pro: true, shot: "en-pro")
    }

    private func checkRouteCardAndTabs(lang: String, appearance: XCUIDevice.Appearance, pro: Bool, shot name: String) throws {
        XCUIDevice.shared.appearance = appearance
        shotPrefix = "card-tabs-"
        // Amsterdam canal belt: sights on and near the loop, so all three
        // tabs show.
        XCUIDevice.shared.location = XCUILocation(location: CLLocation(latitude: 52.3667, longitude: 4.8945))
        app = XCUIApplication()
        let locale = ["en": "en_GB", "nl": "nl_NL", "de": "de_DE"][lang] ?? "en_GB"
        app.launchArguments += [
            "-onboarding.hasCompleted", "YES",
            "-auth.continuedAsGuest", "YES",
            "-paywall.firstSearchShown", "YES",
            "-AppleLanguages", "(\(lang))", "-AppleLocale", locale,
            "-uiTest.appearance", appearance == .dark ? "dark" : "light",
            "-uiTest.pro", pro ? "YES" : "NO"
        ]
        app.launch()
        let findLabel = ["en": "Find My Looopr", "nl": "Vind Mijn Looopr", "de": "Meinen Looopr finden"][lang] ?? "Find My Looopr"
        let find = app.buttons[findLabel]
        XCTAssertTrue(find.waitForExistence(timeout: 10))
        find.tap()
        allowLocationIfAsked()
        XCTAssertTrue(app.buttons["routeCardMap"].firstMatch.waitForExistence(timeout: 60), "loops should load")

        // The card: a row under the stats that opens the route detail.
        let row = app.buttons["routeCardPOIRow"].firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 5), "the card should have its 'along this loop' row")
        sleep(1)
        shot("\(name)-1-card")
        scrollTo(row, attempts: 3)
        row.tap()

        // The detail: every tab fully on screen, nothing to drag.
        let food = app.buttons["poiTab.food"]
        XCTAssertTrue(food.waitForExistence(timeout: 60), "route detail should show the Food & Drinks tab")
        sleep(1)
        shot("\(name)-2-detail")
        let screen = app.windows.firstMatch.frame
        for id in ["poiTab.onRoute", "poiTab.nearRoute", "poiTab.food"] {
            let tab = app.buttons[id]
            guard tab.exists else { continue }
            XCTAssertTrue(tab.frame.minX >= screen.minX && tab.frame.maxX <= screen.maxX,
                          "\(id) should be fully on screen, not cut off")
        }

        if pro {
            XCTAssertTrue(food.label.contains("10+"), "Pro sees the teaser count until the places load")
        } else {
            XCTAssertTrue(food.label.contains("Pro"), "free users see Pro where the count goes")
            scrollTo(food, attempts: 2)
            food.tap()
            sleep(1)
            shot("\(name)-3-food-locked")
            if lang == "en" {
                XCTAssertTrue(app.buttons["Try Pro free"].waitForExistence(timeout: 5), "the locked tab offers Pro in place")
            }
        }
        app.terminate()
    }

    // MARK: - 13 Nov: sights never silently missing

    /// Opens several loops' details back to back, the way that made MapKit
    /// throttle the sight searches (Pedro, 13 Nov: no sights on a loop past
    /// the Rijksmuseum). Each detail must end with sights or with the
    /// "Try again" notice, never with an empty list that reads as "no
    /// sights here". Writes a summary to uitest-shots/sights-run.txt.
    func testSightsNeverSilentlyMissingAcrossSeveralLoops() throws {
        XCUIDevice.shared.appearance = .light
        shotPrefix = "sights-"
        XCUIDevice.shared.location = XCUILocation(location: CLLocation(latitude: 52.3600, longitude: 4.8852))
        app = XCUIApplication()
        app.launchArguments += [
            "-onboarding.hasCompleted", "YES",
            "-auth.continuedAsGuest", "YES",
            "-paywall.firstSearchShown", "YES",
            "-AppleLanguages", "(en)", "-AppleLocale", "en_GB",
            "-uiTest.appearance", "light",
            "-uiTest.pro", "YES"
        ]
        app.launch()
        let find = app.buttons["Find My Looopr"]
        XCTAssertTrue(find.waitForExistence(timeout: 10))
        find.tap()
        allowLocationIfAsked()
        XCTAssertTrue(app.buttons["routeCardMap"].firstMatch.waitForExistence(timeout: 60), "loops should load")
        sleep(2)

        let cards = app.buttons.matching(identifier: "routeCardMap")
        let loopCount = min(cards.count, 5)
        var log: [String] = ["loops: \(cards.count), opening \(loopCount)"]
        let start = Date()

        writeLog(log, to: "sights-run.txt")
        for i in 0..<loopCount {
            let card = cards.element(boundBy: i)
            scrollTo(card, attempts: 6)
            log.append("loop \(i + 1): card exists=\(card.exists) hittable=\(card.isHittable)")
            writeLog(log, to: "sights-run.txt")
            card.tap()

            let onRoute = app.buttons["poiTab.onRoute"]
            let nearRoute = app.buttons["poiTab.nearRoute"]
            let unavailable = app.otherElements["routeDetail.sightsUnavailable"]
            let more = app.descendants(matching: .any)["routeDetail.findingMoreSights"]
            var sawMore = false
            var outcome = "nothing (silently empty)"
            let opened = Date()
            var firstSight: TimeInterval?
            let deadline = Date().addingTimeInterval(50)
            while Date() < deadline {
                if firstSight == nil && (onRoute.exists || nearRoute.exists) {
                    firstSight = Date().timeIntervalSince(opened)
                }
                if more.exists && !sawMore {
                    sawMore = true
                    shot("loop\(i + 1)-finding-more")
                }
                if unavailable.exists { outcome = "Try again notice"; break }
                if (onRoute.exists || nearRoute.exists) && !more.exists { outcome = "sights"; break }
                usleep(500_000)
            }
            let t = Int(Date().timeIntervalSince(start))
            let full = Date().timeIntervalSince(opened)
            let first = firstSight.map { String(format: "%.1fs", $0) } ?? "-"
            log.append("loop \(i + 1) at \(t)s: \(outcome); first sight after \(first), complete after \(String(format: "%.1fs", full))\(sawMore ? ", showed 'Finding more sights'" : "")")
            shot("loop\(i + 1)")
            XCTAssertNotEqual(outcome, "nothing (silently empty)", "loop \(i + 1): sights or a Try again notice")

            if outcome == "Try again notice" {
                app.buttons["routeDetail.sightsTryAgain"].tap()
                log.append("  tapped Try again")
                let ok = onRoute.waitForExistence(timeout: 60) || nearRoute.exists || unavailable.exists
                log.append("  after Try again: \(onRoute.exists || nearRoute.exists ? "sights" : unavailable.exists ? "notice again" : "nothing")")
                shot("loop\(i + 1)-after-try-again")
                XCTAssertTrue(ok)
            }

            writeLog(log, to: "sights-run.txt")
            app.buttons["routeDetailBack"].tap()
            sleep(1)
        }

        // Reopening a loop uses its cached sights: covered by the unit test
        // testReopeningALoopUsesItsCachedSights.
        writeLog(log, to: "sights-run.txt")
        app.terminate()
    }

    private func writeLog(_ lines: [String], to file: String) {
        guard let home = ProcessInfo.processInfo.environment["SIMULATOR_HOST_HOME"] else { return }
        let url = URL(fileURLWithPath: home).appendingPathComponent("Muter/.claude/uitest-shots/\(file)")
        try? (lines.joined(separator: "\n") + "\n").write(to: url, atomically: true, encoding: .utf8)
    }

    private func runFirstRunFlow() throws {
        // 1 · Intro, three pages.
        XCTAssertTrue(app.buttons["Next"].waitForExistence(timeout: 10), "intro should open on first launch")
        shot("01-intro-page1")
        app.buttons["Next"].tap()
        app.buttons["Next"].tap()
        XCTAssertTrue(app.buttons["Get started"].waitForExistence(timeout: 5))
        shot("02-intro-page3")
        app.buttons["Get started"].tap()

        // 2 · Straight to Home: no sign-in screen in between (item 12).
        let find = app.buttons["Find My Looopr"]
        XCTAssertTrue(find.waitForExistence(timeout: 10), "Home should follow the intro directly")
        XCTAssertFalse(app.buttons["Continue without an account"].exists, "no sign-in wall at launch")
        shot("03-home-as-guest")

        // 3 · Search. Answer the location prompt if iOS shows it.
        find.tap()
        allowLocationIfAsked()

        // 4 · Loops arrive; the first search shows the paywall on its own
        //     about two seconds later (item 13).
        XCTAssertTrue(app.buttons["routeCardMap"].firstMatch.waitForExistence(timeout: 60), "loops should load")
        shot("04-loops")
        let paywallAppeared = waitForPaywall(timeout: 15)
        shot("05-paywall-first-search")
        XCTAssertTrue(paywallAppeared, "first search with loops should show the paywall once")
        closePaywall()

        // 5 · Two open loops, then the locked ones (items 2 and 14).
        XCTAssertEqual(app.buttons.matching(identifier: "routeCardMap").count, 2, "free users open two loops")
        let lockedCTA = app.buttons["lockedRoutesCTA"]
        scrollTo(lockedCTA)
        shot("06-locked-loops")
        XCTAssertTrue(lockedCTA.exists, "extra loops should be shown locked")
        lockedCTA.tap()
        XCTAssertTrue(waitForPaywall(timeout: 15), "a locked loop opens the paywall")
        shot("07-paywall-from-locked-loop")
        closePaywall()

        // 6 · Route detail: no invented elevation or difficulty (item 1).
        app.swipeDown(); app.swipeDown(); app.swipeDown()
        app.buttons.matching(identifier: "routeCardMap").firstMatch.tap()
        sleep(3)
        shot("08-route-detail")
        XCTAssertFalse(app.staticTexts["Difficulty"].exists)
        XCTAssertEqual(app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH '+' AND label ENDSWITH ' m'")).count, 0,
                       "no '+72 m'-style elevation on the route")

        // 7 · Cafés tab is locked with the free-week wording (item 13).
        let food = app.buttons.matching(NSPredicate(format: "label CONTAINS 'Food'")).firstMatch
        if food.waitForExistence(timeout: 5) {
            scrollTo(food)
            food.tap()
            sleep(1)
            shot("09-cafes-locked")
            XCTAssertTrue(app.buttons["Try Pro free"].exists || app.staticTexts["Try Pro free"].exists)
        }

        // 8 · Profile tab.
        let profile = app.buttons["Profile"].firstMatch
        if profile.waitForExistence(timeout: 5) {
            profile.tap()
            sleep(2)
            shot("10-profile")
        }
    }

    // MARK: - Helpers

    private func allowLocationIfAsked() {
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        for label in ["Allow While Using App", "Allow Once", "Allow"] {
            let button = springboard.buttons[label]
            if button.waitForExistence(timeout: label == "Allow While Using App" ? 8 : 1) {
                button.tap()
                return
            }
        }
    }

    /// RevenueCat's paywall shows the plan prices; that is the tell.
    private func waitForPaywall(timeout: TimeInterval) -> Bool {
        let price = app.staticTexts.matching(NSPredicate(format: "label CONTAINS '/mo' OR label CONTAINS '/yr' OR label CONTAINS 'Continue' OR label CONTAINS 'Restore'")).firstMatch
        let restore = app.buttons.matching(NSPredicate(format: "label CONTAINS 'Restore'")).firstMatch
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if price.exists || restore.exists { return true }
            usleep(300_000)
        }
        return false
    }

    private func closePaywall() {
        let close = app.buttons.matching(NSPredicate(format: "label ==[c] 'Close' OR identifier CONTAINS[c] 'close'")).firstMatch
        if close.waitForExistence(timeout: 5) {
            close.tap()
        } else {
            app.swipeDown(velocity: .fast)
        }
        sleep(1)
    }

    private func scrollTo(_ element: XCUIElement, attempts: Int = 8) {
        var tries = 0
        while (!element.exists || !element.isHittable) && tries < attempts {
            app.swipeUp()
            tries += 1
        }
    }

    private func shot(_ rawName: String) {
        let name = shotPrefix + rawName
        let image = XCUIScreen.main.screenshot()
        let attachment = XCTAttachment(screenshot: image)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
        if let home = ProcessInfo.processInfo.environment["SIMULATOR_HOST_HOME"] {
            let dir = URL(fileURLWithPath: home).appendingPathComponent("Muter/.claude/uitest-shots", isDirectory: true)
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            try? image.pngRepresentation.write(to: dir.appendingPathComponent("\(name).png"))
        }
    }
}
