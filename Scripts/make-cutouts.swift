#!/usr/bin/env swift
// Cuts the food out of photos, the same way the app does, and writes the biggest
// cutout of each into fastlane/screenshots/source/ for the store screenshots.
//
//   swift Scripts/make-cutouts.swift ~/Downloads/*.jpeg
//
// The app runs this on device because Vision's foreground mask needs a real
// device; on macOS it runs fine, which is why the store art can be made here.
import AppKit
import CoreImage
import Foundation
import ImageIO
import Vision

let arguments = Array(CommandLine.arguments.dropFirst())
guard !arguments.isEmpty else {
    print("usage: swift Scripts/make-cutouts.swift <photo> [photo …]")
    exit(1)
}

let repositoryRoot = URL(fileURLWithPath: #filePath)
    .deletingLastPathComponent()
    .deletingLastPathComponent()
let outputFolder = repositoryRoot
    .appendingPathComponent("fastlane/screenshots/source", isDirectory: true)
try FileManager.default.createDirectory(at: outputFolder, withIntermediateDirectories: true)

let context = CIContext(options: [.cacheIntermediates: false])

/// Downsampled the way the app does, so the mask sees the same picture.
func image(at url: URL, maxPixelDimension: Int) -> CIImage? {
    guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
    let options: [CFString: Any] = [
        kCGImageSourceCreateThumbnailFromImageAlways: true,
        kCGImageSourceCreateThumbnailWithTransform: true,
        kCGImageSourceThumbnailMaxPixelSize: maxPixelDimension,
        kCGImageSourceShouldCacheImmediately: true,
    ]
    guard let thumbnail = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary)
    else { return nil }
    return CIImage(cgImage: thumbnail)
}

func png(from ciImage: CIImage, maxPixelDimension: CGFloat) -> Data? {
    let extent = ciImage.extent
    guard extent.width > 0, extent.height > 0 else { return nil }
    let scale = min(1, maxPixelDimension / max(extent.width, extent.height))
    let scaled = ciImage.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
    let normalized = scaled.transformed(
        by: CGAffineTransform(translationX: -scaled.extent.minX, y: -scaled.extent.minY)
    )
    return context.pngRepresentation(
        of: normalized,
        format: .RGBA8,
        colorSpace: CGColorSpaceCreateDeviceRGB()
    )
}

var written = 0

for (index, path) in arguments.enumerated() {
    let url = URL(fileURLWithPath: (path as NSString).expandingTildeInPath)
    guard let ciImage = image(at: url, maxPixelDimension: 2_560) else {
        print("skip \(url.lastPathComponent): could not read")
        continue
    }

    let handler = VNImageRequestHandler(ciImage: ciImage)
    let request = VNGenerateForegroundInstanceMaskRequest()
    do {
        try handler.perform([request])
    } catch {
        print("skip \(url.lastPathComponent): \(error.localizedDescription)")
        continue
    }
    guard let result = request.results?.first, !result.allInstances.isEmpty else {
        print("skip \(url.lastPathComponent): nothing in the foreground")
        continue
    }

    // The dish, not the chopsticks beside it: keep the instance with the most
    // pixels, which on a plate photo is the food.
    var best: (data: Data, area: CGFloat)?
    for instance in result.allInstances {
        guard let buffer = try? result.generateMaskedImage(
            ofInstances: [instance],
            from: handler,
            croppedToInstancesExtent: true
        ) else { continue }
        let masked = CIImage(cvPixelBuffer: buffer)
        let area = masked.extent.width * masked.extent.height
        guard let data = png(from: masked, maxPixelDimension: 1_200) else { continue }
        if best == nil || area > best!.area {
            best = (data, area)
        }
    }

    guard let best else {
        print("skip \(url.lastPathComponent): no cutout came out")
        continue
    }
    let destination = outputFolder.appendingPathComponent(
        String(format: "%02d.png", index + 1)
    )
    try best.data.write(to: destination)
    written += 1
    print("cut \(url.lastPathComponent) -> \(destination.lastPathComponent)")
}

print("\(written) cutouts in \(outputFolder.path)")
