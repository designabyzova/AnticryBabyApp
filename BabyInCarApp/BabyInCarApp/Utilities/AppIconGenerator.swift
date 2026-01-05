//
//  AppIconGenerator.swift
//  BabyInCarApp
//
//  Programmatic app icon generation with Core Graphics
//  Creates a beautiful sleeping baby icon with sound waves
//

import UIKit
import SwiftUI

/// Generates app icons programmatically for all required sizes
class AppIconGenerator {

    // MARK: - Brand Colors
    struct BrandColors {
        // Primary palette - soft, calming
        static let softLavender = UIColor(red: 180/255, green: 167/255, blue: 214/255, alpha: 1.0)    // #B4A7D6
        static let dreamyBlue = UIColor(red: 137/255, green: 207/255, blue: 240/255, alpha: 1.0)      // #89CFF0
        static let warmCream = UIColor(red: 255/255, green: 248/255, blue: 231/255, alpha: 1.0)       // #FFF8E7

        // Accent colors
        static let gentleMint = UIColor(red: 152/255, green: 215/255, blue: 194/255, alpha: 1.0)      // #98D7C2
        static let softCoral = UIColor(red: 255/255, green: 188/255, blue: 188/255, alpha: 1.0)       // #FFBCBC
        static let blushPink = UIColor(red: 255/255, green: 218/255, blue: 233/255, alpha: 1.0)       // #FFDAE9

        // Dark accents
        static let deepLavender = UIColor(red: 147/255, green: 130/255, blue: 189/255, alpha: 1.0)    // #9382BD
        static let midnightBlue = UIColor(red: 45/255, green: 55/255, blue: 72/255, alpha: 1.0)       // #2D3748
    }

    // MARK: - Generate Icon

    /// Generate app icon image at specified size
    /// - Parameter size: Size in points
    /// - Returns: UIImage of the app icon
    static func generateIcon(size: CGFloat) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: size, height: size))

        return renderer.image { context in
            let rect = CGRect(origin: .zero, size: CGSize(width: size, height: size))
            let cgContext = context.cgContext

            // 1. Background gradient
            drawBackground(in: rect, context: cgContext)

            // 2. Decorative elements (stars, moon)
            drawDecorations(in: rect, context: cgContext, size: size)

            // 3. Sound waves (behind baby)
            drawSoundWaves(in: rect, context: cgContext, size: size)

            // 4. Sleeping baby face
            drawBabyFace(in: rect, context: cgContext, size: size)

            // 5. Musical notes
            drawMusicalNotes(in: rect, context: cgContext, size: size)

            // 6. Subtle overlay for polish
            drawOverlay(in: rect, context: cgContext)
        }
    }

    // MARK: - Background

    private static func drawBackground(in rect: CGRect, context: CGContext) {
        let colors = [
            BrandColors.warmCream.cgColor,
            BrandColors.softLavender.cgColor,
            BrandColors.dreamyBlue.withAlphaComponent(0.7).cgColor
        ]
        let locations: [CGFloat] = [0.0, 0.5, 1.0]

        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let gradient = CGGradient(colorsSpace: colorSpace, colors: colors as CFArray, locations: locations) else { return }

        context.drawLinearGradient(
            gradient,
            start: CGPoint(x: rect.midX, y: 0),
            end: CGPoint(x: rect.midX, y: rect.height),
            options: []
        )
    }

    // MARK: - Decorations (Stars, Moon)

    private static func drawDecorations(in rect: CGRect, context: CGContext, size: CGFloat) {
        let starColor = UIColor.white.withAlphaComponent(0.8)

        // Draw small stars
        let starPositions: [(x: CGFloat, y: CGFloat, size: CGFloat)] = [
            (0.15, 0.12, 0.04),
            (0.85, 0.15, 0.03),
            (0.75, 0.08, 0.025),
            (0.25, 0.20, 0.02),
            (0.90, 0.25, 0.02),
            (0.10, 0.30, 0.015)
        ]

        for star in starPositions {
            let x = rect.width * star.x
            let y = rect.height * star.y
            let starSize = rect.width * star.size

            drawStar(at: CGPoint(x: x, y: y), size: starSize, color: starColor, context: context)
        }

        // Draw crescent moon
        let moonSize = size * 0.15
        let moonX = size * 0.82
        let moonY = size * 0.18
        drawMoon(at: CGPoint(x: moonX, y: moonY), size: moonSize, context: context)
    }

    private static func drawStar(at center: CGPoint, size: CGFloat, color: UIColor, context: CGContext) {
        context.saveGState()

        let path = UIBezierPath()
        let points = 5
        let innerRadius = size * 0.4
        let outerRadius = size

        for i in 0..<(points * 2) {
            let radius = i % 2 == 0 ? outerRadius : innerRadius
            let angle = CGFloat(i) * .pi / CGFloat(points) - .pi / 2
            let point = CGPoint(
                x: center.x + cos(angle) * radius,
                y: center.y + sin(angle) * radius
            )

            if i == 0 {
                path.move(to: point)
            } else {
                path.addLine(to: point)
            }
        }
        path.close()

        context.setFillColor(color.cgColor)
        context.addPath(path.cgPath)
        context.fillPath()

        context.restoreGState()
    }

    private static func drawMoon(at center: CGPoint, size: CGFloat, context: CGContext) {
        context.saveGState()

        let moonColor = UIColor(red: 255/255, green: 250/255, blue: 220/255, alpha: 0.9)

        // Full circle
        let fullMoonPath = UIBezierPath(ovalIn: CGRect(
            x: center.x - size/2,
            y: center.y - size/2,
            width: size,
            height: size
        ))

        // Cutout circle (offset for crescent effect)
        let cutoutPath = UIBezierPath(ovalIn: CGRect(
            x: center.x - size/2 + size * 0.3,
            y: center.y - size/2 - size * 0.1,
            width: size * 0.9,
            height: size * 0.9
        ))

        context.setFillColor(moonColor.cgColor)
        context.addPath(fullMoonPath.cgPath)
        context.fillPath()

        // Cut out to create crescent
        context.setBlendMode(.destinationOut)
        context.addPath(cutoutPath.cgPath)
        context.fillPath()
        context.setBlendMode(.normal)

        context.restoreGState()
    }

    // MARK: - Sound Waves

    private static func drawSoundWaves(in rect: CGRect, context: CGContext, size: CGFloat) {
        context.saveGState()

        let centerX = rect.midX
        let centerY = rect.midY + size * 0.05

        let waveColors = [
            BrandColors.softLavender.withAlphaComponent(0.3),
            BrandColors.dreamyBlue.withAlphaComponent(0.25),
            BrandColors.gentleMint.withAlphaComponent(0.2)
        ]

        let waveRadii: [CGFloat] = [0.45, 0.55, 0.65]

        for (index, radius) in waveRadii.enumerated() {
            let waveRadius = size * radius
            let strokeWidth = size * 0.015

            let path = UIBezierPath(arcCenter: CGPoint(x: centerX, y: centerY),
                                    radius: waveRadius,
                                    startAngle: -.pi * 0.7,
                                    endAngle: -.pi * 0.3,
                                    clockwise: false)

            context.setStrokeColor(waveColors[index].cgColor)
            context.setLineWidth(strokeWidth)
            context.setLineCap(.round)
            context.addPath(path.cgPath)
            context.strokePath()

            // Mirror on the other side
            let mirrorPath = UIBezierPath(arcCenter: CGPoint(x: centerX, y: centerY),
                                          radius: waveRadius,
                                          startAngle: -.pi * 0.7 + .pi,
                                          endAngle: -.pi * 0.3 + .pi,
                                          clockwise: false)

            context.addPath(mirrorPath.cgPath)
            context.strokePath()
        }

        context.restoreGState()
    }

    // MARK: - Baby Face

    private static func drawBabyFace(in rect: CGRect, context: CGContext, size: CGFloat) {
        context.saveGState()

        let centerX = rect.midX
        let centerY = rect.midY + size * 0.08
        let faceRadius = size * 0.28

        // Face base - soft peach/cream color
        let faceColor = UIColor(red: 255/255, green: 228/255, blue: 206/255, alpha: 1.0)
        let faceRect = CGRect(
            x: centerX - faceRadius,
            y: centerY - faceRadius,
            width: faceRadius * 2,
            height: faceRadius * 2
        )

        // Draw face shadow first
        context.saveGState()
        context.setShadow(offset: CGSize(width: 0, height: size * 0.02), blur: size * 0.04, color: BrandColors.deepLavender.withAlphaComponent(0.3).cgColor)
        context.setFillColor(faceColor.cgColor)
        context.fillEllipse(in: faceRect)
        context.restoreGState()

        // Face fill (again, without shadow)
        context.setFillColor(faceColor.cgColor)
        context.fillEllipse(in: faceRect)

        // Rosy cheeks
        let cheekColor = BrandColors.softCoral.withAlphaComponent(0.5)
        let cheekRadius = faceRadius * 0.2
        let cheekY = centerY + faceRadius * 0.15

        // Left cheek
        let leftCheekRect = CGRect(
            x: centerX - faceRadius * 0.55 - cheekRadius,
            y: cheekY - cheekRadius,
            width: cheekRadius * 2,
            height: cheekRadius * 2
        )
        context.setFillColor(cheekColor.cgColor)
        context.fillEllipse(in: leftCheekRect)

        // Right cheek
        let rightCheekRect = CGRect(
            x: centerX + faceRadius * 0.55 - cheekRadius,
            y: cheekY - cheekRadius,
            width: cheekRadius * 2,
            height: cheekRadius * 2
        )
        context.fillEllipse(in: rightCheekRect)

        // Closed eyes (curved lines)
        let eyeY = centerY - faceRadius * 0.1
        let eyeWidth = faceRadius * 0.25
        let eyeHeight = faceRadius * 0.08
        let eyeColor = BrandColors.midnightBlue.withAlphaComponent(0.7)

        // Left eye
        let leftEyePath = UIBezierPath()
        let leftEyeX = centerX - faceRadius * 0.35
        leftEyePath.move(to: CGPoint(x: leftEyeX - eyeWidth/2, y: eyeY))
        leftEyePath.addQuadCurve(
            to: CGPoint(x: leftEyeX + eyeWidth/2, y: eyeY),
            controlPoint: CGPoint(x: leftEyeX, y: eyeY + eyeHeight)
        )

        context.setStrokeColor(eyeColor.cgColor)
        context.setLineWidth(size * 0.018)
        context.setLineCap(.round)
        context.addPath(leftEyePath.cgPath)
        context.strokePath()

        // Right eye
        let rightEyePath = UIBezierPath()
        let rightEyeX = centerX + faceRadius * 0.35
        rightEyePath.move(to: CGPoint(x: rightEyeX - eyeWidth/2, y: eyeY))
        rightEyePath.addQuadCurve(
            to: CGPoint(x: rightEyeX + eyeWidth/2, y: eyeY),
            controlPoint: CGPoint(x: rightEyeX, y: eyeY + eyeHeight)
        )

        context.addPath(rightEyePath.cgPath)
        context.strokePath()

        // Tiny eyelashes
        drawEyelashes(at: CGPoint(x: leftEyeX, y: eyeY - eyeHeight * 0.3), width: eyeWidth, context: context, size: size)
        drawEyelashes(at: CGPoint(x: rightEyeX, y: eyeY - eyeHeight * 0.3), width: eyeWidth, context: context, size: size)

        // Small peaceful smile
        let smilePath = UIBezierPath()
        let smileY = centerY + faceRadius * 0.35
        let smileWidth = faceRadius * 0.3

        smilePath.move(to: CGPoint(x: centerX - smileWidth/2, y: smileY))
        smilePath.addQuadCurve(
            to: CGPoint(x: centerX + smileWidth/2, y: smileY),
            controlPoint: CGPoint(x: centerX, y: smileY + faceRadius * 0.1)
        )

        context.setStrokeColor(BrandColors.softCoral.cgColor)
        context.setLineWidth(size * 0.015)
        context.addPath(smilePath.cgPath)
        context.strokePath()

        // Hair tuft
        drawHairTuft(at: CGPoint(x: centerX, y: centerY - faceRadius * 0.85), faceRadius: faceRadius, context: context, size: size)

        context.restoreGState()
    }

    private static func drawEyelashes(at center: CGPoint, width: CGFloat, context: CGContext, size: CGFloat) {
        let lashColor = BrandColors.midnightBlue.withAlphaComponent(0.3)
        context.setStrokeColor(lashColor.cgColor)
        context.setLineWidth(size * 0.008)

        let lashPositions: [CGFloat] = [-0.3, 0, 0.3]
        let lashHeight = size * 0.015

        for pos in lashPositions {
            let x = center.x + width * pos
            context.move(to: CGPoint(x: x, y: center.y))
            context.addLine(to: CGPoint(x: x, y: center.y - lashHeight))
            context.strokePath()
        }
    }

    private static func drawHairTuft(at center: CGPoint, faceRadius: CGFloat, context: CGContext, size: CGFloat) {
        let hairColor = UIColor(red: 139/255, green: 90/255, blue: 43/255, alpha: 0.8)
        context.setFillColor(hairColor.cgColor)

        // Draw 3 curved hair strands
        for i in -1...1 {
            let path = UIBezierPath()
            let offsetX = CGFloat(i) * faceRadius * 0.15
            let baseWidth = faceRadius * 0.08

            path.move(to: CGPoint(x: center.x + offsetX - baseWidth, y: center.y + faceRadius * 0.3))
            path.addQuadCurve(
                to: CGPoint(x: center.x + offsetX, y: center.y - faceRadius * 0.15),
                controlPoint: CGPoint(x: center.x + offsetX - baseWidth * 0.5, y: center.y)
            )
            path.addQuadCurve(
                to: CGPoint(x: center.x + offsetX + baseWidth, y: center.y + faceRadius * 0.3),
                controlPoint: CGPoint(x: center.x + offsetX + baseWidth * 0.5, y: center.y)
            )
            path.close()

            context.addPath(path.cgPath)
            context.fillPath()
        }
    }

    // MARK: - Musical Notes

    private static func drawMusicalNotes(in rect: CGRect, context: CGContext, size: CGFloat) {
        context.saveGState()

        let noteColor = BrandColors.deepLavender.withAlphaComponent(0.6)

        // Position notes around the baby face
        let notePositions: [(x: CGFloat, y: CGFloat, rotation: CGFloat, scale: CGFloat)] = [
            (0.18, 0.55, -15, 0.8),
            (0.82, 0.50, 15, 0.9),
            (0.25, 0.75, -10, 0.7)
        ]

        for note in notePositions {
            let x = rect.width * note.x
            let y = rect.height * note.y
            let noteSize = size * 0.06 * note.scale

            drawMusicNote(at: CGPoint(x: x, y: y), size: noteSize, rotation: note.rotation, color: noteColor, context: context)
        }

        context.restoreGState()
    }

    private static func drawMusicNote(at center: CGPoint, size: CGFloat, rotation: CGFloat, color: UIColor, context: CGContext) {
        context.saveGState()

        // Translate and rotate
        context.translateBy(x: center.x, y: center.y)
        context.rotate(by: rotation * .pi / 180)

        context.setFillColor(color.cgColor)
        context.setStrokeColor(color.cgColor)
        context.setLineWidth(size * 0.15)

        // Note head (oval)
        let headRect = CGRect(x: -size * 0.5, y: size * 0.3, width: size, height: size * 0.7)
        context.fillEllipse(in: headRect)

        // Note stem
        context.move(to: CGPoint(x: size * 0.4, y: size * 0.5))
        context.addLine(to: CGPoint(x: size * 0.4, y: -size * 0.8))
        context.strokePath()

        // Note flag
        let flagPath = UIBezierPath()
        flagPath.move(to: CGPoint(x: size * 0.4, y: -size * 0.8))
        flagPath.addQuadCurve(
            to: CGPoint(x: size * 0.8, y: -size * 0.3),
            controlPoint: CGPoint(x: size * 0.9, y: -size * 0.7)
        )

        context.setLineWidth(size * 0.12)
        context.setLineCap(.round)
        context.addPath(flagPath.cgPath)
        context.strokePath()

        context.restoreGState()
    }

    // MARK: - Overlay

    private static func drawOverlay(in rect: CGRect, context: CGContext) {
        // Subtle vignette effect
        let colors = [
            UIColor.clear.cgColor,
            UIColor.black.withAlphaComponent(0.05).cgColor
        ]
        let locations: [CGFloat] = [0.6, 1.0]

        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let gradient = CGGradient(colorsSpace: colorSpace, colors: colors as CFArray, locations: locations) else { return }

        context.drawRadialGradient(
            gradient,
            startCenter: CGPoint(x: rect.midX, y: rect.midY),
            startRadius: 0,
            endCenter: CGPoint(x: rect.midX, y: rect.midY),
            endRadius: rect.width * 0.7,
            options: []
        )
    }

    // MARK: - Export All Sizes

    /// Generate and save all required icon sizes to the asset catalog
    static func generateAllSizes() -> [String: UIImage] {
        let sizes: [(name: String, size: CGFloat)] = [
            ("icon_1024", 1024),
            ("icon_512@2x", 1024),
            ("icon_512", 512),
            ("icon_256@2x", 512),
            ("icon_256", 256),
            ("icon_128@2x", 256),
            ("icon_128", 128),
            ("icon_32@2x", 64),
            ("icon_32", 32),
            ("icon_16@2x", 32),
            ("icon_16", 16)
        ]

        var icons: [String: UIImage] = [:]

        for item in sizes {
            icons[item.name] = generateIcon(size: item.size)
        }

        return icons
    }
}

// MARK: - SwiftUI Preview

struct AppIconPreview: View {
    var body: some View {
        VStack(spacing: 20) {
            Text("App Icon Preview")
                .font(.headline)

            // Large preview
            if let icon = UIImage(named: "AppIcon") ?? generatePreviewIcon() {
                Image(uiImage: icon)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 200, height: 200)
                    .clipShape(RoundedRectangle(cornerRadius: 40))
                    .shadow(radius: 10)
            }

            // Size variations
            HStack(spacing: 16) {
                ForEach([60, 40, 29, 20] as [CGFloat], id: \.self) { size in
                    if let icon = generatePreviewIcon(size: size * 3) {
                        Image(uiImage: icon)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: size, height: size)
                            .clipShape(RoundedRectangle(cornerRadius: size * 0.2))
                    }
                }
            }
        }
        .padding()
    }

    private func generatePreviewIcon(size: CGFloat = 512) -> UIImage? {
        return AppIconGenerator.generateIcon(size: size)
    }
}

#Preview {
    AppIconPreview()
}
