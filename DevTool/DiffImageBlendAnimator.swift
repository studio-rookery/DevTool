//
//  DiffImageBlendAnimator.swift
//  DevTool
//
//  Created by masaki on 2024/10/09.
//

import SwiftUI
import AppKit
import ImageIO
import UniformTypeIdentifiers

struct AlphaAnimation {
    let alpha: Double
    let durationSeconds: TimeInterval
    
    static let animations = [
        AlphaAnimation(alpha: 0, durationSeconds: 0.4),
        AlphaAnimation(alpha: 1, durationSeconds: 1),
        AlphaAnimation(alpha: 1, durationSeconds: 0.4),
        AlphaAnimation(alpha: 0, durationSeconds: 1),
    ]
}
struct DiffImageBlendAnimator {
    let nsImageA: NSImage
    let nsImageB: NSImage
    let frameRate: Double = 0.1

    func createGifAnimation() -> Data? {
        let size = nsImageA.size // Use the size of the first image

        // Create APNG properties
        let fileProperties = [kCGImagePropertyPNGDictionary: [kCGImagePropertyAPNGLoopCount: 0]]
        let data = NSMutableData()

        let totalFrames = Int((AlphaAnimation.animations.reduce(0) { $0 + $1.durationSeconds } / frameRate).rounded(.up))
        guard let destination = CGImageDestinationCreateWithData(data, UTType.png.identifier as CFString, totalFrames, nil) else {
            return nil
        }
        CGImageDestinationSetProperties(destination, fileProperties as CFDictionary)

        func drawText(_ text: String, alpha: Double) {
            let fontSize: CGFloat = 64
            let attributes: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: fontSize, weight: .bold),
                .foregroundColor: NSColor.red.withAlphaComponent(CGFloat(alpha)),
                .strokeWidth : -1,
                .strokeColor : NSColor.white.withAlphaComponent(CGFloat(alpha))
            ]
            NSString(string: text).draw(at: NSPoint(x: 10, y: size.height - fontSize * 1.1), withAttributes: attributes)
        }
        
        // Generate frames based on AlphaAnimation struct
        var currentOpacity = 0.0
        for animation in AlphaAnimation.animations {
            let frameCount = Int(animation.durationSeconds / frameRate)
            let opacityChange = (animation.alpha - currentOpacity) / Double(frameCount)
            for _ in 0..<frameCount {
                currentOpacity += opacityChange

                let combinedImage = NSImage(size: size)
                combinedImage.lockFocus()
                nsImageA.draw(in: CGRect(origin: .zero, size: size), from: .zero, operation: .sourceOver, fraction: 1.0)
                drawText("Before", alpha: 1.0 - currentOpacity)
                nsImageB.draw(in: CGRect(origin: .zero, size: size), from: .zero, operation: .sourceOver, fraction: CGFloat(currentOpacity))
                drawText("After", alpha: currentOpacity)
                combinedImage.unlockFocus()

                guard let cgImage = combinedImage.cgImage else {
                    return nil
                }
                
                let frameProperties = [kCGImagePropertyPNGDictionary: [kCGImagePropertyAPNGDelayTime: frameRate / 8]]
                CGImageDestinationAddImage(destination, cgImage, frameProperties as CFDictionary)
            }
            currentOpacity = animation.alpha
        }

        // Finalize the APNG
        guard CGImageDestinationFinalize(destination) else {
            return nil
        }

        return data as Data
    }
}

// Extension to convert NSImage to CGImage
extension NSImage {
    var cgImage: CGImage? {
        var rect = CGRect(origin: .zero, size: size)
        return cgImage(forProposedRect: &rect, context: nil, hints: nil)
    }
}
