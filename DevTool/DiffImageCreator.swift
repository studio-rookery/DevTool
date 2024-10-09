//
//  DiffImageCreator.swift
//  DevTool
//
//  Created by masaki on 2024/10/09.
//

import Cocoa
import SwiftUI
import AppKit
import CoreImage
import CoreImage.CIFilterBuiltins

// 差分画像を生成するクラス
struct DiffImageCreator {
    
    func generateHighlightedDifferenceWithOriginal(image1: NSImage, image2: NSImage) -> NSImage? {
        guard let ciImage1 = CIImage(data: image1.tiffRepresentation!),
              let ciImage2 = CIImage(data: image2.tiffRepresentation!) else {
            return nil
        }

        // 差分フィルターを使用して、差分画像を作成
        let differenceFilter = CIFilter.differenceBlendMode()
        differenceFilter.inputImage = ciImage1
        differenceFilter.backgroundImage = ciImage2

        guard let diffImage = differenceFilter.outputImage else {
            return nil
        }

        // 差分画像を白黒化（マスク作成用）
        let monochromeFilter = CIFilter.colorControls()
        monochromeFilter.inputImage = diffImage
        monochromeFilter.saturation = 0.0
        monochromeFilter.brightness = 0.0
        monochromeFilter.contrast = 1.0

        guard let maskImage = monochromeFilter.outputImage else {
            return nil
        }

        // ハイライト用のピンク色画像を作成
        let falseColorFilter = CIFilter.falseColor()
        falseColorFilter.inputImage = diffImage
        falseColorFilter.color0 = CIColor(red: 1, green: 0, blue: 1, alpha: 1)  // ピンク色
        falseColorFilter.color1 = CIColor(red: 0, green: 0, blue: 0, alpha: 0)  // 透明

        guard let highlightImage = falseColorFilter.outputImage else {
            return nil
        }

        // 差分箇所のみをピンク色にハイライトした画像を合成
        let blendFilter = CIFilter.blendWithMask()
        blendFilter.inputImage = highlightImage      // ピンクのハイライト画像
        blendFilter.backgroundImage = ciImage1       // 元の画像1
        blendFilter.maskImage = maskImage            // 差分マスク画像

        guard let outputCIImage = blendFilter.outputImage else {
            return nil
        }

        // CIImageをNSImageに変換
        let rep = NSCIImageRep(ciImage: outputCIImage)
        let nsImage = NSImage(size: rep.size)
        nsImage.addRepresentation(rep)

        return nsImage
    }


    // 2つの SwiftUI Image から NSImage の差分を生成
    func createDifferenceImage(from swiftUIImage1: Image, and swiftUIImage2: Image) -> Image? {
        guard let nsImage1 = swiftUIImage1.toNSImage(),
              let nsImage2 = swiftUIImage2.toNSImage(),
              let image = generateHighlightedDifferenceWithOriginal(image1: nsImage1, image2: nsImage2)
        else {
            print("SwiftUIのImageをNSImageに変換できません。")
            return nil
        }
        return Image(nsImage: image)
    }
}

extension Image {
    
    func toNSImage() -> NSImage? {
        let view = NSHostingView(rootView: self)
        let size = view.fittingSize
        view.setFrameSize(size)
        let bitmapRep = view.bitmapImageRepForCachingDisplay(in: view.bounds)!
        view.cacheDisplay(in: view.bounds, to: bitmapRep)
        let nsImage = NSImage(size: size)
        nsImage.addRepresentation(bitmapRep)
        return nsImage
    }
}
