//
//  IconExportTests.swift
//  BabyInCarAppTests
//
//  Test to export app icons to disk
//

import XCTest
@testable import BabyInCarApp

final class IconExportTests: XCTestCase {

    func testExportAppIcons() throws {
        // Generate all icon sizes
        let icons = AppIconGenerator.generateAllSizes()

        XCTAssertFalse(icons.isEmpty, "Should generate icons")

        // Get path to project's asset catalog
        let projectPath = "/Users/aabyzovext/Projects/AI bussines ideas/AnticryBabyApp/BabyInCarApp/BabyInCarApp/Assets.xcassets/AppIcon.appiconset"
        let iconFolder = URL(fileURLWithPath: projectPath)

        // Export each icon
        for (name, image) in icons {
            let filePath = iconFolder.appendingPathComponent("\(name).png")

            if let data = image.pngData() {
                do {
                    try data.write(to: filePath)
                    print("Exported: \(name).png to \(filePath.path)")
                } catch {
                    XCTFail("Failed to export \(name): \(error)")
                }
            }
        }

        // Update Contents.json
        let contentsJSON = IconExporter.generateContentsJSON()
        let contentsPath = iconFolder.appendingPathComponent("Contents.json")

        do {
            try contentsJSON.write(to: contentsPath, atomically: true, encoding: .utf8)
            print("Updated Contents.json")
        } catch {
            XCTFail("Failed to write Contents.json: \(error)")
        }

        // Verify the 1024x1024 icon was created
        let mainIconPath = iconFolder.appendingPathComponent("icon_1024.png")
        XCTAssertTrue(FileManager.default.fileExists(atPath: mainIconPath.path), "Main icon should exist")
    }
}
