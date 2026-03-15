import Foundation

enum CategoryConfigLoader {

    static let appSupportDir: URL = {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return base.appendingPathComponent("TimeTracker")
    }()

    static let defaultConfigPath: URL = {
        appSupportDir.appendingPathComponent("categories.json")
    }()

    static func loadDefault() throws -> CategoryConfig {
        guard let url = Bundle.module.url(forResource: "default-categories", withExtension: "json") else {
            throw ConfigError.bundledConfigNotFound
        }
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode(CategoryConfig.self, from: data)
    }

    static func load(from url: URL) throws -> CategoryConfig {
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode(CategoryConfig.self, from: data)
    }

    static func loadOrCreateDefault(at url: URL? = nil) throws -> CategoryConfig {
        let target = url ?? defaultConfigPath

        if FileManager.default.fileExists(atPath: target.path) {
            return try load(from: target)
        }

        let dir = target.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)

        let defaultConfig = try loadDefault()
        let data = try JSONEncoder().encode(defaultConfig)
        let pretty = try JSONSerialization.data(
            withJSONObject: try JSONSerialization.jsonObject(with: data),
            options: [.prettyPrinted, .sortedKeys]
        )
        try pretty.write(to: target)

        return defaultConfig
    }

    static func save(_ config: CategoryConfig, to url: URL? = nil) throws {
        let target = url ?? defaultConfigPath
        let dir = target.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)

        let data = try JSONEncoder().encode(config)
        let pretty = try JSONSerialization.data(
            withJSONObject: try JSONSerialization.jsonObject(with: data),
            options: [.prettyPrinted, .sortedKeys]
        )
        try pretty.write(to: target)
    }

    enum ConfigError: Error {
        case bundledConfigNotFound
    }
}
