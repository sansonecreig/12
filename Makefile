ARCHS = arm64 arm64e
TARGET = iphone:latest:13.0
INSTALL_TARGET_PROCESSES = SpringBoard

TARGET_CODESIGN = ldid
CODESIGN = ldid
ADDITIONAL_CODESIGN_FLAGS = -Sentitlements.plist

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = MatrixNebulaAegis
MatrixNebulaAegis_FILES = $(wildcard src/*.m) Tweak.xm
MatrixNebulaAegis_FRAMEWORKS = UIKit Foundation Security CoreGraphics CoreImage Network
MatrixNebulaAegis_CFLAGS = -fobjc-arc -Wno-deprecated-declarations -Iinclude
MatrixNebulaAegis_LDFLAGS = -lsubstrate

include $(THEOS_MAKE_PATH)/tweak.mk

after-install::
	install.exec "killall -9 SpringBoard"
