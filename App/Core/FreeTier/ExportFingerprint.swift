import Foundation
import CryptoKit

enum ExportFingerprint {
    private struct RenderContent: Encodable {
        let image: String
        let width: Int
        let height: Int
        let paper: Paper
        let rendererVersion: Int
    }
    static func make(_ project: SampleProject) throws -> String {
        let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]
        let content = RenderContent(image: digest(project.imagePNG), width: project.width,
                                    height: project.height, paper: project.paper, rendererVersion: 1)
        return digest(try encoder.encode(content))
    }
    private static func digest(_ data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }
}
