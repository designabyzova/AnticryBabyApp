import XCTest

final class ScreenshotTests: XCTestCase {

    let app = XCUIApplication()

    override func setUpWithError() throws {
        continueAfterFailure = false
        app.launch()
    }

    func testTakeAppStoreScreenshots() throws {
        // Wait for app to load
        sleep(2)

        // Screenshot 1: Home Screen
        let homeScreenshot = XCUIScreen.main.screenshot()
        let homeAttachment = XCTAttachment(screenshot: homeScreenshot)
        homeAttachment.name = "1_home_APP_IPHONE_67_0"
        homeAttachment.lifetime = .keepAlways
        add(homeAttachment)

        // Tap on Library tab
        let libraryTab = app.tabBars.buttons["Library"]
        if libraryTab.exists {
            libraryTab.tap()
            sleep(1)

            // Screenshot 2: Library Screen
            let libraryScreenshot = XCUIScreen.main.screenshot()
            let libraryAttachment = XCTAttachment(screenshot: libraryScreenshot)
            libraryAttachment.name = "2_library_APP_IPHONE_67_0"
            libraryAttachment.lifetime = .keepAlways
            add(libraryAttachment)
        }

        // Tap on Favorites tab
        let favoritesTab = app.tabBars.buttons["Favorites"]
        if favoritesTab.exists {
            favoritesTab.tap()
            sleep(1)

            // Screenshot 3: Favorites Screen
            let favoritesScreenshot = XCUIScreen.main.screenshot()
            let favoritesAttachment = XCTAttachment(screenshot: favoritesScreenshot)
            favoritesAttachment.name = "3_favorites_APP_IPHONE_67_0"
            favoritesAttachment.lifetime = .keepAlways
            add(favoritesAttachment)
        }

        // Tap on Profile tab
        let profileTab = app.tabBars.buttons["Profile"]
        if profileTab.exists {
            profileTab.tap()
            sleep(1)

            // Screenshot 4: Profile Screen
            let profileScreenshot = XCUIScreen.main.screenshot()
            let profileAttachment = XCTAttachment(screenshot: profileScreenshot)
            profileAttachment.name = "4_profile_APP_IPHONE_67_0"
            profileAttachment.lifetime = .keepAlways
            add(profileAttachment)
        }

        // Go back to Home to find a music category
        let homeTab = app.tabBars.buttons["Home"]
        if homeTab.exists {
            homeTab.tap()
            sleep(1)

            // Tap on a category to show content
            let classicalCategory = app.staticTexts["Classical..."]
            if classicalCategory.exists {
                classicalCategory.tap()
                sleep(1)

                // Screenshot 5: Category/Content Screen
                let categoryScreenshot = XCUIScreen.main.screenshot()
                let categoryAttachment = XCTAttachment(screenshot: categoryScreenshot)
                categoryAttachment.name = "5_category_APP_IPHONE_67_0"
                categoryAttachment.lifetime = .keepAlways
                add(categoryAttachment)
            }
        }
    }
}
