.DEFAULT_GOAL := help

SCHEME      = Taskmato
PROJECT     = app/Taskmato.xcodeproj
DESTINATION = platform=macOS
SIGN_FLAGS  = CODE_SIGN_IDENTITY="-" CODE_SIGNING_REQUIRED=YES CODE_SIGNING_ALLOWED=YES

SOURCE_DIRS = app/Taskmato app/TaskmatoTests app/TaskmatoUITests

BUILD_DIR    = build
ARCHIVE_PATH = $(BUILD_DIR)/Taskmato.xcarchive
EXPORT_PATH  = $(BUILD_DIR)/export
VERSION      = $(shell cat version.txt | tr -d '[:space:]')
DMG_PATH     = $(BUILD_DIR)/Taskmato-$(VERSION).dmg
APP_PATH     = $(shell xcodebuild -project $(PROJECT) -scheme $(SCHEME) -configuration Debug -showBuildSettings 2>/dev/null | awk '$$1 == "BUILT_PRODUCTS_DIR" { print $$3; exit }')/$(SCHEME).app

# Developer ID signing — used for notarized distribution outside the App Store.
# SIGN_FLAGS (ad-hoc) is used for local dev builds only.
RELEASE_SIGN_FLAGS = CODE_SIGN_IDENTITY="Developer ID Application" \
                     CODE_SIGNING_REQUIRED=YES \
                     CODE_SIGNING_ALLOWED=YES \
                     DEVELOPMENT_TEAM=43757RE978

.PHONY: help sync-version build run test lint format format-check clean archive notarize release

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

run: build ## Build and launch the app (kills any running instance first)
	@pkill -x $(SCHEME) 2>/dev/null || true
	open "$(APP_PATH)"

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
	rm -rf $(BUILD_DIR)

archive: sync-version ## Archive, export, and package a Developer ID–signed DMG
	mkdir -p $(BUILD_DIR)
	xcodebuild archive \
		-project $(PROJECT) \
		-scheme $(SCHEME) \
		-configuration Release \
		-destination '$(DESTINATION)' \
		-archivePath $(ARCHIVE_PATH) \
		$(RELEASE_SIGN_FLAGS)
	xcodebuild -exportArchive \
		-archivePath $(ARCHIVE_PATH) \
		-exportPath $(EXPORT_PATH) \
		-exportOptionsPlist scripts/export-options.plist
	hdiutil create \
		-volname "Taskmato" \
		-srcfolder "$(EXPORT_PATH)/Taskmato.app" \
		-ov \
		-format UDZO \
		"$(DMG_PATH)"
	@echo "DMG ready: $(DMG_PATH)"

notarize: ## Notarize the DMG and staple the ticket (requires taskmato-notarize keychain profile)
	xcrun notarytool submit "$(DMG_PATH)" \
		--keychain-profile "taskmato-notarize" \
		--wait
	xcrun stapler staple "$(DMG_PATH)"

release: archive notarize ## Build, notarize, create a draft GitHub release with the DMG, then publish
	@if gh release view "v$(VERSION)" > /dev/null 2>&1; then \
		gh release upload "v$(VERSION)" "$(DMG_PATH)#Taskmato.dmg" --clobber; \
	else \
		gh release create "v$(VERSION)" \
			--draft \
			--title "Taskmato v$(VERSION)" \
			--generate-notes \
			"$(DMG_PATH)#Taskmato.dmg"; \
		gh release edit "v$(VERSION)" --draft=false; \
	fi
