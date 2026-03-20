import Foundation

struct CategoryRule: Codable, Equatable {
    var apps: [String]
    var related: [String]?
    var urlPatterns: [String]?
}

struct CategoryConfig: Codable, Equatable {
    var categories: [String: CategoryRule]
    var defaultCategory: String

    enum CodingKeys: String, CodingKey {
        case categories
        case defaultCategory = "default_category"
    }

    func category(forBundleId bundleId: String) -> String? {
        for (name, rule) in categories {
            if rule.apps.contains(bundleId) {
                return name
            }
        }
        return nil
    }

    func isRelated(bundleId: String, toCategory category: String) -> Bool {
        guard let rule = categories[category] else { return false }
        return rule.related?.contains(bundleId) ?? false
    }

    func resolve(bundleId: String, currentCategory: String?, pageURL: String? = nil) -> String {
        // 1. Check primary app match
        if let primary = category(forBundleId: bundleId) {
            return primary
        }

        // 2. Check URL patterns
        if let url = pageURL {
            for (name, rule) in categories {
                if let patterns = rule.urlPatterns {
                    for pattern in patterns {
                        if url.localizedCaseInsensitiveContains(pattern) {
                            return name
                        }
                    }
                }
            }
        }

        // 3. Check related apps
        if let current = currentCategory, isRelated(bundleId: bundleId, toCategory: current) {
            return current
        }

        // 4. Fall back to default
        return defaultCategory
    }
}
