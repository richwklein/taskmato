.DEFAULT_GOAL := help

SCHEME      = Taskmato
PROJECT     = app/Taskmato.xcodeproj
DESTINATION = platform=macOS
SIGN_FLAGS  = CODE_SIGN_IDENTITY="-" CODE_SIGNING_REQUIRED=YES CODE_SIGNING_ALLOWED=YES

SOURCE_DIRS = app/Taskmato app/TaskmatoTests app/TaskmatoUITests

.PHONY: help sync-version build test lint format clean

help: ## List the available commands
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-30s\033[0m %s\n", $$1, $$2}'

sync-version: ## Sync version.txt into app/Taskmato/Config/Version.xcconfig
	bash scripts/sync-version.sh

build: sync-version ## Build the app in Debug configuration
	xcodebuild build \
		-project $(PROJECT) \
		-scheme $(SCHEME) \
		-configuration Debug \
		-destination '$(DESTINATION)' \
		$(SIGN_FLAGS)

test: ## Run the unit test suite
	xcodebuild test \
		-project $(PROJECT) \
		-scheme $(SCHEME) \
		-destination '$(DESTINATION)' \
		-enableCodeCoverage YES \
		$(SIGN_FLAGS)

lint: ## Check for SwiftLint violations
	swiftlint lint --strict

format: ## Format source files in-place with swift-format
	xcrun swift-format format --recursive -i $(SOURCE_DIRS)

format-check: ## Verify formatting without modifying files (used in CI)
	xcrun swift-format lint --recursive --strict $(SOURCE_DIRS)

clean: ## Remove build artifacts
	xcodebuild clean \
		-project $(PROJECT) \
		-scheme $(SCHEME)
