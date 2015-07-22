export SDKVERSION=8.4
export THEOS_DEVICE_IP=192.168.1.128

include theos/makefiles/common.mk

TWEAK_NAME = Snapstress
Snapstress_FRAMEWORKS = UIKit CoreGraphics
Snapstress_FILES = main.xm
ARCHS = armv7 armv7s arm64

include $(THEOS_MAKE_PATH)/tweak.mk

after-install::
	install.exec "killall -9 Snapster"
