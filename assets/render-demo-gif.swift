#!/usr/bin/env swift
import AppKit
import Foundation
import ImageIO
import UniformTypeIdentifiers

let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let script = root.appendingPathComponent("assets/demo.sh")
let output = root.appendingPathComponent("assets/demo.gif")

let process = Process()
process.executableURL = URL(fileURLWithPath: "/bin/bash")
process.arguments = [script.path]
var environment = ProcessInfo.processInfo.environment
environment["SHAREMEMORY_DEMO_DIR"] = "/tmp/sharememory-demo-recording"
environment["SHAREMEMORY_DEMO_DATE"] = "2026-06-12"
process.environment = environment

let pipe = Pipe()
process.standardOutput = pipe
process.standardError = pipe
try process.run()
process.waitUntilExit()

let data = pipe.fileHandleForReading.readDataToEndOfFile()
let text = String(data: data, encoding: .utf8) ?? ""
guard process.terminationStatus == 0 else {
    FileHandle.standardError.write(data)
    exit(process.terminationStatus)
}

let lines = text.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
let checkpoints = [8, 12, 18, lines.count].map { min($0, lines.count) }

let width: CGFloat = 1100
let height: CGFloat = 720
let maxLines = 28
let background = NSColor(calibratedRed: 0.055, green: 0.063, blue: 0.075, alpha: 1)
let panel = NSColor(calibratedRed: 0.08, green: 0.09, blue: 0.105, alpha: 1)
let border = NSColor(calibratedRed: 0.22, green: 0.25, blue: 0.30, alpha: 1)
let textColor = NSColor(calibratedRed: 0.88, green: 0.91, blue: 0.94, alpha: 1)
let mutedColor = NSColor(calibratedRed: 0.58, green: 0.66, blue: 0.75, alpha: 1)
let accent = NSColor(calibratedRed: 0.20, green: 0.72, blue: 0.52, alpha: 1)
let font = NSFont.monospacedSystemFont(ofSize: 18, weight: .regular)
let bold = NSFont.monospacedSystemFont(ofSize: 18, weight: .semibold)

func drawFrame(upTo count: Int) -> CGImage {
    let image = NSImage(size: NSSize(width: width, height: height))
    image.lockFocus()

    background.setFill()
    NSRect(x: 0, y: 0, width: width, height: height).fill()

    let terminal = NSRect(x: 42, y: 42, width: width - 84, height: height - 84)
    let path = NSBezierPath(roundedRect: terminal, xRadius: 16, yRadius: 16)
    panel.setFill()
    path.fill()
    border.setStroke()
    path.lineWidth = 1
    path.stroke()

    let dots: [(NSColor, CGFloat)] = [
        (NSColor(calibratedRed: 0.94, green: 0.32, blue: 0.28, alpha: 1), 72),
        (NSColor(calibratedRed: 0.95, green: 0.72, blue: 0.26, alpha: 1), 98),
        (NSColor(calibratedRed: 0.25, green: 0.78, blue: 0.39, alpha: 1), 124),
    ]
    for (color, x) in dots {
        color.setFill()
        NSBezierPath(ovalIn: NSRect(x: x, y: height - 82, width: 13, height: 13)).fill()
    }

    let titleAttributes: [NSAttributedString.Key: Any] = [.font: bold, .foregroundColor: mutedColor]
    "ShareMemory live replay".draw(at: NSPoint(x: 158, y: height - 86), withAttributes: titleAttributes)

    let visible = Array(lines.prefix(count)).suffix(maxLines)
    var y = height - 132
    for line in visible {
        let color = line.hasPrefix("$") || line.hasPrefix("Result:") ? accent : textColor
        let attributes: [NSAttributedString.Key: Any] = [.font: line.hasPrefix("$") ? bold : font, .foregroundColor: color]
        line.draw(at: NSPoint(x: 72, y: y), withAttributes: attributes)
        y -= 22
    }

    image.unlockFocus()
    guard
        let tiff = image.tiffRepresentation,
        let bitmap = NSBitmapImageRep(data: tiff),
        let cgImage = bitmap.cgImage
    else {
        fatalError("Could not render GIF frame")
    }
    return cgImage
}

guard let destination = CGImageDestinationCreateWithURL(output as CFURL, UTType.gif.identifier as CFString, checkpoints.count, nil) else {
    fatalError("Could not create GIF destination")
}

let gifProperties: [CFString: Any] = [
    kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFLoopCount: 0]
]
CGImageDestinationSetProperties(destination, gifProperties as CFDictionary)

let frameProperties: [CFString: Any] = [
    kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFDelayTime: 1.25]
]
for checkpoint in checkpoints {
    CGImageDestinationAddImage(destination, drawFrame(upTo: checkpoint), frameProperties as CFDictionary)
}

if !CGImageDestinationFinalize(destination) {
    fatalError("Could not finalize assets/demo.gif")
}

print("wrote \(output.path)")
