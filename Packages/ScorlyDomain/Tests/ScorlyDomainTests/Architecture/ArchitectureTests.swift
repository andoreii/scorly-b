import Foundation
import Testing

/// Pin the v2 package layering rules. Each test scans a package's
/// source files and fails if any imports a module that's forbidden for
/// that layer. The intent is to make architecture violations a CI
/// failure, not a code-review item.
///
/// Layering (from the v2 plan):
/// ```
/// App  ←  Feature*  ←  Data  ←  Domain
///                         ↘   ↗
///                       DesignSystem  (UI primitives only)
/// ```
/// Domain has no upstream deps. Data may import Domain + the Supabase
/// SDK. Features may import Domain, Data, and DesignSystem — but never
/// each other. The app target is the only place feature packages are
/// composed together.
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

        // Features may pull from Domain / Data / DesignSystem and any
        // platform framework. Only sibling features are forbidden.
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
        // The design system is meant to be a SwiftUI-only primitives
        // layer. It must not depend on Domain types (those should arrive
        // via view-models living in feature packages), Data, or any
        // feature package.
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

        // For every package OTHER than the app target, the set of
        // feature packages it imports must have size ≤ 1 (a feature can
        // import itself transitively through testable imports / its own
        // module, but the per-feature test above already pins that
        // sibling-feature imports are forbidden).
        //
        // The app target may import all of them — that's the entire
        // point of the rule.
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

            // A feature package is allowed to "see" itself (its own
            // module is not actually imported, but if a future refactor
            // does that the cross-feature rule above catches it).
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
