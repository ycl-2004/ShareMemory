#!/usr/bin/env swift
import AppKit
import Foundation
import ImageIO
import UniformTypeIdentifiers

let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let script = root.appendingPathComponent("assets/demo.sh")
let output = root.appendingPathComponent("assets/demo.gif")
let demoDirPath = "/tmp/sharememory-demo-recording"
defer {
    try? FileManager.default.removeItem(atPath: demoDirPath)
}

let process = Process()
process.executableURL = URL(fileURLWithPath: "/bin/bash")
process.arguments = [script.path]
var environment = ProcessInfo.processInfo.environment
environment["SHAREMEMORY_DEMO_DIR"] = demoDirPath
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

let characters = Array(text)
let punctuation: Set<Character> = [":", ",", ".", ";", ")", "]"]

struct Frame {
    let count: Int
    let delay: Double
}

func currentLine(before count: Int) -> String {
    guard count > 0 else { return "" }
    var start = 0
    for i in stride(from: count - 1, through: 0, by: -1) {
        if characters[i] == "\n" {
            start = i + 1
            break
        }
    }
    return String(characters[start..<count])
}

func characterDelay(_ character: Character, line: String, offset: Int) -> Double {
    if line.hasPrefix("$") {
        return [0.050, 0.065, 0.042, 0.080, 0.055][offset % 5]
    }
    if character == " " {
        return [0.018, 0.026, 0.020][offset % 3]
    }
    if punctuation.contains(character) {
        return [0.060, 0.075, 0.050][offset % 3]
    }
    if line.hasPrefix("Result:") {
        return [0.035, 0.048, 0.040, 0.060][offset % 4]
    }
    return [0.018, 0.026, 0.014, 0.032, 0.022, 0.040][offset % 6]
}

func nextLineBreak(from index: Int) -> Int {
    var i = index
    while i < characters.count, characters[i] != "\n" {
        i += 1
    }
    return i
}

func chunkSize(for line: String, offset: Int) -> Int {
    if line.hasPrefix("$") {
        return [1, 2, 1, 3][offset % 4]
    }
    if line.hasPrefix("ShareMemory demo:") || line.hasPrefix("Result:") {
        return [1, 1, 2, 1, 2][offset % 5]
    }
    return [4, 7, 5, 9, 3, 8, 6, 10][offset % 8]
}

func linePause(after line: String) -> Double {
    if line.isEmpty { return 0.12 }
    if line.hasPrefix("$") { return 0.52 }
    if line.hasPrefix("ShareMemory demo:") { return 0.70 }
    if line.hasPrefix("Result:") { return 1.70 }
    if line.hasPrefix("created:") || line.hasPrefix("CONFIG:") || line.hasPrefix("LATEST SYNC_LOG:") {
        return 0.36
    }
    return 0.20
}

var frames: [Frame] = [Frame(count: 0, delay: 0.45)]
var typed = 0
while typed < characters.count {
    let next = characters[typed]
    if next == "\n" {
        let line = currentLine(before: typed)
        typed += 1
        frames.append(Frame(count: typed, delay: linePause(after: line)))
    } else {
        let line = currentLine(before: typed)
        let lineBreak = nextLineBreak(from: typed)
        let end = min(typed + chunkSize(for: line, offset: typed), lineBreak)
        let lastCharacter = characters[max(typed, end - 1)]
        typed = end
        frames.append(Frame(count: typed, delay: characterDelay(lastCharacter, line: line, offset: typed)))
    }
}
frames.append(Frame(count: characters.count, delay: 1.8))

let width: CGFloat = 1000
let height: CGFloat = 660
let maxLines = 26
let background = NSColor(calibratedRed: 0.055, green: 0.063, blue: 0.075, alpha: 1)
let panel = NSColor(calibratedRed: 0.08, green: 0.09, blue: 0.105, alpha: 1)
let border = NSColor(calibratedRed: 0.22, green: 0.25, blue: 0.30, alpha: 1)
let textColor = NSColor(calibratedRed: 0.88, green: 0.91, blue: 0.94, alpha: 1)
let mutedColor = NSColor(calibratedRed: 0.58, green: 0.66, blue: 0.75, alpha: 1)
let accent = NSColor(calibratedRed: 0.20, green: 0.72, blue: 0.52, alpha: 1)
let font = NSFont.monospacedSystemFont(ofSize: 18, weight: .regular)
let bold = NSFont.monospacedSystemFont(ofSize: 18, weight: .semibold)
let charWidth = "M".size(withAttributes: [.font: font]).width

func drawFrame(upTo count: Int, cursorVisible: Bool = true) -> CGImage {
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

    let prefix = String(characters.prefix(count))
    let visible = Array(prefix.split(separator: "\n", omittingEmptySubsequences: false).map(String.init).suffix(maxLines))
    var y = height - 132
    for line in visible {
        let color = line.hasPrefix("$") || line.hasPrefix("Result:") ? accent : textColor
        let attributes: [NSAttributedString.Key: Any] = [.font: line.hasPrefix("$") ? bold : font, .foregroundColor: color]
        line.draw(at: NSPoint(x: 72, y: y), withAttributes: attributes)
        y -= 22
    }

    if cursorVisible, let lastLine = visible.last {
        let cursorY = height - 132 - CGFloat(max(visible.count - 1, 0)) * 22
        let cursorX = 72 + CGFloat(lastLine.count) * charWidth
        accent.setFill()
        NSRect(x: cursorX + 2, y: cursorY + 2, width: 9, height: 18).fill()
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

guard let destination = CGImageDestinationCreateWithURL(output as CFURL, UTType.gif.identifier as CFString, frames.count, nil) else {
    fatalError("Could not create GIF destination")
}

let gifProperties: [CFString: Any] = [
    kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFLoopCount: 0]
]
CGImageDestinationSetProperties(destination, gifProperties as CFDictionary)

for (index, frame) in frames.enumerated() {
    let frameProperties: [CFString: Any] = [
        kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFDelayTime: frame.delay]
    ]
    CGImageDestinationAddImage(
        destination,
        drawFrame(upTo: frame.count, cursorVisible: index % 9 < 7),
        frameProperties as CFDictionary
    )
}

if !CGImageDestinationFinalize(destination) {
    fatalError("Could not finalize assets/demo.gif")
}

print("wrote \(output.path)")
print("frames \(frames.count)")
