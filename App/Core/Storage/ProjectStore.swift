import Foundation

enum Paper: String, Codable, CaseIterable, Identifiable {
    case a4, letter
    var id: String { rawValue }
    var width: Int { self == .a4 ? 21000 : 21590 }
    var height: Int { self == .a4 ? 29700 : 27940 }
    var title: String { self == .a4 ? "A4" : "Letter" }
}

/// Physical dimensions use integer hundredths of a millimetre.
struct SampleProject: Codable, Equatable {
    var id = UUID()
    var imagePNG: Data
    var width = 5000
    var height = 7000
    var paper: Paper = .a4
}
struct ProjectEnvelope: Codable {
    var version = 1
    let project: SampleProject
}
enum StarterError: Error { case invalidImage, invalidDimensions, unsupportedVersion, quota, corruptHistory }

struct ProjectStore {
    let directory: URL
    init(directory: URL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        .appendingPathComponent("ToolStarterProjects", isDirectory: true)) { self.directory = directory }
    var file: URL { directory.appendingPathComponent("draft.json") }
    func save(_ project: SampleProject) throws {
        _ = try PDFExporter.contentRect(project)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try JSONEncoder().encode(ProjectEnvelope(project: project)).write(to: file, options: .atomic)
    }
    func load() throws -> SampleProject? {
        guard FileManager.default.fileExists(atPath: file.path) else { return nil }
        let envelope = try JSONDecoder().decode(ProjectEnvelope.self, from: Data(contentsOf: file))
        guard envelope.version == 1 else { throw StarterError.unsupportedVersion }
        _ = try PDFExporter.contentRect(envelope.project)
        return envelope.project
    }
}
