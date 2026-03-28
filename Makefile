BINARY_NAME = Tunnel
APP_NAME = Buu SSH Tunnels
BUILD_DIR = .build/release
APP_BUNDLE = $(APP_NAME).app

.PHONY: build run clean test install zip

build:
	swift build -c release
	mkdir -p "$(APP_BUNDLE)/Contents/MacOS"
	mkdir -p "$(APP_BUNDLE)/Contents/Resources"
	cp "$(BUILD_DIR)/$(BINARY_NAME)" "$(APP_BUNDLE)/Contents/MacOS/$(BINARY_NAME)"
	cp Resources/Info.plist "$(APP_BUNDLE)/Contents/"
	cp Resources/AppIcon.icns "$(APP_BUNDLE)/Contents/Resources/"

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

zip: build
	zip -r "$(APP_NAME).zip" "$(APP_BUNDLE)"
