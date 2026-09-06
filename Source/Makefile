MODULES = bmalloc WTF JavaScriptCore ThirdParty/ANGLE ThirdParty/brotli ThirdParty/woff2 ThirdParty/lz4 ThirdParty/ots ThirdParty/libwebrtc WebCore WebInspectorUI WebKitLegacy WebKit2

ifneq (,$(SDKROOT))
	ifeq (,$(findstring macosx,$(SDKROOT)))
		MODULES = bmalloc WTF JavaScriptCore ThirdParty/ANGLE ThirdParty/brotli ThirdParty/woff2 ThirdParty/lz4 ThirdParty/ots ThirdParty/libwebrtc WebCore WebKitLegacy WebKit2
	endif
endif

all:
	@for dir in $(MODULES); do ${MAKE} $@ -C $$dir; exit_status=$$?; \
	if [ $$exit_status -ne 0 ]; then exit $$exit_status; fi; done

debug d:
	@for dir in $(MODULES); do ${MAKE} $@ -C $$dir; exit_status=$$?; \
	if [ $$exit_status -ne 0 ]; then exit $$exit_status; fi; done

release r:
	@for dir in $(MODULES); do ${MAKE} $@ -C $$dir; exit_status=$$?; \
	if [ $$exit_status -ne 0 ]; then exit $$exit_status; fi; done

analyze:
	@for dir in $(MODULES); do ${MAKE} $@ -C $$dir; exit_status=$$?; \
	if [ $$exit_status -ne 0 ]; then exit $$exit_status; fi; done

clean:
	@for dir in $(MODULES); do ${MAKE} $@ -C $$dir; exit_status=$$?; \
	if [ $$exit_status -ne 0 ]; then exit $$exit_status; fi; done
