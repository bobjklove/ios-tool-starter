import UIKit
import ImageIO
import PDFKit

enum Length {
    static func points(_ hundredthsMM: Int) -> Double { Double(hundredthsMM) * 72 / 2540 }
    static func units(points: Double) -> Int { Int((points * 2540 / 72).rounded()) }
}

enum ImageImport {
    /// Bakes orientation and removes original metadata; caps decoded image memory.
    static func normalizedPNG(_ data: Data) throws -> Data {
        guard data.count <= 50 * 1024 * 1024,
              let source = CGImageSourceCreateWithData(data as CFData, [kCGImageSourceShouldCache: false] as CFDictionary),
              let cg = CGImageSourceCreateThumbnailAtIndex(source, 0, [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceCreateThumbnailWithTransform: true,
                kCGImageSourceThumbnailMaxPixelSize: 2400,
                kCGImageSourceShouldCacheImmediately: true
              ] as CFDictionary),
              let png = UIImage(cgImage: cg).pngData() else { throw StarterError.invalidImage }
        return png
    }
}

enum PDFExporter {
    static func contentRect(_ project: SampleProject) throws -> CGRect {
        guard project.width > 0, project.height > 0,
              project.width <= project.paper.width - 2000,
              project.height <= project.paper.height - 2000 else { throw StarterError.invalidDimensions }
        return CGRect(x: Length.points((project.paper.width - project.width) / 2),
                      y: Length.points((project.paper.height - project.height) / 2),
                      width: Length.points(project.width), height: Length.points(project.height))
    }
    static func data(_ project: SampleProject) throws -> Data {
        try Task<Never, Never>.checkCancellation()
        let rect = try contentRect(project)
        guard let image = UIImage(data: project.imagePNG), image.size.width > 0, image.size.height > 0 else {
            throw StarterError.invalidImage
        }
        let bounds = CGRect(x: 0, y: 0, width: Length.points(project.paper.width), height: Length.points(project.paper.height))
        let format = UIGraphicsPDFRendererFormat()
        format.documentInfo = [:]
        return UIGraphicsPDFRenderer(bounds: bounds, format: format).pdfData { context in
            context.beginPage()
            let cg = context.cgContext
            cg.setFillColor(UIColor.white.cgColor); cg.fill(bounds)
            cg.saveGState(); cg.clip(to: rect)
            let scale = max(rect.width / image.size.width, rect.height / image.size.height)
            let size = CGSize(width: image.size.width * scale, height: image.size.height * scale)
            image.draw(in: CGRect(x: rect.midX - size.width / 2, y: rect.midY - size.height / 2,
                                  width: size.width, height: size.height))
            cg.restoreGState()
        }
    }
    static func export(_ project: SampleProject, to destination: URL) throws {
        let bytes = try data(project)
        try Task<Never, Never>.checkCancellation()
        try bytes.write(to: destination, options: .atomic)
    }
}

struct ExportLease: Identifiable {
    let id = UUID()
    let directory: URL
    let fingerprint: String
    var url: URL { directory.appendingPathComponent("Export.pdf") }
}
struct TemporaryExports {
    let root: URL
    init(root: URL = FileManager.default.temporaryDirectory.appendingPathComponent("ToolStarterExports", isDirectory: true)) {
        self.root = root
    }
    func clearStale() throws {
        if FileManager.default.fileExists(atPath: root.path) { try FileManager.default.removeItem(at: root) }
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    }
    func create(_ project: SampleProject) throws -> ExportLease {
        let lease = ExportLease(directory: root.appendingPathComponent(UUID().uuidString, isDirectory: true),
                                fingerprint: try ExportFingerprint.make(project))
        do {
            try FileManager.default.createDirectory(at: lease.directory, withIntermediateDirectories: true)
            try PDFExporter.export(project, to: lease.url)
            return lease
        } catch { remove(lease); throw error }
    }
    func remove(_ lease: ExportLease) { try? FileManager.default.removeItem(at: lease.directory) }
}
