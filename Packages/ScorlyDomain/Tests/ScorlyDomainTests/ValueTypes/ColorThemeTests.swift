import Foundation
import Testing
@testable import ScorlyDomain

struct ColorThemeTests {
    // MARK: - Preset

    @Test("Preset round-trips by name")
    func presetRoundTrip() {
        let theme = ColorTheme(encoded: "Forest")
        #expect(theme == .preset(name: "Forest"))
        #expect(theme?.encoded == "Forest")
    }

    @Test("Preset trims surrounding whitespace")
    func presetTrimsWhitespace() {
        #expect(ColorTheme(encoded: "  Forest  ") == .preset(name: "Forest"))
    }

    // MARK: - Custom solid

    @Test("CustomSolid parses and re-encodes")
    func solidRoundTrip() {
        let theme = ColorTheme(encoded: "CustomSolid:1A2B3C")
        #expect(theme == .customSolid(hex: "1A2B3C"))
        #expect(theme?.encoded == "CustomSolid:1A2B3C")
    }

    @Test("CustomSolid normalizes lowercase + leading #")
    func solidNormalizes() {
        #expect(ColorTheme(encoded: "CustomSolid:#abcdef") == .customSolid(hex: "ABCDEF"))
        #expect(ColorTheme(encoded: "CustomSolid:abcdef") == .customSolid(hex: "ABCDEF"))
    }

    @Test("CustomSolid rejects malformed hex")
    func solidRejectsMalformed() {
        #expect(ColorTheme(encoded: "CustomSolid:XYZ123") == nil)
        #expect(ColorTheme(encoded: "CustomSolid:12345") == nil) // 5 chars
        #expect(ColorTheme(encoded: "CustomSolid:1234567") == nil) // 7 chars
        #expect(ColorTheme(encoded: "CustomSolid:") == nil)
    }

    // MARK: - Custom gradient

    @Test("CustomGradient parses and re-encodes")
    func gradientRoundTrip() {
        let theme = ColorTheme(encoded: "CustomGradient:112233-AABBCC")
        #expect(theme == .customGradient(start: "112233", end: "AABBCC"))
        #expect(theme?.encoded == "CustomGradient:112233-AABBCC")
    }

    @Test("CustomGradient normalizes both endpoints")
    func gradientNormalizes() {
        let theme = ColorTheme(encoded: "CustomGradient:#aabbcc-ddeeff")
        #expect(theme == .customGradient(start: "AABBCC", end: "DDEEFF"))
    }

    @Test("CustomGradient rejects single-color or malformed payloads")
    func gradientRejectsMalformed() {
        #expect(ColorTheme(encoded: "CustomGradient:112233") == nil)
        #expect(ColorTheme(encoded: "CustomGradient:112233-XYZ123") == nil)
        #expect(ColorTheme(encoded: "CustomGradient:-AABBCC") == nil)
        #expect(ColorTheme(encoded: "CustomGradient:") == nil)
    }

    // MARK: - Empty input

    @Test("Empty / whitespace-only input returns nil")
    func emptyInput() {
        #expect(ColorTheme(encoded: "") == nil)
        #expect(ColorTheme(encoded: "    ") == nil)
    }

    // MARK: - Codable

    @Test("Codable round-trips through the wire-format string")
    func codableRoundTrip() throws {
        let cases: [ColorTheme] = [
            .preset(name: "Forest"),
            .customSolid(hex: "1A2B3C"),
            .customGradient(start: "112233", end: "AABBCC"),
        ]
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        for theme in cases {
            let data = try encoder.encode(theme)
            let decoded = try decoder.decode(ColorTheme.self, from: data)
            #expect(decoded == theme)
        }
    }

    @Test("Codable rejects malformed wire-format strings")
    func codableRejectsMalformed() {
        let badJSON = Data("\"CustomSolid:XYZ123\"".utf8)
        #expect(throws: DecodingError.self) {
            _ = try JSONDecoder().decode(ColorTheme.self, from: badJSON)
        }
    }
}
