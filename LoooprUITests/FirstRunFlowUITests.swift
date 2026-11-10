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
    private var shotIndex = 0

    override func setUpWithError() throws {
        continueAfterFailure = false
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
            "-AppleLanguages", "(en)", "-AppleLocale", "en_GB"
        ]
        app.launch()
    }

    func testFirstRunGoesFromIntroToLoopsWithoutASignInWall() throws {
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

    private func shot(_ name: String) {
        shotIndex += 1
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
