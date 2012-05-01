include theos/makefiles/common.mk

TWEAK_NAME = HistoryEnhancer
HistoryEnhancer_FILES = Tweak.xm
HistoryEnhancer_FRAMEWORKS = UIKit

include $(THEOS_MAKE_PATH)/tweak.mk

after-stage::
	$(ECHO_NOTHING)mkdir -p $(THEOS_STAGING_DIR)/Library/PreferenceLoader/Preferences$(ECHO_END)
	$(ECHO_NOTHING)cp HEPreferences.plist $(THEOS_STAGING_DIR)/Library/PreferenceLoader/Preferences/HEPreferences.plist$(ECHO_END)
	$(ECHO_NOTHING)cp icon.png $(THEOS_STAGING_DIR)/Library/PreferenceLoader/Preferences/HistoryEnhancer.png$(ECHO_END)