import Foundation

/// Locates source files inside the Scorly repo and inspects their
/// `import` statements. Used by the architecture tests in this folder
/// to pin the package layering rules from the v2 plan:
///
/// - `ScorlyDomain` may not import UIKit/SwiftUI/Supabase or any
///   downstream package (Data / Features / DesignSystem).
/// - `ScorlyData` may not import UIKit/SwiftUI or any feature package.
/// - `ScorlyFeature*` may not import another `ScorlyFeature*`.
///
/// Implementation note: the alternative is a third-party AST tool
/// (Harmonize / Sourcery). For the rules above — which only need to
/// check import statements — a regex pass over the package's source
/// files is just as reliable and ships with zero extra dependencies.
/// If the rule set ever needs structural facts (subclass relationships,
/// access-control conformance, etc.), that's the moment to swap in a
/// real AST tool.
enum ArchitectureScanner {
    // MARK: - Repo discovery

    /// Walks up from this file's location until it finds the directory
    /// containing `project.yml`. Tests run with arbitrary cwd, so file
    /// paths must be resolved from `#filePath`.
    static func repoRoot(file: StaticString = #filePath) -> URL {
        var dir = URL(fileURLWithPath: "\(file)").deletingLastPathComponent()
        let fileManager = FileManager.default

        while dir.path != "/" {
            let marker = dir.appendingPathComponent("project.yml")
            if fileManager.fileExists(atPath: marker.path) {
                return dir
            }
            dir = dir.deletingLastPathComponent()
        }
        fatalError("Could not locate Scorly repo root from \(file)")
    }

    /// Sources directory for a given SPM package, e.g.
    /// `Packages/ScorlyDomain/Sources/ScorlyDomain`.
    static func sourcesDirectory(for package: String) -> URL {
        repoRoot()
            .appendingPathComponent("Packages")
            .appendingPathComponent(package)
            .appendingPathComponent("Sources")
            .appendingPathComponent(package)
    }

    /// Sources directory for the app target, `Scorly/`.
    static func appSourcesDirectory() -> URL {
        repoRoot().appendingPathComponent("Scorly")
    }

    // MARK: - File walking

    /// All `.swift` files under `directory`, recursively. Returns paths
    /// relative to `repoRoot()` so test failures point at something a
    /// human can find immediately.
    static func swiftFiles(under directory: URL) -> [URL] {
        let fileManager = FileManager.default
        guard
            let enumerator = fileManager.enumerator(
                at: directory,
                includingPropertiesForKeys: [.isRegularFileKey],
                options: [.skipsHiddenFiles]
            )
        else {
            return []
        }

        var result: [URL] = []
        for case let url as URL in enumerator {
            guard url.pathExtension == "swift" else { continue }
            let values = try? url.resourceValues(forKeys: [.isRegularFileKey])
            if values?.isRegularFile == true {
                result.append(url)
            }
        }
        return result
    }

    // MARK: - Import extraction

    /// Returns the module names imported by `file`. Strips submodule
    /// paths (`import Foundation.NSURL` → `Foundation`) and ignores
    /// import attributes (`@testable import X`, `@_implementationOnly`,
    /// etc.) so the caller only sees the top-level module.
    ///
    /// Handles the common forms:
    /// ```swift
    /// import Foundation
    /// import struct Foundation.URL
    /// @testable import ScorlyData
    /// @_implementationOnly import Supabase
    /// ```
    /// Does NOT try to be a full Swift parser — line comments and
    /// block-comment-aware stripping are sufficient because the rules
    /// only need to detect deliberate imports. A determined developer
    /// could hide one inside a multi-line string, but at that point the
    /// rule is being intentionally subverted and any tooling would
    /// fail.
    static func importedModules(in file: URL) -> Set<String> {
        guard let contents = try? String(contentsOf: file, encoding: .utf8) else {
            return []
        }

        var modules: Set<String> = []
        var inBlockComment = false
        for rawLine in contents.components(separatedBy: .newlines) {
            let stripped = stripComments(from: rawLine, inBlockComment: &inBlockComment)
            if let module = parseImport(from: stripped) {
                modules.insert(module)
            }
        }
        return modules
    }

    /// Remove `//` line comments and `/* ... */` block comments from a
    /// single source line. `inBlockComment` is threaded across lines so
    /// multi-line `/* ... */` blocks are tracked correctly.
    private static func stripComments(
        from rawLine: String,
        inBlockComment: inout Bool
    ) -> String {
        var line = rawLine

        if inBlockComment {
            if let endRange = line.range(of: "*/") {
                line = String(line[endRange.upperBound...])
                inBlockComment = false
            } else {
                return ""
            }
        }
        if let startRange = line.range(of: "/*") {
            let before = line[..<startRange.lowerBound]
            if let endRange = line.range(
                of: "*/",
                range: startRange.upperBound..<line.endIndex
            ) {
                line = String(before) + String(line[endRange.upperBound...])
            } else {
                line = String(before)
                inBlockComment = true
            }
        }
        if let commentRange = line.range(of: "//") {
            line = String(line[..<commentRange.lowerBound])
        }
        return line.trimmingCharacters(in: .whitespaces)
    }

    /// Parse a single comment-stripped line and return its top-level
    /// imported module, or nil if the line is not an `import` statement.
    /// Handles leading attributes (`@testable`, `@_implementationOnly`,
    /// etc.) and the `import struct Foundation.URL` form.
    private static func parseImport(from line: String) -> String? {
        guard !line.isEmpty else { return nil }

        // Peel off leading attributes.
        var working = line
        while working.hasPrefix("@") {
            guard let space = working.firstIndex(of: " ") else { return nil }
            working = String(working[working.index(after: space)...])
                .trimmingCharacters(in: .whitespaces)
        }

        guard working.hasPrefix("import ") else { return nil }

        var remainder = String(working.dropFirst("import ".count))
            .trimmingCharacters(in: .whitespaces)

        let declKinds: Set = [
            "struct", "class", "enum", "protocol",
            "typealias", "func", "var", "let",
        ]
        if let firstSpace = remainder.firstIndex(of: " ") {
            let firstToken = String(remainder[..<firstSpace])
            if declKinds.contains(firstToken) {
                remainder = String(remainder[remainder.index(after: firstSpace)...])
                    .trimmingCharacters(in: .whitespaces)
            }
        }

        let module = remainder.components(separatedBy: ".").first ?? remainder
        let cleaned = module.trimmingCharacters(
            in: CharacterSet.whitespaces.union(.punctuationCharacters)
        )
        return cleaned.isEmpty ? nil : cleaned
    }

    // MARK: - Reporting

    /// Convenience: collect every (file, forbidden-module) pair under
    /// `directory` whose imports match `forbidden`. Used to produce a
    /// single rich failure message instead of one assert per file.
    static func forbiddenImports(
        under directory: URL,
        forbidden: Set<String>
    ) -> [(file: URL, module: String)] {
        var hits: [(URL, String)] = []
        for file in swiftFiles(under: directory) {
            let imports = importedModules(in: file)
            let bad = imports.intersection(forbidden)
            for module in bad.sorted() {
                hits.append((file, module))
            }
        }
        return hits
    }

    /// Render `forbiddenImports` as a multi-line string the developer
    /// can paste into a fix.
    static func renderHits(_ hits: [(file: URL, module: String)]) -> String {
        let root = repoRoot().path
        return hits
            .map { hit in
                let relativePath = hit.file.path.replacingOccurrences(
                    of: root + "/",
                    with: ""
                )
                return "  - \(relativePath): import \(hit.module)"
            }
            .joined(separator: "\n")
    }
}
