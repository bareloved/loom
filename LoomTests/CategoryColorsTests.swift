import Testing
import SwiftUI
import AppKit
@testable import Loom

@Suite("Category Colors")
struct CategoryColorsTests {

    @Test("Known categories get assigned colors")
    func knownCategories() {
        let coding = CategoryColors.color(for: "Coding")
        let email = CategoryColors.color(for: "Email")
        // Different categories must resolve to different colors
        let codingNS = NSColor(coding)
        let emailNS = NSColor(email)
        let codingComponents = codingNS.usingColorSpace(.deviceRGB)
        let emailComponents = emailNS.usingColorSpace(.deviceRGB)
        #expect(codingComponents != nil)
        #expect(emailComponents != nil)
        // At least one RGB component should differ
        let cR = codingComponents!.redComponent
        let eR = emailComponents!.redComponent
        let cG = codingComponents!.greenComponent
        let eG = emailComponents!.greenComponent
        let cB = codingComponents!.blueComponent
        let eB = emailComponents!.blueComponent
        #expect(cR != eR || cG != eG || cB != eB)
    }

    @Test("Same category always returns same color")
    func deterministic() {
        let c1 = CategoryColors.color(for: "MyCustomCategory")
        let c2 = CategoryColors.color(for: "MyCustomCategory")
        // Dynamic colors resolve to the same RGB values
        let ns1 = NSColor(c1).usingColorSpace(.deviceRGB)!
        let ns2 = NSColor(c2).usingColorSpace(.deviceRGB)!
        #expect(ns1.redComponent == ns2.redComponent)
        #expect(ns1.greenComponent == ns2.greenComponent)
        #expect(ns1.blueComponent == ns2.blueComponent)
    }

    @Test("Other gets gray")
    func otherGetsGray() {
        let other = CategoryColors.color(for: "Other")
        let gray = CategoryColors.gray
        // Compare resolved RGB values
        let otherNS = NSColor(other).usingColorSpace(.deviceRGB)!
        let grayNS = NSColor(gray).usingColorSpace(.deviceRGB)!
        #expect(abs(otherNS.redComponent - grayNS.redComponent) < 0.01)
        #expect(abs(otherNS.greenComponent - grayNS.greenComponent) < 0.01)
        #expect(abs(otherNS.blueComponent - grayNS.blueComponent) < 0.01)
    }
}
