ARCHS = arm64 arm64e
TARGET = iphone:latest:13.0
INSTALL_TARGET_PROCESSES = SpringBoard

TARGET_CODESIGN = ldid
CODESIGN = ldid

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = MatrixAegisLite
MatrixAegisLite_FILES = $(wildcard src/*.m) Tweak.xm
MatrixAegisLite_FRAMEWORKS = UIKit Foundation Security
MatrixAegisLite_CFLAGS = -fobjc-arc -Wno-deprecated-declarations -Iinclude
MatrixAegisLite_LDFLAGS = -lsubstrate

include $(THEOS_MAKE_PATH)/tweak.mk

after-install::
	install.exec "killall -9 SpringBoard"
