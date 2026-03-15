import Testing
import SwiftUI
@testable import TimeTracker

@Suite("Category Colors")
struct CategoryColorsTests {

    @Test("Known categories get assigned colors")
    func knownCategories() {
        let coding = CategoryColors.color(for: "Coding")
        let email = CategoryColors.color(for: "Email")
        #expect(coding != email)
    }

    @Test("Same category always returns same color")
    func deterministic() {
        let c1 = CategoryColors.color(for: "MyCustomCategory")
        let c2 = CategoryColors.color(for: "MyCustomCategory")
        #expect(c1 == c2)
    }

    @Test("Other gets gray")
    func otherGetsGray() {
        let other = CategoryColors.color(for: "Other")
        #expect(other == CategoryColors.gray)
    }
}
