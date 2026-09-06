/*
 * Copyright (C) 2014-2016 Apple Inc.  All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 * 1. Redistributions of source code must retain the above copyright
 *    notice, this list of conditions and the following disclaimer.
 * 2. Redistributions in binary form must reproduce the above copyright
 *    notice, this list of conditions and the following disclaimer in the
 *    documentation and/or other materials provided with the distribution.
 *
 * THIS SOFTWARE IS PROVIDED BY APPLE INC. ``AS IS'' AND ANY
 * EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 * IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR
 * PURPOSE ARE DISCLAIMED.  IN NO EVENT SHALL APPLE INC. OR
 * CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL,
 * EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO,
 * PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR
 * PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY
 * OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
 * (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
 * OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE. 
 */

#ifndef CoreTextSPI_h
#define CoreTextSPI_h

#include "CoreGraphicsSPI.h"
#include <CoreText/CoreText.h>

#if USE(APPLE_INTERNAL_SDK)

#include <CoreText/CoreTextPriv.h>

#else

enum {
#if PLATFORM(MAC) && __MAC_OS_X_VERSION_MIN_REQUIRED <= 1070
    kCTFontUIFontNone = kCTFontNoFontType,
    kCTFontUIFontUser = kCTFontUserFontType,
    kCTFontUIFontUserFixedPitch = kCTFontUserFixedPitchFontType,
    kCTFontUIFontSystem = kCTFontSystemFontType,
    kCTFontUIFontEmphasizedSystem = kCTFontEmphasizedSystemFontType,
    kCTFontUIFontSmallSystem = kCTFontSmallSystemFontType,
    kCTFontUIFontSmallEmphasizedSystem = kCTFontSmallEmphasizedSystemFontType,
    kCTFontUIFontMiniSystem = kCTFontMiniSystemFontType,
    kCTFontUIFontMiniEmphasizedSystem = kCTFontMiniEmphasizedSystemFontType,
    kCTFontUIFontViews = kCTFontViewsFontType,
    kCTFontUIFontApplication = kCTFontApplicationFontType,
    kCTFontUIFontLabel = kCTFontLabelFontType,
    kCTFontUIFontMenuTitle = kCTFontMenuTitleFontType,
    kCTFontUIFontMenuItem = kCTFontMenuItemFontType,
    kCTFontUIFontMenuItemMark = kCTFontMenuItemMarkFontType,
    kCTFontUIFontMenuItemCmdKey = kCTFontMenuItemCmdKeyFontType,
    kCTFontUIFontWindowTitle = kCTFontWindowTitleFontType,
    kCTFontUIFontPushButton = kCTFontPushButtonFontType,
    kCTFontUIFontUtilityWindowTitle = kCTFontUtilityWindowTitleFontType,
    kCTFontUIFontAlertHeader = kCTFontAlertHeaderFontType,
    kCTFontUIFontSystemDetail = kCTFontSystemDetailFontType,
    kCTFontUIFontEmphasizedSystemDetail = kCTFontEmphasizedSystemDetailFontType,
    kCTFontUIFontToolbar = kCTFontToolbarFontType,
    kCTFontUIFontSmallToolbar = kCTFontSmallToolbarFontType,
    kCTFontUIFontMessage = kCTFontMessageFontType,
    kCTFontUIFontPalette = kCTFontPaletteFontType,
    kCTFontUIFontToolTip = kCTFontToolTipFontType,
    kCTFontUIFontControlContent = kCTFontControlContentFontType,
#endif
    kCTFontUIFontSystemItalic = 27,
    kCTFontUIFontSystemThin = 102,
    kCTFontUIFontSystemLight = 103,
    kCTFontUIFontSystemUltraLight = 104,
};

#if PLATFORM(MAC) && __MAC_OS_X_VERSION_MIN_REQUIRED <= 1070
enum {
    kCTFontOrientationDefault = kCTFontDefaultOrientation,
    kCTFontOrientationHorizontal = kCTFontHorizontalOrientation,
    kCTFontOrientationVertical = kCTFontVerticalOrientation,
};

enum {
    kCTFontTraitItalic = kCTFontItalicTrait,
    kCTFontTraitBold = kCTFontBoldTrait,
    kCTFontTraitExpanded = kCTFontExpandedTrait,
    kCTFontTraitCondensed = kCTFontCondensedTrait,
    kCTFontTraitMonoSpace = kCTFontMonoSpaceTrait,
    kCTFontTraitVertical = kCTFontVerticalTrait,
    kCTFontTraitUIOptimized = kCTFontUIOptimizedTrait,
    kCTFontTraitClassMask = kCTFontClassMaskTrait,
};
#endif

typedef CF_OPTIONS(uint32_t, CTFontTransformOptions)
{
    kCTFontTransformApplyShaping = (1 << 0),
    kCTFontTransformApplyPositioning = (1 << 1)
};

#ifndef kCTFontOptionsPreferSystemFont
#define kCTFontOptionsPreferSystemFont (1 << 2)
#endif
typedef CF_OPTIONS(uint32_t, CTFontDescriptorOptions)
{
    kCTFontDescriptorOptionSystemUIFont = 1 << 1,
    kCTFontDescriptorOptionPreferAppleSystemFont = kCTFontOptionsPreferSystemFont
};

enum {
    kCTRunStatusHasOrigins = (1 << 4),
};

#endif

WTF_EXTERN_C_BEGIN

typedef const UniChar* (*CTUniCharProviderCallback)(CFIndex stringIndex, CFIndex* charCount, CFDictionaryRef* attributes, void* refCon);
typedef void (*CTUniCharDisposeCallback)(const UniChar* chars, void* refCon);

extern const CFStringRef kCTFontReferenceURLAttribute;
extern const CFStringRef kCTFontOpticalSizeAttribute;
extern const CFStringRef kCTFontPostScriptNameAttribute;

bool CTFontTransformGlyphs(CTFontRef, CGGlyph glyphs[], CGSize advances[], CFIndex count, CTFontTransformOptions);

CGSize CTRunGetInitialAdvance(CTRunRef run);
CTLineRef CTLineCreateWithUniCharProvider(CTUniCharProviderCallback provide, CTUniCharDisposeCallback dispose, void* refCon);
void CTRunGetBaseAdvancesAndOrigins(CTRunRef, CFRange, CGSize baseAdvances[], CGPoint origins[]);
CTTypesetterRef CTTypesetterCreateWithUniCharProviderAndOptions(CTUniCharProviderCallback provide, CTUniCharDisposeCallback dispose, void* refCon, CFDictionaryRef options);
bool CTFontGetVerticalGlyphsForCharacters(CTFontRef, const UniChar characters[], CGGlyph glyphs[], CFIndex count);
void CTFontGetUnsummedAdvancesForGlyphsAndStyle(CTFontRef, CTFontOrientation, CGFontRenderingStyle, const CGGlyph[], CGSize advances[], CFIndex count);

CFArrayRef CTFontDescriptorCopyAvailableFontFamilyNames(CFArrayRef fontDescriptors);
CTFontDescriptorRef CTFontDescriptorCreateForUIType(CTFontUIFontType, CGFloat size, CFStringRef language);
CTFontDescriptorRef CTFontDescriptorCreateWithTextStyle(CFStringRef style, CFStringRef size, CFStringRef language);
CTFontDescriptorRef CTFontDescriptorCreateCopyWithSymbolicTraits(CTFontDescriptorRef original, CTFontSymbolicTraits symTraitValue, CTFontSymbolicTraits symTraitMask);
CFBitVectorRef CTFontCopyGlyphCoverageForFeature(CTFontRef, CFDictionaryRef feature);

CTFontDescriptorRef CTFontDescriptorCreateWithAttributesAndOptions(CFDictionaryRef attributes, CTFontDescriptorOptions);
CTFontDescriptorRef CTFontDescriptorCreateLastResort();

extern const CFStringRef kCTFontCSSWeightAttribute;
extern const CFStringRef kCTFontCSSWidthAttribute;
extern const CFStringRef kCTFontDescriptorTextStyleAttribute;
extern const CFStringRef kCTFontUIFontDesignTrait;

extern const CFStringRef kCTFrameMaximumNumberOfLinesAttributeName;

bool CTFontDescriptorIsSystemUIFont(CTFontDescriptorRef);
CTFontRef CTFontCreateForCSS(CFStringRef name, uint16_t weight, CTFontSymbolicTraits, CGFloat size);
CTFontRef CTFontCreateForCharactersWithLanguage(CTFontRef currentFont, const UTF16Char *characters, CFIndex length, CFStringRef language, CFIndex *coveredLength);

#if PLATFORM(IOS) || __MAC_OS_X_VERSION_MIN_REQUIRED >= 101000
extern const CFStringRef kCTUIFontTextStyleShortHeadline;
extern const CFStringRef kCTUIFontTextStyleShortBody;
extern const CFStringRef kCTUIFontTextStyleShortSubhead;
extern const CFStringRef kCTUIFontTextStyleShortFootnote;
extern const CFStringRef kCTUIFontTextStyleShortCaption1;
extern const CFStringRef kCTUIFontTextStyleTallBody;

extern const CFStringRef kCTUIFontTextStyleHeadline;
extern const CFStringRef kCTUIFontTextStyleBody;
extern const CFStringRef kCTUIFontTextStyleSubhead;
extern const CFStringRef kCTUIFontTextStyleFootnote;
extern const CFStringRef kCTUIFontTextStyleCaption1;
extern const CFStringRef kCTUIFontTextStyleCaption2;

extern const CFStringRef kCTFontDescriptorTextStyleEmphasized;

extern const CGFloat kCTFontWeightUltraLight;
extern const CGFloat kCTFontWeightThin;
extern const CGFloat kCTFontWeightLight;
extern const CGFloat kCTFontWeightRegular;
extern const CGFloat kCTFontWeightMedium;
extern const CGFloat kCTFontWeightSemibold;
extern const CGFloat kCTFontWeightBold;
extern const CGFloat kCTFontWeightHeavy;
extern const CGFloat kCTFontWeightBlack;
#endif

#if PLATFORM(IOS) || __MAC_OS_X_VERSION_MIN_REQUIRED >= 101000
extern const CFStringRef kCTUIFontTextStyleTitle0;
extern const CFStringRef kCTUIFontTextStyleTitle1;
extern const CFStringRef kCTUIFontTextStyleTitle2;
extern const CFStringRef kCTUIFontTextStyleTitle3;
extern const CFStringRef kCTUIFontTextStyleTitle4;
CTFontDescriptorRef CTFontCreatePhysicalFontDescriptorForCharactersWithLanguage(CTFontRef currentFont, const UTF16Char* characters, CFIndex length, CFStringRef language, CFIndex* coveredLength);
__attribute__((availability(macosx,obsoleted=10.13))) __attribute__((availability(ios,obsoleted=11.0))) CTFontRef CTFontCreatePhysicalFontForCharactersWithLanguage(CTFontRef, const UTF16Char* characters, CFIndex length, CFStringRef language, CFIndex* coveredLength);
#endif

bool CTFontIsAppleColorEmoji(CTFontRef);
CTFontRef CTFontCreateForCharacters(CTFontRef currentFont, const UTF16Char *characters, CFIndex length, CFIndex *coveredLength);

#if PLATFORM(MAC) && __MAC_OS_X_VERSION_MIN_REQUIRED == 1050
CGSize CTFramesetterSuggestFrameSizeWithConstraints(CTFramesetterRef framesetter, CFRange stringRange, CFDictionaryRef frameAttributes, CGSize constraints, CFRange *fitRange);

void CTRunGetAdvances(CTRunRef run, CFRange range, CGSize buffer[]);
const CGSize* CTRunGetAdvancesPtr(CTRunRef run);
extern const CFStringRef kCTTypesetterOptionForcedEmbeddingLevel;

#define kCTFontFileURLAttribute CFSTR("NSCTFontFileURLAttribute")
#define kCTFontURLAttribute kCTFontFileURLAttribute

extern const CFStringRef kCTForegroundColorFromContextAttributeName;
#endif

WTF_EXTERN_C_END

#endif
