import Foundation

struct CategoryRule: Codable {
    var apps: [String]
    var related: [String]?
}

struct CategoryConfig: Codable {
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

    func resolve(bundleId: String, currentCategory: String?) -> String {
        if let primary = category(forBundleId: bundleId) {
            return primary
        }
        if let current = currentCategory, isRelated(bundleId: bundleId, toCategory: current) {
            return current
        }
        return defaultCategory
    }
}
