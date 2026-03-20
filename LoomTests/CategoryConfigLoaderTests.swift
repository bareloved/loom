import Testing
import Foundation
@testable import Loom

@Suite("Category Config Loader")
struct CategoryConfigLoaderTests {

    @Test("Loads default config from bundle")
    func loadsDefaultConfig() throws {
        let config = try CategoryConfigLoader.loadDefault()
        #expect(config.categories.count > 0)
        #expect(config.categories["Coding"] != nil)
        #expect(config.defaultCategory == "Other")
    }

    @Test("Loads config from custom path")
    func loadsCustomConfig() throws {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let customJSON = """
        {
          "categories": {
            "Gaming": { "apps": ["com.valve.steam"] }
          },
          "default_category": "Misc"
        }
        """.data(using: .utf8)!

        let filePath = tempDir.appendingPathComponent("categories.json")
        try customJSON.write(to: filePath)

        let config = try CategoryConfigLoader.load(from: filePath)
        #expect(config.categories.count == 1)
        #expect(config.categories["Gaming"] != nil)
        #expect(config.defaultCategory == "Misc")
    }

    @Test("Writes default config to disk if missing")
    func writesDefaultIfMissing() throws {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let filePath = tempDir.appendingPathComponent("categories.json")
        let config = try CategoryConfigLoader.loadOrCreateDefault(at: filePath)

        #expect(config.categories.count > 0)
        #expect(FileManager.default.fileExists(atPath: filePath.path))
    }
}
