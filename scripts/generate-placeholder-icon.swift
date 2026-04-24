#!/usr/bin/env swift
// Soothbee placeholder app icon generator
// Renders a 1024x1024 PNG: honey radial gradient + hexagon outline + minimal bee silhouette.
// Output: BabyInCarApp/Assets.xcassets/AppIcon.appiconset/icon_1024.png + BabyInCarWatchApp/... + macOS sizes.
//
// Usage: swift scripts/generate-placeholder-icon.swift
// Requires: macOS with CoreGraphics/ImageIO. No external deps.

import AppKit
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers

// MARK: - Palette (hex from Honeycomb Dusk)
let honeyGold = CGColor(red: 0.910, green: 0.659, blue: 0.220, alpha: 1.0)     // #E8A838
let lightHoney = CGColor(red: 0.961, green: 0.851, blue: 0.522, alpha: 1.0)    // #F5D985
let honeyDeep = CGColor(red: 0.478, green: 0.306, blue: 0.078, alpha: 1.0)     // #7A4E14
let hiveCharcoal = CGColor(red: 0.169, green: 0.141, blue: 0.098, alpha: 1.0)  // #2B2419

// MARK: - Render
func renderIcon(size: CGFloat) -> CGImage? {
    let colorSpace = CGColorSpace(name: CGColorSpace.sRGB)!
    guard let ctx = CGContext(
        data: nil,
        width: Int(size),
        height: Int(size),
        bitsPerComponent: 8,
        bytesPerRow: 0,
        space: colorSpace,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    ) else { return nil }

    // 1. Background: honey radial gradient (light center → deeper edges)
    let gradientColors = [lightHoney, honeyGold] as CFArray
    let gradient = CGGradient(
        colorsSpace: colorSpace,
        colors: gradientColors,
        locations: [0.0, 1.0]
    )!
    let center = CGPoint(x: size / 2, y: size / 2)
    ctx.drawRadialGradient(
        gradient,
        startCenter: center, startRadius: 0,
        endCenter: center, endRadius: size * 0.7,
        options: []
    )

    // 2. Outer hexagon (honeycomb cell) — stroked in honeyDeep
    let hexRadius = size * 0.34
    let hexPath = CGMutablePath()
    for i in 0..<6 {
        // Pointy-top hexagon (rotated 30° from flat-top)
        let angle = CGFloat(i) * (.pi / 3) - .pi / 2
        let x = center.x + hexRadius * cos(angle)
        let y = center.y + hexRadius * sin(angle)
        if i == 0 { hexPath.move(to: CGPoint(x: x, y: y)) }
        else { hexPath.addLine(to: CGPoint(x: x, y: y)) }
    }
    hexPath.closeSubpath()
    ctx.setStrokeColor(honeyDeep)
    ctx.setLineWidth(size * 0.02)
    ctx.addPath(hexPath)
    ctx.strokePath()

    // 3. Bee body: rounded-rect oval, honey gold with two hiveCharcoal stripes
    let bodyWidth = size * 0.36
    let bodyHeight = size * 0.26
    let bodyRect = CGRect(
        x: center.x - bodyWidth / 2,
        y: center.y - bodyHeight / 2,
        width: bodyWidth,
        height: bodyHeight
    )
    ctx.saveGState()
    // Body fill — slightly lighter honey to stand out from bg
    let bodyPath = CGPath(roundedRect: bodyRect, cornerWidth: bodyHeight / 2, cornerHeight: bodyHeight / 2, transform: nil)
    ctx.addPath(bodyPath)
    ctx.setFillColor(lightHoney)
    ctx.fillPath()

    // Stripes — clipped to body shape
    ctx.addPath(bodyPath)
    ctx.clip()
    ctx.setFillColor(hiveCharcoal)
    let stripeWidth = bodyWidth * 0.14
    // Two stripes centered-ish
    for offset: CGFloat in [-0.18, 0.18] {
        let stripeX = center.x + bodyWidth * offset - stripeWidth / 2
        let stripe = CGRect(x: stripeX, y: bodyRect.minY, width: stripeWidth, height: bodyHeight)
        ctx.fill(stripe)
    }
    ctx.restoreGState()

    // 4. Wing — soft ellipse on upper-right, translucent white
    let wingWidth = bodyWidth * 0.55
    let wingHeight = bodyHeight * 0.75
    let wingRect = CGRect(
        x: center.x - wingWidth * 0.25,
        y: center.y + bodyHeight * 0.15,
        width: wingWidth,
        height: wingHeight
    )
    ctx.saveGState()
    ctx.setFillColor(CGColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 0.55))
    ctx.setStrokeColor(honeyDeep)
    ctx.setLineWidth(size * 0.006)
    ctx.addEllipse(in: wingRect)
    ctx.drawPath(using: .fillStroke)
    ctx.restoreGState()

    // 5. Eye dot (left side) — tiny charcoal circle
    let eyeRadius = size * 0.012
    let eyeCenter = CGPoint(x: center.x - bodyWidth * 0.36, y: center.y + bodyHeight * 0.12)
    ctx.setFillColor(hiveCharcoal)
    ctx.addEllipse(in: CGRect(
        x: eyeCenter.x - eyeRadius,
        y: eyeCenter.y - eyeRadius,
        width: eyeRadius * 2,
        height: eyeRadius * 2
    ))
    ctx.fillPath()

    return ctx.makeImage()
}

func writePNG(_ image: CGImage, to url: URL) throws {
    guard let dest = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil) else {
        throw NSError(domain: "icon-gen", code: 1)
    }
    CGImageDestinationAddImage(dest, image, nil)
    if !CGImageDestinationFinalize(dest) {
        throw NSError(domain: "icon-gen", code: 2)
    }
}

func resize(_ image: CGImage, to size: Int) -> CGImage? {
    let colorSpace = CGColorSpace(name: CGColorSpace.sRGB)!
    guard let ctx = CGContext(
        data: nil,
        width: size,
        height: size,
        bitsPerComponent: 8,
        bytesPerRow: 0,
        space: colorSpace,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    ) else { return nil }
    ctx.interpolationQuality = .high
    ctx.draw(image, in: CGRect(x: 0, y: 0, width: size, height: size))
    return ctx.makeImage()
}

// MARK: - Main
let fm = FileManager.default
let scriptDir = URL(fileURLWithPath: CommandLine.arguments[0]).deletingLastPathComponent()
let repoRoot = scriptDir.deletingLastPathComponent()
let mainIconSet = repoRoot
    .appendingPathComponent("BabyInCarApp")
    .appendingPathComponent("BabyInCarApp")
    .appendingPathComponent("Assets.xcassets")
    .appendingPathComponent("AppIcon.appiconset")
let watchIconSet = repoRoot
    .appendingPathComponent("BabyInCarApp")
    .appendingPathComponent("BabyInCarWatchApp")
    .appendingPathComponent("Assets.xcassets")
    .appendingPathComponent("AppIcon.appiconset")

guard fm.fileExists(atPath: mainIconSet.path) else {
    print("error: main iconset not found at \(mainIconSet.path)")
    exit(1)
}

print("generating 1024x1024 base icon...")
guard let baseIcon = renderIcon(size: 1024) else {
    print("error: render failed")
    exit(1)
}

// iOS + Watch: single 1024x1024
let iosPath = mainIconSet.appendingPathComponent("icon_1024.png")
try writePNG(baseIcon, to: iosPath)
print("wrote \(iosPath.path)")

if fm.fileExists(atPath: watchIconSet.path) {
    let watchPath = watchIconSet.appendingPathComponent("icon_1024.png")
    try writePNG(baseIcon, to: watchPath)
    print("wrote \(watchPath.path)")
}

// macOS sizes (from Contents.json)
let macSizes: [(name: String, size: Int)] = [
    ("icon_16.png", 16),
    ("icon_16@2x.png", 32),
    ("icon_32.png", 32),
    ("icon_32@2x.png", 64),
    ("icon_128.png", 128),
    ("icon_128@2x.png", 256),
    ("icon_256.png", 256),
    ("icon_256@2x.png", 512),
    ("icon_512.png", 512),
    ("icon_512@2x.png", 1024),
]
for (name, px) in macSizes {
    guard let resized = resize(baseIcon, to: px) else { continue }
    let path = mainIconSet.appendingPathComponent(name)
    try writePNG(resized, to: path)
    print("wrote \(path.path) (\(px)x\(px))")
}

print("done.")
