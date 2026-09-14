APP = Roost
BUNDLE = build/$(APP).app
BINARY = .build/release/$(APP)
DEVELOPER_DIR = $(shell xcode-select -p)
TESTING_FRAMEWORKS = $(DEVELOPER_DIR)/Library/Developer/Frameworks
TESTING_LIBS = $(DEVELOPER_DIR)/Library/Developer/usr/lib

.PHONY: app run install test selftest clean

app:
	swift build -c release
	rm -rf $(BUNDLE)
	mkdir -p $(BUNDLE)/Contents/MacOS
	cp $(BINARY) $(BUNDLE)/Contents/MacOS/$(APP)
	cp Resources/Info.plist $(BUNDLE)/Contents/Info.plist
	codesign --force --sign - $(BUNDLE)

run: app
	open $(BUNDLE)

install: app
	rm -rf /Applications/$(APP).app
	cp -R $(BUNDLE) /Applications/
	open /Applications/$(APP).app

test:
	swift test -Xswiftc -F$(TESTING_FRAMEWORKS) -Xlinker -F$(TESTING_FRAMEWORKS) -Xlinker -rpath -Xlinker $(TESTING_FRAMEWORKS) -Xlinker -rpath -Xlinker $(TESTING_LIBS)

selftest: install
	open -n -W /Applications/$(APP).app --args --selftest /tmp/roost-selftest.txt
	cat /tmp/roost-selftest.txt

clean:
	rm -rf .build build
