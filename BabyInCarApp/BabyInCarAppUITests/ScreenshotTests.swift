import XCTest

final class ScreenshotTests: XCTestCase {

    let app = XCUIApplication()

    override func setUpWithError() throws {
        continueAfterFailure = false
        app.launch()
    }

    func testTakeAppStoreScreenshots() throws {
        // Wait for splash screen to dismiss
        sleep(5)

        // Screenshot 1: Home Screen
        saveScreenshot(name: "1_home_APP_IPHONE_67_0")

        // Tap on Library tab
        let libraryTab = app.tabBars.buttons["Library"]
        if libraryTab.waitForExistence(timeout: 3) {
            libraryTab.tap()
            sleep(2)
            saveScreenshot(name: "2_library_APP_IPHONE_67_0")
        }

        // Tap on Detect tab
        let detectTab = app.tabBars.buttons["Detect"]
        if detectTab.waitForExistence(timeout: 3) {
            detectTab.tap()
            sleep(2)
            saveScreenshot(name: "3_detect_APP_IPHONE_67_0")
        }

        // Tap on Favorites tab
        let favoritesTab = app.tabBars.buttons["Favorites"]
        if favoritesTab.waitForExistence(timeout: 3) {
            favoritesTab.tap()
            sleep(2)
            saveScreenshot(name: "4_favorites_APP_IPHONE_67_0")
        }

        // Tap on Profile tab
        let profileTab = app.tabBars.buttons["Profile"]
        if profileTab.waitForExistence(timeout: 3) {
            profileTab.tap()
            sleep(2)
            saveScreenshot(name: "5_profile_APP_IPHONE_67_0")
        }
    }

    private func saveScreenshot(name: String) {
        let screenshot = XCUIScreen.main.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
