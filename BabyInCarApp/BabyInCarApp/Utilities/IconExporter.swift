//
//  IconExporter.swift
//  BabyInCarApp
//
//  Utility to export generated app icons to files
//

import UIKit

/// Exports app icons to the asset catalog
class IconExporter {

    /// Export all icon sizes to the asset catalog location
    /// Call this from a test or script to generate icons
    static func exportToAssetCatalog() {
        let icons = AppIconGenerator.generateAllSizes()

        // Get documents directory for output (in real usage, copy to Xcode assets)
        guard let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            print("Could not find documents directory")
            return
        }

        let iconFolder = documentsPath.appendingPathComponent("GeneratedIcons")

        // Create folder if needed
        try? FileManager.default.createDirectory(at: iconFolder, withIntermediateDirectories: true)

        for (name, image) in icons {
            let filePath = iconFolder.appendingPathComponent("\(name).png")

            if let data = image.pngData() {
                do {
                    try data.write(to: filePath)
                    print("Exported: \(name).png")
                } catch {
                    print("Failed to export \(name): \(error)")
                }
            }
        }

        print("\nIcons exported to: \(iconFolder.path)")
        print("\nTo use these icons:")
        print("1. Copy the generated PNG files to Assets.xcassets/AppIcon.appiconset/")
        print("2. Update Contents.json to reference the files")
    }

    /// Generate Contents.json for the asset catalog
    static func generateContentsJSON() -> String {
        return """
{
  "images" : [
    {
      "filename" : "icon_1024.png",
      "idiom" : "universal",
      "platform" : "ios",
      "size" : "1024x1024"
    },
    {
      "filename" : "icon_1024.png",
      "idiom" : "universal",
      "platform" : "watchos",
      "size" : "1024x1024"
    },
    {
      "filename" : "icon_16.png",
      "idiom" : "mac",
      "scale" : "1x",
      "size" : "16x16"
    },
    {
      "filename" : "icon_16@2x.png",
      "idiom" : "mac",
      "scale" : "2x",
      "size" : "16x16"
    },
    {
      "filename" : "icon_32.png",
      "idiom" : "mac",
      "scale" : "1x",
      "size" : "32x32"
    },
    {
      "filename" : "icon_32@2x.png",
      "idiom" : "mac",
      "scale" : "2x",
      "size" : "32x32"
    },
    {
      "filename" : "icon_128.png",
      "idiom" : "mac",
      "scale" : "1x",
      "size" : "128x128"
    },
    {
      "filename" : "icon_128@2x.png",
      "idiom" : "mac",
      "scale" : "2x",
      "size" : "128x128"
    },
    {
      "filename" : "icon_256.png",
      "idiom" : "mac",
      "scale" : "1x",
      "size" : "256x256"
    },
    {
      "filename" : "icon_256@2x.png",
      "idiom" : "mac",
      "scale" : "2x",
      "size" : "256x256"
    },
    {
      "filename" : "icon_512.png",
      "idiom" : "mac",
      "scale" : "1x",
      "size" : "512x512"
    },
    {
      "filename" : "icon_512@2x.png",
      "idiom" : "mac",
      "scale" : "2x",
      "size" : "512x512"
    }
  ],
  "info" : {
    "author" : "xcode",
    "version" : 1
  }
}
"""
    }
}
