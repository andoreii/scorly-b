import Foundation
import Testing

/// Pins the package layering rules: each test scans a package's source
/// files and fails if any imports a module forbidden for that layer,
/// so violations are a CI failure rather than a code-review item.
struct ArchitectureTests {
    // MARK: - Domain layer

    @Test("ScorlyDomain has no UI / network / sibling-package imports")
    func domainImportsAreClean() {
        let dir = ArchitectureScanner.sourcesDirectory(for: "ScorlyDomain")
        let forbidden: Set = [
            "UIKit",
            "SwiftUI",
            "AppKit",
            "Supabase",
            "ScorlyData",
            "ScorlyDesignSystem",
            "ScorlyFeatureAuth",
            "ScorlyFeatureCourses",
            "ScorlyFeatureRound",
            "ScorlyFeatureHistory",
            "ScorlyFeatureStats",
            "ScorlyFeatureGoals",
            "ScorlyFeatureSettings",
        ]
        let hits = ArchitectureScanner.forbiddenImports(
            under: dir,
            forbidden: forbidden
        )
        #expect(
            hits.isEmpty,
            """
            ScorlyDomain must be UI-free, network-free, and sit at the
            bottom of the layering. Forbidden imports found:
            \(ArchitectureScanner.renderHits(hits))
            """
        )
    }

    // MARK: - Data layer

    @Test("ScorlyData has no UI / feature-package imports")
    func dataImportsAreClean() {
        let dir = ArchitectureScanner.sourcesDirectory(for: "ScorlyData")
        let forbidden: Set = [
            "UIKit",
            "SwiftUI",
            "AppKit",
            "ScorlyDesignSystem",
            "ScorlyFeatureAuth",
            "ScorlyFeatureCourses",
            "ScorlyFeatureRound",
            "ScorlyFeatureHistory",
            "ScorlyFeatureStats",
            "ScorlyFeatureGoals",
            "ScorlyFeatureSettings",
        ]
        let hits = ArchitectureScanner.forbiddenImports(
            under: dir,
            forbidden: forbidden
        )
        #expect(
            hits.isEmpty,
            """
            ScorlyData may import Domain + Supabase. UI frameworks and
            feature packages are forbidden. Found:
            \(ArchitectureScanner.renderHits(hits))
            """
        )
    }

    // MARK: - Feature isolation

    @Test("Feature packages do not import each other", arguments: [
        "ScorlyFeatureAuth",
        "ScorlyFeatureCourses",
        "ScorlyFeatureRound",
        "ScorlyFeatureHistory",
        "ScorlyFeatureStats",
        "ScorlyFeatureGoals",
        "ScorlyFeatureSettings",
    ])
    func featureCannotImportSiblingFeature(featureName: String) {
        let allFeatures: Set = [
            "ScorlyFeatureAuth",
            "ScorlyFeatureCourses",
            "ScorlyFeatureRound",
            "ScorlyFeatureHistory",
            "ScorlyFeatureStats",
            "ScorlyFeatureGoals",
            "ScorlyFeatureSettings",
        ]
        let siblings = allFeatures.subtracting([featureName])

        // Only sibling features are forbidden.
        let dir = ArchitectureScanner.sourcesDirectory(for: featureName)
        let hits = ArchitectureScanner.forbiddenImports(
            under: dir,
            forbidden: siblings
        )
        #expect(
            hits.isEmpty,
            """
            \(featureName) is importing another feature package. Feature
            packages must compose only through the app target. Found:
            \(ArchitectureScanner.renderHits(hits))
            """
        )
    }

    // MARK: - Design system isolation

    @Test("ScorlyDesignSystem does not import Data / features / Domain")
    func designSystemImportsAreClean() {
        // Domain types should arrive via view-models in feature packages.
        let dir = ArchitectureScanner.sourcesDirectory(for: "ScorlyDesignSystem")
        let forbidden: Set = [
            "ScorlyDomain",
            "ScorlyData",
            "Supabase",
            "ScorlyFeatureAuth",
            "ScorlyFeatureCourses",
            "ScorlyFeatureRound",
            "ScorlyFeatureHistory",
            "ScorlyFeatureStats",
            "ScorlyFeatureGoals",
            "ScorlyFeatureSettings",
        ]
        let hits = ArchitectureScanner.forbiddenImports(
            under: dir,
            forbidden: forbidden
        )
        #expect(
            hits.isEmpty,
            """
            ScorlyDesignSystem is a SwiftUI primitives layer. It must
            not depend on Domain, Data, the Supabase SDK, or any
            feature package. Found:
            \(ArchitectureScanner.renderHits(hits))
            """
        )
    }

    // MARK: - App is the only feature-composer

    @Test("Only the app target imports more than one feature package")
    func onlyAppComposesFeatures() {
        let allFeatures: Set = [
            "ScorlyFeatureAuth",
            "ScorlyFeatureCourses",
            "ScorlyFeatureRound",
            "ScorlyFeatureHistory",
            "ScorlyFeatureStats",
            "ScorlyFeatureGoals",
            "ScorlyFeatureSettings",
        ]

        // Every package other than the app target should see at most
        // one feature package; only the app composes them all.
        let packagesToCheck = [
            "ScorlyDomain",
            "ScorlyData",
            "ScorlyDesignSystem",
        ] + allFeatures.sorted()

        for package in packagesToCheck {
            let dir = ArchitectureScanner.sourcesDirectory(for: package)
            var seenFeatures: Set<String> = []
            for file in ArchitectureScanner.swiftFiles(under: dir) {
                let imports = ArchitectureScanner.importedModules(in: file)
                seenFeatures.formUnion(imports.intersection(allFeatures))
            }

            // A feature package is allowed to "see" itself.
            seenFeatures.remove(package)

            #expect(
                seenFeatures.isEmpty,
                """
                \(package) imports feature package(s) \(seenFeatures.sorted()).
                Only the app target may compose features.
                """
            )
        }
    }
}
