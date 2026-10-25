import XCTest

@MainActor private func currentScreenshotLocale() -> String {
    let identifier = Locale.current.identifier.lowercased()
    if identifier.contains("zh") { return "zh-Hans" }
    if identifier.contains("ja") { return "ja" }
    return "en"
}

@MainActor private func captureStoreScreenshots(testCase: XCTestCase) {
    let locale = currentScreenshotLocale()
    let includeDark = locale != "ja"
    let homeArgs = ["-store-screenshot"]
    let emptyArgs = ["-store-screenshot-empty"]
    let paywallArgs = ["-store-screenshot", "-store-screenshot-paywall"]
    let appearances: [(XCUIDevice.Appearance, String)] = includeDark
        ? [(.light, "light"), (.dark, "dark")]
        : [(.light, "light")]

    for (appearance, appearanceName) in appearances {
        capture(locale: locale, page: "home", appearance: appearance,
                appearanceName: appearanceName, arguments: homeArgs,
                expectedIdentifier: "export-pdf", testCase: testCase)
        if includeDark {
            capture(locale: locale, page: "empty", appearance: appearance,
                    appearanceName: appearanceName, arguments: emptyArgs,
                    expectedIdentifier: "choose-photo", testCase: testCase)
            capture(locale: locale, page: "paywall", appearance: appearance,
                    appearanceName: appearanceName, arguments: paywallArgs,
                    expectedIdentifier: "paywall-close", testCase: testCase)
        }
    }
}

@MainActor private func capture(locale: String, page: String, appearance: XCUIDevice.Appearance,
                                appearanceName: String, arguments: [String], expectedIdentifier: String,
                                testCase: XCTestCase) {
    let app = XCUIApplication()
    app.launchArguments = arguments
    XCUIDevice.shared.appearance = appearance
    app.launch()

    XCTAssertTrue(
        app.buttons[expectedIdentifier].waitForExistence(timeout: 25),
        "Missing \(expectedIdentifier) for \(locale)/\(appearanceName)/\(page)"
    )
    Thread.sleep(forTimeInterval: 0.8)

    let attachment = XCTAttachment(screenshot: app.screenshot())
    attachment.name = "\(locale)-\(appearanceName)-\(page)"
    attachment.lifetime = .keepAlways
    testCase.add(attachment)
    app.terminate()
}

@MainActor final class StoreScreenshotTests: XCTestCase {
    func testStoreScreenshot() {
        continueAfterFailure = false
        captureStoreScreenshots(testCase: self)
    }
}
