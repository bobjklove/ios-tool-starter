#!/usr/bin/env swift
import Foundation

struct Failure: Error, CustomStringConvertible {
    let description: String
}

func run(_ executable: String, _ arguments: [String]) throws {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: executable)
    process.arguments = arguments
    try process.run()
    process.waitUntilExit()
    guard process.terminationStatus == 0 else {
        throw Failure(description: "Command failed (\(process.terminationStatus)): \(URL(fileURLWithPath: executable).lastPathComponent)")
    }
}

func fail(_ message: String) -> Never {
    fputs("generate-app-icon: \(message)\n", stderr)
    exit(2)
}

do {
    guard CommandLine.arguments.count == 3 else {
        throw Failure(description: "usage: generate-app-icon.swift DrawIcon.swift Output.png")
    }
    let source = URL(fileURLWithPath: CommandLine.arguments[1]).standardizedFileURL
    let output = URL(fileURLWithPath: CommandLine.arguments[2]).standardizedFileURL
    guard FileManager.default.fileExists(atPath: source.path) else {
        throw Failure(description: "draw source does not exist")
    }
    try FileManager.default.createDirectory(at: output.deletingLastPathComponent(), withIntermediateDirectories: true)

    let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
    let build = root.appendingPathComponent(".build/icon-generator", isDirectory: true)
    try FileManager.default.createDirectory(at: build, withIntermediateDirectories: true)
    let main = build.appendingPathComponent("main.swift")
    let runner = #"""
import AppKit
import Foundation
import ImageIO

    let size: CGFloat = 1024
    guard let context = CGContext(data: nil, width: Int(size), height: Int(size), bitsPerComponent: 8,
                              bytesPerRow: Int(size) * 4, space: CGColorSpaceCreateDeviceRGB(),
                              bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue) else {
    fatalError("Could not create RGB context")
}
context.setFillColor(CGColor(gray: 1, alpha: 1))
context.fill(CGRect(x: 0, y: 0, width: size, height: size))
drawIcon(context: context, size: size)
guard let image = context.makeImage(),
      let destination = CGImageDestinationCreateWithURL(URL(fileURLWithPath: CommandLine.arguments[1]) as CFURL,
                                                        "public.png" as CFString, 1, nil) else {
    fatalError("Could not create PNG destination")
}
CGImageDestinationAddImage(destination, image, nil)
guard CGImageDestinationFinalize(destination) else { fatalError("Could not write PNG") }
"""#
    let combined = try String(contentsOf: source, encoding: .utf8) + "\n" + runner
    try combined.write(to: main, atomically: true, encoding: .utf8)
    let binary = build.appendingPathComponent("icon-renderer")
    try run("/usr/bin/xcrun", ["swiftc", main.path, "-o", binary.path])
    try run(binary.path, [output.path])

    let data = try Data(contentsOf: output)
    guard data.count >= 26,
          Array(data.prefix(8)) == [137, 80, 78, 71, 13, 10, 26, 10] else {
        throw Failure(description: "output is not a PNG")
    }
    let width = data[16..<20].reduce(UInt32(0)) { ($0 << 8) | UInt32($1) }
    let height = data[20..<24].reduce(UInt32(0)) { ($0 << 8) | UInt32($1) }
    guard width == 1024, height == 1024, data[25] == 2 else {
        throw Failure(description: "expected 1024x1024 RGB PNG without alpha; got \(width)x\(height), color type \(data[25])")
    }
    print("Created and verified 1024x1024 RGB PNG: \(output.path)")
} catch {
    fail(String(describing: error))
}
