ARCHS = arm64 arm64e
TARGET = iphone:latest:13.0
INSTALL_TARGET_PROCESSES = SpringBoard

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = MatrixAegisLite
MatrixAegisLite_FILES = $(wildcard src/*.m) src/fishhook.c Tweak.xm
MatrixAegisLite_FRAMEWORKS = UIKit Foundation Security CoreGraphics WebKit
MatrixAegisLite_CFLAGS = -fobjc-arc -Wno-deprecated-declarations -I$(PWD)/include

include $(THEOS_MAKE_PATH)/tweak.mk

after-install::
	install.exec "killall -9 SpringBoard"
