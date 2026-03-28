SCHEME = PRDaemon
PROJECT = PRDaemon.xcodeproj
CONFIG = Debug
BUILD_DIR = $(shell xcodebuild -project $(PROJECT) -scheme $(SCHEME) -showBuildSettings 2>/dev/null | grep -m1 'BUILT_PRODUCTS_DIR' | awk '{print $$3}')
APP_NAME = PR Daemon

.PHONY: generate build run clean

generate:
	xcodegen generate

build: generate
	xcodebuild -project $(PROJECT) -scheme $(SCHEME) -configuration $(CONFIG) build CODE_SIGNING_ALLOWED=NO
	codesign --deep --force --sign - "$(BUILD_DIR)/$(APP_NAME).app"

run: build
	-pkill -x "$(APP_NAME)" 2>/dev/null || true
	open "$(BUILD_DIR)/$(APP_NAME).app"

clean:
	xcodebuild -project $(PROJECT) -scheme $(SCHEME) clean
	rm -rf DerivedData
