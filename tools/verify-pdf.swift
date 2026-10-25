#!/usr/bin/env swift
import AppKit
import Foundation
import PDFKit

struct Check: Decodable {
    let page: Int
    let paper: String
    let imageRectMillimeters: [Double]
    let toleranceMillimeters: Double?
}
struct Manifest: Decodable { let pages: [Check] }
struct Failure: Error, CustomStringConvertible { let description: String }

func stop(_ message: String) -> Never {
    fputs("verify-pdf: \(message)\n", stderr)
    exit(1)
}
func near(_ actual: Double, _ expected: Double, _ tolerance: Double) -> Bool {
    abs(actual - expected) <= tolerance
}

let args = CommandLine.arguments
guard args.count == 3 else { stop("usage: verify-pdf.swift document.pdf expected-geometry.json") }
let pdfURL = URL(fileURLWithPath: args[1])
let manifestURL = URL(fileURLWithPath: args[2])
do {
    let manifest = try JSONDecoder().decode(Manifest.self, from: Data(contentsOf: manifestURL))
    guard let document = PDFDocument(url: pdfURL), document.pageCount == manifest.pages.count else {
        throw Failure(description: "PDF page count does not match manifest")
    }
    for check in manifest.pages {
        guard check.page > 0, check.page <= document.pageCount, check.imageRectMillimeters.count == 4,
              let page = document.page(at: check.page - 1) else {
            throw Failure(description: "invalid page or expected rectangle in manifest")
        }
        let expectedPaper: CGSize
        switch check.paper {
        case "A4": expectedPaper = CGSize(width: 210, height: 297)
        case "Letter": expectedPaper = CGSize(width: 215.9, height: 279.4)
        default: throw Failure(description: "paper must be A4 or Letter")
        }
        let box = page.bounds(for: .mediaBox)
        let mmPerPoint = 25.4 / 72.0
        let tolerance = check.toleranceMillimeters ?? 0.25
        guard near(Double(box.width) * mmPerPoint, expectedPaper.width, tolerance),
              near(Double(box.height) * mmPerPoint, expectedPaper.height, tolerance) else {
            throw Failure(description: "page \(check.page) size is not expected \(check.paper)")
        }

        // Rasterize at 600 dpi and measure non-white pixels. Expected values in the
        // manifest define the image ink rectangle in PDF page coordinates (origin at bottom-left).
        let scale = 600.0 / 72.0
        let width = Int((box.width * scale).rounded()), height = Int((box.height * scale).rounded())
        guard let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8,
                                      bytesPerRow: width * 4, space: CGColorSpaceCreateDeviceRGB(),
                                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else {
            throw Failure(description: "could not create PDF raster context")
        }
        context.setFillColor(NSColor.white.cgColor)
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        context.scaleBy(x: scale, y: scale)
        page.draw(with: .mediaBox, to: context)
        guard let image = context.makeImage(), let data = image.dataProvider?.data,
              let bytes = CFDataGetBytePtr(data) else { throw Failure(description: "could not read rendered PDF pixels") }
        var minX = width, minY = height, maxX = -1, maxY = -1
        let rowBytes = image.bytesPerRow
        for y in 0..<height {
            for x in 0..<width {
                let offset = y * rowBytes + x * 4
                if bytes[offset] < 248 || bytes[offset + 1] < 248 || bytes[offset + 2] < 248 {
                    minX = min(minX, x); minY = min(minY, y)
                    maxX = max(maxX, x); maxY = max(maxY, y)
                }
            }
        }
        guard maxX >= minX else { throw Failure(description: "no non-white page content found") }
        let measured = [Double(minX) / scale * mmPerPoint,
                        (Double(height - 1 - maxY)) / scale * mmPerPoint,
                        Double(maxX - minX + 1) / scale * mmPerPoint,
                        Double(maxY - minY + 1) / scale * mmPerPoint]
        guard zip(measured, check.imageRectMillimeters).allSatisfy({ near($0.0, $0.1, tolerance) }) else {
            throw Failure(description: "page \(check.page) visible content bounds differ; measured mm \(measured)")
        }
        print("PASS page \(check.page): \(check.paper), visible content bounds match within \(tolerance) mm")
    }
} catch {
    stop(String(describing: error))
}
