/*
 * Copyright 2006, 2007, 2008, 2009, 2010, 2011 Apple Inc. All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 *
 * 1.  Redistributions of source code must retain the above copyright
 *     notice, this list of conditions and the following disclaimer. 
 * 2.  Redistributions in binary form must reproduce the above copyright
 *     notice, this list of conditions and the following disclaimer in the
 *     documentation and/or other materials provided with the distribution. 
 * 3.  Neither the name of Apple Inc. ("Apple") nor the names of
 *     its contributors may be used to endorse or promote products derived
 *     from this software without specific prior written permission. 
 *
 * THIS SOFTWARE IS PROVIDED BY APPLE AND ITS CONTRIBUTORS "AS IS" AND ANY
 * EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
 * WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
 * DISCLAIMED. IN NO EVENT SHALL APPLE OR ITS CONTRIBUTORS BE LIABLE FOR ANY
 * DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
 * (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
 * LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
 * ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
 * (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF
 * THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

#import "WebSystemInterface.h"

// Needed for builds not using PCH to expose BUILDING_ macros, see bug 32753.
#include <wtf/Platform.h>

#import <WebCore/WebCoreSystemInterface.h>
#import <WebKitSystemInterface.h>

#define INIT(function) wk##function = WK##function

void InitWebCoreSystemInterface(void)
{
    static bool didInit;
    if (didInit)
        return;

#if __MAC_OS_X_VERSION_MIN_REQUIRED >= 1070
    INIT(CALayerEnumerateRectsBeingDrawnWithBlock);
#endif
#if !PLATFORM(IOS)
    INIT(CGContextGetShouldSmoothFonts);
#endif
    INIT(CGPatternCreateWithImageAndTransform);
    INIT(CGContextResetClip);
#if !PLATFORM(IOS) && __MAC_OS_X_VERSION_MIN_REQUIRED >= 1080
    INIT(CGContextDrawsWithCorrectShadowOffsets);
#endif
    INIT(CopyCFLocalizationPreferredName);
    INIT(CopyCONNECTProxyResponse);
    INIT(CopyNSURLResponseStatusLine);
#if __MAC_OS_X_VERSION_MIN_REQUIRED >= 1060
    INIT(CopyNSURLResponseCertificateChain);
#endif
    INIT(CreateCustomCFReadStream);
#if !PLATFORM(IOS)
    INIT(DrawCapsLockIndicator);
    INIT(DrawBezeledTextArea);
    INIT(DrawBezeledTextFieldCell);
    INIT(DrawFocusRing);
#if __MAC_OS_X_VERSION_MIN_REQUIRED >= 1080
    INIT(DrawFocusRingAtTime);
    INIT(DrawCellFocusRingWithFrameAtTime);
#endif
    INIT(DrawMediaUIPart);
    INIT(DrawMediaSliderTrack);
    INIT(DrawTextFieldCellFocusRing);
    INIT(GetExtensionsForMIMEType);
    INIT(GetFontInLanguageForCharacter);
    INIT(GetFontInLanguageForRange);
    INIT(GetGlyphTransformedAdvances);
#endif
#if PLATFORM(IOS) || __MAC_OS_X_VERSION_MIN_REQUIRED >= 1070
    INIT(GetHTTPRequestPriority);
#endif
    INIT(GetMIMETypeForExtension);
    INIT(GetNSURLResponseLastModifiedDate);
    INIT(GetWebDefaultCFStringEncoding);
#if !PLATFORM(IOS)
    INIT(GetPreferredExtensionForMIMEType);
    INIT(GetWheelEventDeltas);
#if __MAC_OS_X_VERSION_MIN_REQUIRED >= 1060
    INIT(GetNSEventKeyChar);
#endif
    INIT(HitTestMediaUIPart);
#endif
    INIT(InitializeMaximumHTTPConnectionCountPerHost);
#if !PLATFORM(IOS)
    INIT(MeasureMediaUIPart);
    INIT(CreateMediaUIBackgroundView);
    INIT(CreateMediaUIControl);
    INIT(WindowSetAlpha);
    INIT(WindowSetScaledFrame);
#if __MAC_OS_X_VERSION_MIN_REQUIRED <= 1060
    INIT(MediaControllerThemeAvailable);
#endif
    INIT(PopupMenu);
    INIT(SetCGFontRenderingMode);
#endif
    INIT(SetBaseCTM);
    INIT(SetCONNECTProxyAuthorizationForStream);
    INIT(SetCONNECTProxyForStream);
#if !PLATFORM(IOS)
    INIT(SetDragImage);
#endif
#if PLATFORM(IOS) || __MAC_OS_X_VERSION_MIN_REQUIRED >= 1070
    INIT(SetHTTPRequestMaximumPriority);
    INIT(SetHTTPRequestPriority);
    INIT(SetHTTPRequestMinimumFastLanePriority);
    INIT(HTTPRequestEnablePipelining);
#endif
    INIT(SetNSURLConnectionDefersCallbacks);
    INIT(SetNSURLRequestShouldContentSniff);
    INIT(SetPatternPhaseInUserSpace);
#if __MAC_OS_X_VERSION_MIN_REQUIRED >= 1070
    INIT(CGContextIsPDFContext);
#endif
    INIT(GetUserToBaseCTM);
    INIT(SetUpFontCache);
    INIT(SignalCFReadStreamEnd);
    INIT(SignalCFReadStreamError);
    INIT(SignalCFReadStreamHasBytes);
#if ENABLE(VIDEO) && !PLATFORM(IOS)
    INIT(QTIncludeOnlyModernMediaFileTypes);
    INIT(QTMovieDataRate);
    INIT(QTMovieDisableComponent);
    INIT(QTMovieMaxTimeLoaded);
    INIT(QTMovieMaxTimeLoadedChangeNotification);
    INIT(QTMovieMaxTimeSeekable);
    INIT(QTMovieGetType);
    INIT(QTMovieHasClosedCaptions);
    INIT(QTMovieResolvedURL);
    INIT(QTMovieSetShowClosedCaptions);
    INIT(QTMovieSelectPreferredAlternates);
    INIT(QTMovieViewSetDrawSynchronously);
    INIT(QTGetSitesInMediaDownloadCache);
    INIT(QTClearMediaDownloadCacheForSite);
    INIT(QTClearMediaDownloadCache);
#endif

#if !PLATFORM(IOS)
    INIT(GetGlyphsForCharacters);
#endif
    INIT(GetVerticalGlyphsForCharacters);
#if PLATFORM(IOS)
    INIT(ExecutableWasLinkedOnOrAfterIOSVersion);
    INIT(GetDeviceClass);
    INIT(GetScreenSize);
    INIT(GetAvailableScreenSize);
    INIT(GetScreenScaleFactor);
    INIT(IsGB18030ComplianceRequired);
    INIT(IsOptimizedFullscreenSupported);
#endif

#if __MAC_OS_X_VERSION_MIN_REQUIRED <= 1060
    INIT(GetHyphenationLocationBeforeIndex);
    INIT(GetNSEventMomentumPhase);
#endif

    INIT(CreateCTLineWithUniCharProvider);

#if !PLATFORM(IOS) && __MAC_OS_X_VERSION_MIN_REQUIRED >= 1070
    INIT(ExecutableWasLinkedOnOrBeforeSnowLeopard);
    INIT(CopyDefaultSearchProviderDisplayName);
    INIT(Cursor);
#endif

#if USE(CFNETWORK)
    INIT(GetDefaultHTTPCookieStorage);
    INIT(CopyCredentialFromCFPersistentStorage);
    INIT(SetCFURLRequestShouldContentSniff);
    INIT(SetRequestStorageSession);
#endif

#if !PLATFORM(IOS)
#if __MAC_OS_X_VERSION_MIN_REQUIRED >= 1070
    INIT(SpeechSynthesisGetVoiceIdentifiers);
    INIT(SpeechSynthesisGetDefaultVoiceIdentifierForLocale);
#endif
    INIT(GetAXTextMarkerTypeID);
    INIT(GetAXTextMarkerRangeTypeID);
    INIT(CreateAXTextMarker);
    INIT(GetBytesFromAXTextMarker);
    INIT(CreateAXTextMarkerRange);
    INIT(CopyAXTextMarkerRangeStart);
    INIT(CopyAXTextMarkerRangeEnd);
    INIT(AccessibilityHandleFocusChanged);
    INIT(CreateAXUIElementRef);
    INIT(UnregisterUniqueIdForElement);
#endif
    INIT(CreatePrivateStorageSession);
    INIT(CopyRequestWithStorageSession);
    INIT(CopyHTTPCookieStorage);
    INIT(GetHTTPCookieAcceptPolicy);
#if __MAC_OS_X_VERSION_MIN_REQUIRED >= 1070
    INIT(HTTPCookies);
#endif
    INIT(HTTPCookiesForURL);
    INIT(SetHTTPCookiesForURL);
#if __MAC_OS_X_VERSION_MIN_REQUIRED >= 1070
    INIT(DeleteAllHTTPCookies);
#endif
    INIT(DeleteHTTPCookie);

    INIT(GetCFURLResponseMIMEType);
    INIT(GetCFURLResponseURL);
    INIT(GetCFURLResponseHTTPResponse);
    INIT(CopyCFURLResponseSuggestedFilename);
    INIT(SetCFURLResponseMIMEType);

#if !PLATFORM(IOS)
    INIT(SetMetadataURL);
#endif

#if PLATFORM(IOS) || __MAC_OS_X_VERSION_MIN_REQUIRED >= 1070
    INIT(CFURLRequestAllowAllPostCaching);
#endif

#if PLATFORM(IOS)
    INIT(GetUserAgent);
    INIT(GetDeviceName);
    INIT(GetOSNameForUserAgent);
    INIT(GetPlatformNameForNavigator);
    INIT(GetVendorNameForNavigator);
#endif

#if !PLATFORM(IOS) && __MAC_OS_X_VERSION_MIN_REQUIRED >= 1080
    INIT(NSElasticDeltaForTimeDelta);
    INIT(NSElasticDeltaForReboundDelta);
    INIT(NSReboundDeltaForElasticDelta);
#endif

#if ENABLE(PUBLIC_SUFFIX_LIST)
    INIT(IsPublicSuffix);
#endif

#if PLATFORM(IOS) || __MAC_OS_X_VERSION_MIN_REQUIRED >= 10100
    INIT(CachePartitionKey);
#endif

#if PLATFORM(IOS) || __MAC_OS_X_VERSION_MIN_REQUIRED >= 1080
    INIT(ExernalDeviceTypeForPlayer);
    INIT(ExernalDeviceDisplayNameForPlayer);

    INIT(QueryDecoderAvailability);
#endif

    didInit = true;
}
