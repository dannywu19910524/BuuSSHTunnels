APP_NAME = Tunnel
BUILD_DIR = .build/release
APP_BUNDLE = $(APP_NAME).app

.PHONY: build run clean test install

build:
	swift build -c release
	mkdir -p "$(APP_BUNDLE)/Contents/MacOS"
	mkdir -p "$(APP_BUNDLE)/Contents/Resources"
	cp "$(BUILD_DIR)/$(APP_NAME)" "$(APP_BUNDLE)/Contents/MacOS/"
	cp Resources/Info.plist "$(APP_BUNDLE)/Contents/"

run: build
	open "$(APP_BUNDLE)"

dev:
	swift run

test:
	swift test

clean:
	swift package clean
	rm -rf "$(APP_BUNDLE)"

install: build
	cp -r "$(APP_BUNDLE)" /Applications/
	@echo "Installed to /Applications/$(APP_BUNDLE)"
