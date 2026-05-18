# Scorly/B — developer Makefile
# Common workflows. Run `make help` for a list.

SHELL := /bin/sh
SIM ?= iPhone 17

.PHONY: help bootstrap hooks gen lint format format-check build test packages-test ci clean

help:
	@echo "Scorly/B — make targets:"
	@echo "  bootstrap     Install developer tools and git hooks"
	@echo "  hooks         Point git at .githooks/ (no-op until .githooks/ exists)"
	@echo "  gen           Run xcodegen"
	@echo "  lint          Run SwiftLint (strict)"
	@echo "  format        Run SwiftFormat (writes)"
	@echo "  format-check  Run SwiftFormat in lint mode"
	@echo "  build         xcodebuild build for $(SIM) simulator"
	@echo "  test          xcodebuild test for $(SIM) simulator"
	@echo "  packages-test swift test across every SPM package"
	@echo "  ci            lint + format-check + packages-test + build + test"
	@echo "  clean         Remove generated artifacts"

bootstrap: hooks
	@which swiftlint >/dev/null   || brew install swiftlint
	@which swiftformat >/dev/null || brew install swiftformat
	@which xcodegen >/dev/null    || brew install xcodegen

hooks:
	@if [ -d .githooks ]; then \
	  git config core.hooksPath .githooks; \
	  echo "✓ git hooks path set to .githooks"; \
	else \
	  echo "(no .githooks/ yet — skipping)"; \
	fi

gen: Local.xcconfig
	xcodegen generate

# First-run shim: copy the example xcconfig into place so xcodegen has
# something to point Debug + Release at. The real file is gitignored;
# the developer fills in the Supabase keys (and later observability DSNs).
Local.xcconfig:
	@cp Local.xcconfig.example Local.xcconfig
	@echo "✓ created Local.xcconfig from Local.xcconfig.example — fill in SUPABASE_URL + ANON_KEY"

lint:
	swiftlint lint --strict

format:
	swiftformat .

format-check:
	swiftformat --lint .

build: gen
	set -o pipefail; xcodebuild \
	  -project ScorlyB.xcodeproj \
	  -scheme ScorlyB \
	  -destination 'platform=iOS Simulator,name=$(SIM)' \
	  build | tail -20

test: gen
	set -o pipefail; xcodebuild \
	  -project ScorlyB.xcodeproj \
	  -scheme ScorlyB \
	  -destination 'platform=iOS Simulator,name=$(SIM)' \
	  test | tail -30

packages-test:
	@for pkg in Packages/*/; do \
	  echo "── swift test — $$pkg"; \
	  (cd "$$pkg" && swift test --parallel) || exit 1; \
	done

ci: lint format-check packages-test build test
	@echo "✓ CI pipeline passed locally"

clean:
	rm -rf DerivedData build .build
	rm -rf Packages/*/.build Packages/*/.swiftpm
