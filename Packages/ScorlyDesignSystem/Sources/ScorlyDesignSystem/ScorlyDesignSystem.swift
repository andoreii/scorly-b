import CoreText
import Foundation
#if canImport(UIKit)
import UIKit
#endif

/// Public entry point. Call `ScorlyDesignSystem.registerFonts()` once
/// from the app's `init()` so Geist + JetBrains Mono are available to
/// `Font.custom(_:size:)` calls everywhere downstream.
@MainActor
public enum ScorlyDesignSystem {
    private static var didRegisterFonts = false

    /// Registers the bundled Geist + JetBrains Mono TTFs with the system
    /// font manager. Idempotent — safe to call multiple times. Must be
    /// invoked on the main actor.
    public static func registerFonts() {
        guard !didRegisterFonts else { return }
        didRegisterFonts = true

        let names = [
            "Geist-Light",
            "Geist-Regular",
            "Geist-Medium",
            "Geist-SemiBold",
            "Geist-Bold",
            "JetBrainsMono-Regular",
            "JetBrainsMono-Medium",
            "JetBrainsMono-SemiBold",
        ]
        for name in names {
            registerFont(name: name)
        }
    }

    /// SPM's `.process` rule flattens `Resources/Fonts/*.ttf` to the
    /// bundle root, so we look up by basename without a subdirectory.
    /// Asserts loudly in DEBUG if either the URL is missing or
    /// registration fails — a silent miss here would mean every
    /// custom-font glyph silently falls back to SF Pro.
    private static func registerFont(name: String) {
        guard let url = Bundle.module.url(forResource: name, withExtension: "ttf") else {
            assertionFailure("Missing bundled font: \(name).ttf")
            return
        }
        var error: Unmanaged<CFError>?
        let ok = CTFontManagerRegisterFontsForURL(url as CFURL, .process, &error)
        if !ok {
            assertionFailure(
                "Failed to register \(name): \(error?.takeRetainedValue().localizedDescription ?? "unknown")"
            )
        }
    }
}
