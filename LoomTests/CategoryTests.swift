import Testing
import Foundation
@testable import Loom

@Suite("Category Configuration")
struct CategoryTests {

    let sampleJSON = """
    {
      "categories": {
        "Coding": {
          "apps": ["com.apple.dt.Xcode", "com.microsoft.VSCode"],
          "related": ["com.apple.Terminal"]
        },
        "Email": {
          "apps": ["com.apple.mail"]
        }
      },
      "default_category": "Other"
    }
    """.data(using: .utf8)!

    @Test("Decodes categories from JSON")
    func decodesCategories() throws {
        let config = try JSONDecoder().decode(CategoryConfig.self, from: sampleJSON)
        #expect(config.categories.count == 2)
        #expect(config.categories["Coding"]?.apps.contains("com.apple.dt.Xcode") == true)
        #expect(config.categories["Coding"]?.related?.contains("com.apple.Terminal") == true)
        #expect(config.categories["Email"]?.related == nil)
        #expect(config.defaultCategory == "Other")
    }

    @Test("Categorizes primary app correctly")
    func categorizesPrimaryApp() throws {
        let config = try JSONDecoder().decode(CategoryConfig.self, from: sampleJSON)
        #expect(config.category(forBundleId: "com.apple.dt.Xcode") == "Coding")
        #expect(config.category(forBundleId: "com.apple.mail") == "Email")
    }

    @Test("Unknown app returns nil from category lookup")
    func unknownAppReturnsNil() throws {
        let config = try JSONDecoder().decode(CategoryConfig.self, from: sampleJSON)
        #expect(config.category(forBundleId: "com.unknown.app") == nil)
    }

    @Test("Resolve: primary match wins, related inherits, unknown falls to default")
    func resolveCategory() throws {
        let config = try JSONDecoder().decode(CategoryConfig.self, from: sampleJSON)
        #expect(config.resolve(bundleId: "com.apple.dt.Xcode", currentCategory: nil as String?) == "Coding")
        #expect(config.resolve(bundleId: "com.apple.dt.Xcode", currentCategory: "Email") == "Coding")
        #expect(config.resolve(bundleId: "com.apple.Terminal", currentCategory: "Coding") == "Coding")
        #expect(config.resolve(bundleId: "com.apple.Terminal", currentCategory: "Email") == "Other")
        #expect(config.resolve(bundleId: "com.unknown.app", currentCategory: "Coding") == "Other")
    }

    @Test("Related app detected correctly")
    func relatedAppDetected() throws {
        let config = try JSONDecoder().decode(CategoryConfig.self, from: sampleJSON)
        #expect(config.isRelated(bundleId: "com.apple.Terminal", toCategory: "Coding") == true)
        #expect(config.isRelated(bundleId: "com.apple.Terminal", toCategory: "Email") == false)
        #expect(config.isRelated(bundleId: "com.apple.mail", toCategory: "Coding") == false)
    }

    @Test("URL patterns match and categorize browser pages")
    func urlPatternMatching() throws {
        let json = """
        {
          "categories": {
            "Coding": {
              "apps": ["com.apple.dt.Xcode"],
              "urlPatterns": ["github.com", "stackoverflow.com"]
            },
            "Social": {
              "apps": [],
              "urlPatterns": ["twitter.com", "reddit.com"]
            }
          },
          "default_category": "Other"
        }
        """.data(using: .utf8)!

        let config = try JSONDecoder().decode(CategoryConfig.self, from: json)

        // URL pattern should match for a browser bundle
        let result = config.resolve(
            bundleId: "com.apple.Safari",
            currentCategory: nil,
            pageURL: "https://github.com/user/repo"
        )
        #expect(result == "Coding")

        // Different URL pattern
        let social = config.resolve(
            bundleId: "com.apple.Safari",
            currentCategory: nil,
            pageURL: "https://twitter.com/home"
        )
        #expect(social == "Social")

        // No matching URL -> default
        let other = config.resolve(
            bundleId: "com.apple.Safari",
            currentCategory: nil,
            pageURL: "https://example.com"
        )
        #expect(other == "Other")

        // No URL provided -> default
        let noUrl = config.resolve(
            bundleId: "com.apple.Safari",
            currentCategory: nil
        )
        #expect(noUrl == "Other")
    }

    @Test("URL patterns decode as optional")
    func urlPatternsOptional() throws {
        // Original JSON without urlPatterns should still decode fine
        let config = try JSONDecoder().decode(CategoryConfig.self, from: sampleJSON)
        #expect(config.categories["Coding"]?.urlPatterns == nil)
        #expect(config.categories["Email"]?.urlPatterns == nil)
    }
}
