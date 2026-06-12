import XCTest

/// Walks the main screens, capturing a screenshot of each for CI.
/// Uses the DEBUG-only "DEV BYPASS" row to skip sign-in.
final class ScreenshotUITests: XCTestCase {
    func testCaptureMainScreens() throws {
        let app = XCUIApplication()
        app.launch()

        capture(app, name: "00-auth")

        tap(containing: "BYPASS", in: app)
        capture(app, name: "01-home")

        tap(containing: "HISTORY", in: app)
        capture(app, name: "02-history")
        tap(containing: "HOME", in: app)

        tap(containing: "TRENDS", in: app)
        capture(app, name: "03-trends")
        tap(containing: "HOME", in: app)

        tap(containing: "COURSES", in: app)
        capture(app, name: "04-courses")
        tap(containing: "HOME", in: app)

        tap(containing: "SETTINGS", in: app)
        capture(app, name: "05-settings")
        tap(containing: "HOME", in: app)

        tap(containing: "Start new round", in: app)
        capture(app, name: "06-setup")
    }

    private func capture(_ app: XCUIApplication, name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    private func tap(containing text: String, in app: XCUIApplication, timeout: TimeInterval = 10) {
        let predicate = NSPredicate(format: "label CONTAINS %@", text)
        let element = app.descendants(matching: .any).matching(predicate).firstMatch
        XCTAssertTrue(element.waitForExistence(timeout: timeout), "Could not find element containing '\(text)'")
        element.tap()
        usleep(500_000)
    }
}
