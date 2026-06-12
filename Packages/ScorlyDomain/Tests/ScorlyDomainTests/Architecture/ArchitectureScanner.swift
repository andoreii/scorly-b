import Foundation

/// Locates source files and inspects their `import` statements, used
/// by the architecture tests to enforce package layering rules (Domain
/// can't import UI/network/downstream packages, features can't import
/// each other, etc).
///
/// A regex pass over imports is enough for these rules; only switch to
/// a real AST tool if we need structural facts beyond imports.
enum ArchitectureScanner {
    // MARK: - Repo discovery

    /// Walks up from this file's location to find the directory
    /// containing `project.yml`, since tests can run with arbitrary cwd.
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

    /// e.g. `Packages/ScorlyDomain/Sources/ScorlyDomain`.
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

    /// All `.swift` files under `directory`, recursively.
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

    /// Returns the top-level module names imported by `file`, stripping
    /// submodule paths and import attributes (`@testable`, etc).
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

    /// Strips `//` and `/* ... */` comments from a line; `inBlockComment`
    /// tracks state across multi-line block comments.
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

    /// Returns the imported module from a comment-stripped line, or nil
    /// if it's not an import statement.
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

    /// Collects every (file, forbidden-module) pair under `directory`
    /// for a single combined failure message.
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

    /// Renders `forbiddenImports` as a multi-line string for failure output.
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
