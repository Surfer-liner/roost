APP = Roost
BUNDLE = build/$(APP).app
BINARY = .build/release/$(APP)
DEVELOPER_DIR = $(shell xcode-select -p)
TESTING_FRAMEWORKS = $(DEVELOPER_DIR)/Library/Developer/Frameworks
TESTING_LIBS = $(DEVELOPER_DIR)/Library/Developer/usr/lib
SIGN_IDENTITY = -
CODESIGN_FLAGS = $(if $(CODESIGN_KEYCHAIN),--keychain $(CODESIGN_KEYCHAIN),)
DEV_KEYCHAIN = $(HOME)/Library/Keychains/roost-dev.keychain-db
VERSION = $(shell /usr/libexec/PlistBuddy -c "Print CFBundleShortVersionString" Resources/Info.plist)
DMG = build/Roost-$(VERSION).dmg

.PHONY: app run install dev dev-cert icon dmg test clean

app:
	swift build -c release
	rm -rf $(BUNDLE)
	mkdir -p $(BUNDLE)/Contents/MacOS $(BUNDLE)/Contents/Resources
	cp $(BINARY) $(BUNDLE)/Contents/MacOS/$(APP)
	cp Resources/Info.plist $(BUNDLE)/Contents/Info.plist
	cp Resources/Roost.icns $(BUNDLE)/Contents/Resources/Roost.icns
	codesign --force --sign "$(SIGN_IDENTITY)" $(CODESIGN_FLAGS) $(BUNDLE)

icon:
	swift run IconTool build/Roost.iconset
	iconutil -c icns build/Roost.iconset -o Resources/Roost.icns

run: app
	open $(BUNDLE)

install: app
	rm -rf /Applications/$(APP).app
	cp -R $(BUNDLE) /Applications/
	open /Applications/$(APP).app

dev-cert:
	./scripts/create-dev-cert.sh

dev:
	$(MAKE) install SIGN_IDENTITY="Roost Local Dev" CODESIGN_KEYCHAIN="$(DEV_KEYCHAIN)"

dmg: app
	rm -rf build/dmg && mkdir -p build/dmg
	cp -R $(BUNDLE) build/dmg/$(APP).app
	ln -s /Applications build/dmg/Applications
	rm -f $(DMG)
	hdiutil create -volname "$(APP)" -srcfolder build/dmg -ov -format UDZO "$(DMG)"
	rm -rf build/dmg
	@echo "Built $(DMG)"

test:
	swift test -Xswiftc -F$(TESTING_FRAMEWORKS) -Xlinker -F$(TESTING_FRAMEWORKS) -Xlinker -rpath -Xlinker $(TESTING_FRAMEWORKS) -Xlinker -rpath -Xlinker $(TESTING_LIBS)

clean:
	rm -rf .build build
