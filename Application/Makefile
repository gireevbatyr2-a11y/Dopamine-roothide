.PHONY: all clean build_clean

APP_VERSION := $(shell cat ../BaseBin/_external/basebin/.version)-$(shell cat ../BaseBin/_external/basebin/.version-roothide)
FORK_SHA := $(shell git rev-parse --short HEAD 2>/dev/null)

all: FFKRW.ipa

FFKRW.ipa: build/Build/Products/Debug-iphoneos/FFKRW.app
	@echo Ad-Hoc signing FFKRW
	xattr -rc build/Build/Products/Debug-iphoneos/FFKRW.app
	ldid -SDopamine/Dopamine.entitlements build/Build/Products/Debug-iphoneos/FFKRW.app/FFKRW
	ldid -s build/Build/Products/Debug-iphoneos/FFKRW.app
	rm -rf Payload FFKRW.ipa
	mkdir Payload
	cp -r build/Build/Products/Debug-iphoneos/FFKRW.app Payload/FFKRW.app
	zip -Ar FFKRW.ipa Payload
	rm -rf Payload
	rm -rf FFKRW.tipa
	cp FFKRW.ipa FFKRW.tipa
	mv FFKRW.ipa FFKRW-roothide-"$(APP_VERSION)".ipa
	mv FFKRW.tipa FFKRW-roothide-"$(APP_VERSION)".tipa

ifeq ($(NIGHTLY), 1)
build/Build/Products/Debug-iphoneos/FFKRW.app: FORCE
	xcodebuild -scheme Dopamine -derivedDataPath build -destination 'generic/platform=iOS' CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO GCC_PREPROCESSOR_DEFINITIONS='NIGHTLY=1 COMMIT_HASH=\"$(COMMIT_HASH)\"'
else
build/Build/Products/Debug-iphoneos/FFKRW.app: FORCE
	xcodebuild -scheme Dopamine -derivedDataPath build -destination 'generic/platform=iOS' CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO
endif
	touch build/Build/Products/Debug-iphoneos/FFKRW.app/FFKRW.roothide
	cp -a Dopamine/Resources/*.deb build/Build/Products/Debug-iphoneos/FFKRW.app/ 2>/dev/null || true
	cp ../BaseBin/.build/libroothider.dylib build/Build/Products/Debug-iphoneos/FFKRW.app/
	plutil -replace CFBundleIdentifier -string "com.ffkrw.FFKRW" build/Build/Products/Debug-iphoneos/FFKRW.app/Info.plist
	plutil -replace CFBundleDisplayName -string "FFKRW" build/Build/Products/Debug-iphoneos/FFKRW.app/Info.plist
	plutil -replace CFBundleName -string "FFKRW" build/Build/Products/Debug-iphoneos/FFKRW.app/Info.plist
	plutil -replace CFBundleShortVersionString -string "$(APP_VERSION)" build/Build/Products/Debug-iphoneos/FFKRW.app/Info.plist
# ifeq ($(PALEHIDE), 1)
	make -C Dopamine/Exploits/palera1n package
	cp -a Dopamine/Exploits/palera1n/.framework build/Build/Products/Debug-iphoneos/FFKRW.app/Frameworks/palera1n.framework
# endif


clean:
	make -C Dopamine/Exploits/palera1n clean
	rm -rf build Payload FFKRW.ipa FFKRW.tipa

build_clean:
	rm -rf Payload build

FORCE: ;