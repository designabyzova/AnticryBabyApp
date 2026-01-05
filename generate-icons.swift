#!/usr/bin/env swift

import Cocoa

// MARK: - Brand Colors
struct BrandColors {
    static let softLavender = NSColor(red: 180/255, green: 167/255, blue: 214/255, alpha: 1.0)
    static let dreamyBlue = NSColor(red: 137/255, green: 207/255, blue: 240/255, alpha: 1.0)
    static let warmCream = NSColor(red: 255/255, green: 248/255, blue: 231/255, alpha: 1.0)
    static let gentleMint = NSColor(red: 152/255, green: 215/255, blue: 194/255, alpha: 1.0)
    static let softCoral = NSColor(red: 255/255, green: 188/255, blue: 188/255, alpha: 1.0)
    static let deepLavender = NSColor(red: 147/255, green: 130/255, blue: 189/255, alpha: 1.0)
    static let midnightBlue = NSColor(red: 45/255, green: 55/255, blue: 72/255, alpha: 1.0)
}

// MARK: - Icon Generator
func generateIcon(size: CGFloat) -> NSImage {
    let image = NSImage(size: NSSize(width: size, height: size))

    image.lockFocus()

    let rect = NSRect(origin: .zero, size: NSSize(width: size, height: size))

    // 1. Background gradient
    let gradient = NSGradient(colors: [
        BrandColors.warmCream,
        BrandColors.softLavender,
        BrandColors.dreamyBlue.withAlphaComponent(0.7)
    ])
    gradient?.draw(in: rect, angle: -90)

    // 2. Draw stars
    let starPositions: [(x: CGFloat, y: CGFloat, s: CGFloat)] = [
        (0.15, 0.88, 0.04),
        (0.85, 0.85, 0.03),
        (0.75, 0.92, 0.025),
        (0.25, 0.80, 0.02),
        (0.90, 0.75, 0.02)
    ]

    NSColor.white.withAlphaComponent(0.8).setFill()
    for star in starPositions {
        let x = size * star.x
        let y = size * star.y
        let starSize = size * star.s
        drawStar(at: NSPoint(x: x, y: y), size: starSize)
    }

    // 3. Draw moon
    let moonSize = size * 0.15
    let moonColor = NSColor(red: 255/255, green: 250/255, blue: 220/255, alpha: 0.9)
    moonColor.setFill()
    let moonRect = NSRect(x: size * 0.75, y: size * 0.75, width: moonSize, height: moonSize)
    let moonPath = NSBezierPath(ovalIn: moonRect)
    moonPath.fill()

    // 4. Sound waves
    let centerX = size / 2
    let centerY = size / 2 - size * 0.05

    for (index, radius) in [0.45, 0.55, 0.65].enumerated() {
        let waveRadius = size * CGFloat(radius)
        let alpha: CGFloat = 0.3 - CGFloat(index) * 0.05

        BrandColors.softLavender.withAlphaComponent(alpha).setStroke()

        let wavePath = NSBezierPath()
        wavePath.lineWidth = size * 0.015
        wavePath.appendArc(
            withCenter: NSPoint(x: centerX, y: centerY),
            radius: waveRadius,
            startAngle: 50,
            endAngle: 130
        )
        wavePath.stroke()

        let wavePath2 = NSBezierPath()
        wavePath2.lineWidth = size * 0.015
        wavePath2.appendArc(
            withCenter: NSPoint(x: centerX, y: centerY),
            radius: waveRadius,
            startAngle: 230,
            endAngle: 310
        )
        wavePath2.stroke()
    }

    // 5. Baby face
    let faceRadius = size * 0.28
    let faceColor = NSColor(red: 255/255, green: 228/255, blue: 206/255, alpha: 1.0)

    // Shadow
    let shadow = NSShadow()
    shadow.shadowColor = BrandColors.deepLavender.withAlphaComponent(0.3)
    shadow.shadowOffset = NSSize(width: 0, height: -size * 0.02)
    shadow.shadowBlurRadius = size * 0.04
    shadow.set()

    faceColor.setFill()
    let faceRect = NSRect(
        x: centerX - faceRadius,
        y: centerY - faceRadius - size * 0.08,
        width: faceRadius * 2,
        height: faceRadius * 2
    )
    let facePath = NSBezierPath(ovalIn: faceRect)
    facePath.fill()

    // Remove shadow for remaining elements
    NSShadow().set()

    // Cheeks
    let cheekColor = BrandColors.softCoral.withAlphaComponent(0.5)
    cheekColor.setFill()
    let cheekRadius = faceRadius * 0.2
    let cheekY = centerY - size * 0.08 - faceRadius * 0.15

    let leftCheekRect = NSRect(
        x: centerX - faceRadius * 0.55 - cheekRadius,
        y: cheekY - cheekRadius,
        width: cheekRadius * 2,
        height: cheekRadius * 2
    )
    NSBezierPath(ovalIn: leftCheekRect).fill()

    let rightCheekRect = NSRect(
        x: centerX + faceRadius * 0.55 - cheekRadius,
        y: cheekY - cheekRadius,
        width: cheekRadius * 2,
        height: cheekRadius * 2
    )
    NSBezierPath(ovalIn: rightCheekRect).fill()

    // Eyes (curved lines for sleeping)
    let eyeY = centerY - size * 0.08 + faceRadius * 0.1
    let eyeWidth = faceRadius * 0.25
    let eyeColor = BrandColors.midnightBlue.withAlphaComponent(0.7)
    eyeColor.setStroke()

    // Left eye
    let leftEyePath = NSBezierPath()
    leftEyePath.lineWidth = size * 0.018
    leftEyePath.lineCapStyle = .round
    let leftEyeX = centerX - faceRadius * 0.35
    leftEyePath.move(to: NSPoint(x: leftEyeX - eyeWidth/2, y: eyeY))
    leftEyePath.curve(
        to: NSPoint(x: leftEyeX + eyeWidth/2, y: eyeY),
        controlPoint1: NSPoint(x: leftEyeX - eyeWidth/4, y: eyeY - faceRadius * 0.08),
        controlPoint2: NSPoint(x: leftEyeX + eyeWidth/4, y: eyeY - faceRadius * 0.08)
    )
    leftEyePath.stroke()

    // Right eye
    let rightEyePath = NSBezierPath()
    rightEyePath.lineWidth = size * 0.018
    rightEyePath.lineCapStyle = .round
    let rightEyeX = centerX + faceRadius * 0.35
    rightEyePath.move(to: NSPoint(x: rightEyeX - eyeWidth/2, y: eyeY))
    rightEyePath.curve(
        to: NSPoint(x: rightEyeX + eyeWidth/2, y: eyeY),
        controlPoint1: NSPoint(x: rightEyeX - eyeWidth/4, y: eyeY - faceRadius * 0.08),
        controlPoint2: NSPoint(x: rightEyeX + eyeWidth/4, y: eyeY - faceRadius * 0.08)
    )
    rightEyePath.stroke()

    // Smile
    let smilePath = NSBezierPath()
    smilePath.lineWidth = size * 0.015
    smilePath.lineCapStyle = .round
    BrandColors.softCoral.setStroke()
    let smileY = centerY - size * 0.08 - faceRadius * 0.35
    let smileWidth = faceRadius * 0.3
    smilePath.move(to: NSPoint(x: centerX - smileWidth/2, y: smileY))
    smilePath.curve(
        to: NSPoint(x: centerX + smileWidth/2, y: smileY),
        controlPoint1: NSPoint(x: centerX - smileWidth/4, y: smileY - faceRadius * 0.1),
        controlPoint2: NSPoint(x: centerX + smileWidth/4, y: smileY - faceRadius * 0.1)
    )
    smilePath.stroke()

    // Hair tuft
    let hairColor = NSColor(red: 139/255, green: 90/255, blue: 43/255, alpha: 0.8)
    hairColor.setFill()

    let hairBaseY = centerY - size * 0.08 + faceRadius * 0.85
    for i in -1...1 {
        let hairPath = NSBezierPath()
        let offsetX = CGFloat(i) * faceRadius * 0.15
        let baseWidth = faceRadius * 0.08

        hairPath.move(to: NSPoint(x: centerX + offsetX - baseWidth, y: hairBaseY - faceRadius * 0.3))
        hairPath.curve(
            to: NSPoint(x: centerX + offsetX, y: hairBaseY + faceRadius * 0.15),
            controlPoint1: NSPoint(x: centerX + offsetX - baseWidth * 0.5, y: hairBaseY),
            controlPoint2: NSPoint(x: centerX + offsetX - baseWidth * 0.2, y: hairBaseY + faceRadius * 0.1)
        )
        hairPath.curve(
            to: NSPoint(x: centerX + offsetX + baseWidth, y: hairBaseY - faceRadius * 0.3),
            controlPoint1: NSPoint(x: centerX + offsetX + baseWidth * 0.2, y: hairBaseY + faceRadius * 0.1),
            controlPoint2: NSPoint(x: centerX + offsetX + baseWidth * 0.5, y: hairBaseY)
        )
        hairPath.close()
        hairPath.fill()
    }

    // 6. Musical notes
    let noteColor = BrandColors.deepLavender.withAlphaComponent(0.6)
    let notePositions: [(x: CGFloat, y: CGFloat, rotation: CGFloat, scale: CGFloat)] = [
        (0.18, 0.45, -15, 0.8),
        (0.82, 0.50, 15, 0.9),
        (0.25, 0.25, -10, 0.7)
    ]

    for note in notePositions {
        drawMusicNote(
            at: NSPoint(x: size * note.x, y: size * note.y),
            size: size * 0.06 * note.scale,
            rotation: note.rotation,
            color: noteColor
        )
    }

    image.unlockFocus()
    return image
}

func drawStar(at center: NSPoint, size: CGFloat) {
    let path = NSBezierPath()
    let points = 5
    let innerRadius = size * 0.4
    let outerRadius = size

    for i in 0..<(points * 2) {
        let radius = i % 2 == 0 ? outerRadius : innerRadius
        let angle = CGFloat(i) * .pi / CGFloat(points) - .pi / 2
        let point = NSPoint(
            x: center.x + cos(angle) * radius,
            y: center.y + sin(angle) * radius
        )

        if i == 0 {
            path.move(to: point)
        } else {
            path.line(to: point)
        }
    }
    path.close()
    path.fill()
}

func drawMusicNote(at center: NSPoint, size: CGFloat, rotation: CGFloat, color: NSColor) {
    let transform = NSAffineTransform()
    transform.translateX(by: center.x, yBy: center.y)
    transform.rotate(byDegrees: rotation)
    transform.concat()

    color.setFill()
    color.setStroke()

    // Note head
    let headRect = NSRect(x: -size * 0.5, y: -size * 0.3 - size * 0.35, width: size, height: size * 0.7)
    NSBezierPath(ovalIn: headRect).fill()

    // Note stem
    let stemPath = NSBezierPath()
    stemPath.lineWidth = size * 0.15
    stemPath.move(to: NSPoint(x: size * 0.4, y: -size * 0.5 + size * 0.35))
    stemPath.line(to: NSPoint(x: size * 0.4, y: size * 0.8))
    stemPath.stroke()

    // Note flag
    let flagPath = NSBezierPath()
    flagPath.lineWidth = size * 0.12
    flagPath.lineCapStyle = .round
    flagPath.move(to: NSPoint(x: size * 0.4, y: size * 0.8))
    flagPath.curve(
        to: NSPoint(x: size * 0.8, y: size * 0.3),
        controlPoint1: NSPoint(x: size * 0.9, y: size * 0.7),
        controlPoint2: NSPoint(x: size * 0.9, y: size * 0.5)
    )
    flagPath.stroke()

    // Reset transform
    let resetTransform = NSAffineTransform()
    resetTransform.translateX(by: -center.x, yBy: -center.y)
    resetTransform.rotate(byDegrees: -rotation)
    resetTransform.concat()
}

// MARK: - Export Icons

let assetPath = "/Users/aabyzovext/Projects/AI bussines ideas/AnticryBabyApp/BabyInCarApp/BabyInCarApp/Assets.xcassets/AppIcon.appiconset"

// Fix: sizes are in POINTS, generate at actual PIXEL sizes
let sizes: [(name: String, points: CGFloat, pixels: CGFloat)] = [
    ("icon_1024", 1024, 1024),    // iOS/watchOS universal icon
    ("icon_512@2x", 512, 1024),   // mac 512@2x = 1024 pixels
    ("icon_512", 512, 512),       // mac 512@1x = 512 pixels
    ("icon_256@2x", 256, 512),    // mac 256@2x = 512 pixels
    ("icon_256", 256, 256),       // mac 256@1x = 256 pixels
    ("icon_128@2x", 128, 256),    // mac 128@2x = 256 pixels
    ("icon_128", 128, 128),       // mac 128@1x = 128 pixels
    ("icon_32@2x", 32, 64),       // mac 32@2x = 64 pixels
    ("icon_32", 32, 32),          // mac 32@1x = 32 pixels
    ("icon_16@2x", 16, 32),       // mac 16@2x = 32 pixels
    ("icon_16", 16, 16)           // mac 16@1x = 16 pixels
]

print("Generating app icons...")

for item in sizes {
    let icon = generateIcon(size: item.pixels)

    guard let tiffData = icon.tiffRepresentation,
          let bitmap = NSBitmapImageRep(data: tiffData),
          let pngData = bitmap.representation(using: .png, properties: [:]) else {
        print("Failed to generate \(item.name)")
        continue
    }

    let filePath = "\(assetPath)/\(item.name).png"
    do {
        try pngData.write(to: URL(fileURLWithPath: filePath))
        print("✓ Exported: \(item.name).png (\(Int(item.pixels))x\(Int(item.pixels)))")
    } catch {
        print("✗ Failed to export \(item.name): \(error)")
    }
}

// Update Contents.json
let contentsJSON = """
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

do {
    try contentsJSON.write(toFile: "\(assetPath)/Contents.json", atomically: true, encoding: .utf8)
    print("✓ Updated Contents.json")
} catch {
    print("✗ Failed to write Contents.json: \(error)")
}

print("\nApp icons generated successfully!")
