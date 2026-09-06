/*
 * This file is part of the internal font implementation.
 *
 * Copyright (C) 2006, 2007, 2008, 2009, 2010 Apple Inc. All rights reserved.
 * Copyright (c) 2010 Google Inc. All rights reserved.
 *
 * This library is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Library General Public
 * License as published by the Free Software Foundation; either
 * version 2 of the License, or (at your option) any later version.
 *
 * This library is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 * Library General Public License for more details.
 *
 * You should have received a copy of the GNU Library General Public License
 * along with this library; see the file COPYING.LIB.  If not, write to
 * the Free Software Foundation, Inc., 51 Franklin Street, Fifth Floor,
 * Boston, MA 02110-1301, USA.
 *
 */

#import "config.h"
#import "FontPlatformData.h"

#import "CoreTextSPI.h"
#import "NSFontSPI.h"
#import "SharedBuffer.h"
#import "WebCoreSystemInterface.h"
#import <wtf/text/WTFString.h>

#if PLATFORM(IOS)
#import "CoreGraphicsSPI.h"
#import <CoreText/CoreText.h>
#endif

#if PLATFORM(MAC) && __MAC_OS_X_VERSION_MIN_REQUIRED == 1050
#include "FontCustomPlatformData.h"
#include <ATS/ATSFont.h>
#endif

namespace WebCore {

// These CoreText Text Spacing feature selectors are not defined in CoreText.
enum TextSpacingCTFeatureSelector { TextSpacingProportional, TextSpacingFullWidth, TextSpacingHalfWidth, TextSpacingThirdWidth, TextSpacingQuarterWidth };

#if PLATFORM(MAC) && __MAC_OS_X_VERSION_MIN_REQUIRED == 1050
FontPlatformData::FontPlatformData(CTFontRef font, RefPtr<ATSFontContainerRefWrapper> atsContainer, float size, bool syntheticBold, bool syntheticOblique, FontOrientation orientation, FontWidthVariant widthVariant, TextRenderingMode textRenderingMode)
    : FontPlatformData(font, size, syntheticBold, syntheticOblique, orientation, widthVariant, textRenderingMode)
{
    m_atsContainer = atsContainer;
}
#endif

FontPlatformData::FontPlatformData(CTFontRef font, float size, bool syntheticBold, bool syntheticOblique, FontOrientation orientation, FontWidthVariant widthVariant, TextRenderingMode textRenderingMode)
#if PLATFORM(MAC) && __MAC_OS_X_VERSION_MIN_REQUIRED == 1050
    : FontPlatformData(size, syntheticBold, syntheticOblique, orientation, widthVariant, textRenderingMode)
#elif  PLATFORM(MAC) && __MAC_OS_X_VERSION_MIN_REQUIRED < 101200
    : FontPlatformData(adoptCF(CTFontCopyGraphicsFont(font, NULL)).get(), size, syntheticBold, syntheticOblique, orientation, widthVariant, textRenderingMode)
#else
    : FontPlatformData(size, syntheticBold, syntheticOblique, orientation, widthVariant, textRenderingMode)
#endif
{
    ASSERT_ARG(font, font);
    m_font = font;
#if PLATFORM(IOS) || __MAC_OS_X_VERSION_MIN_REQUIRED >= 1070
    m_isColorBitmapFont = CTFontGetSymbolicTraits(font) & kCTFontTraitColorGlyphs;
    m_isSystemFont = CTFontDescriptorIsSystemUIFont(adoptCF(CTFontCopyFontDescriptor(m_font.get())).get());
#else
    m_isColorBitmapFont = false;
    m_isSystemFont = [toNSFont(m_font.get()) __isSystemFont];
#endif
    auto variations = adoptCF(static_cast<CFDictionaryRef>(CTFontCopyAttribute(font, kCTFontVariationAttribute)));
    m_hasVariations = variations && CFDictionaryGetCount(variations.get());

#if PLATFORM(IOS)
    m_isEmoji = CTFontIsAppleColorEmoji(m_font.get());
#endif

#if PLATFORM(MAC) && __MAC_OS_X_VERSION_MIN_REQUIRED == 1050
    ATSFontRef atsFont = CTFontGetPlatformFont(font, nullptr);
    m_cgFont = adoptCF(CGFontCreateWithPlatformFont(&atsFont));
    RELEASE_ASSERT(m_cgFont.get());
#endif
}

unsigned FontPlatformData::hash() const
{
    uintptr_t flags = static_cast<uintptr_t>(m_widthVariant << 6 | m_isHashTableDeletedValue << 5 | m_textRenderingMode << 3 | m_orientation << 2 | m_syntheticBold << 1 | m_syntheticOblique);
#if PLATFORM(MAC) && __MAC_OS_X_VERSION_MIN_REQUIRED < 101200
    uintptr_t fontHash = reinterpret_cast<uintptr_t>(m_font.get());
#else
    uintptr_t fontHash = reinterpret_cast<uintptr_t>(CFHash(m_font.get()));
#endif
    uintptr_t hashCodes[] = { fontHash, flags };
    return StringHasher::hashMemory<sizeof(hashCodes)>(hashCodes);
}

bool FontPlatformData::platformIsEqual(const FontPlatformData& other) const
{
    if (!m_font || !other.m_font)
        return m_font == other.m_font;
#if PLATFORM(MAC) && __MAC_OS_X_VERSION_MIN_REQUIRED < 101200
    return m_font == other.m_font;
#else
    return CFEqual(m_font.get(), other.m_font.get());
#endif
}

CTFontRef FontPlatformData::registeredFont() const
{
    CTFontRef platformFont = font();
    ASSERT(platformFont);
#if PLATFORM(IOS) || __MAC_OS_X_VERSION_MIN_REQUIRED >= 1060
    if (platformFont && adoptCF(CTFontCopyAttribute(platformFont, kCTFontURLAttribute)))
        return platformFont;
#else
    if (platformFont && !m_atsContainer)
        return platformFont;
#if 0
    if (platformFont) {
        ATSFontRef atsFont = CTFontGetPlatformFont(platformFont, NULL);
        RELEASE_ASSERT(atsFont != kATSFontRefUnspecified);
        FSRef fsRef;
        if (ATSFontGetFileReference(atsFont, &fsRef) == noErr) {
            ATSFontContainerRef containerRef = kATSFontContainerRefUnspecified;
            if (ATSFontGetContainerFromFileReference(&fsRef, kATSFontContextGlobal, kATSOptionFlagsDefault, &containerRef) == noErr)
                if (containerRef != kATSFontContainerRefUnspecified)
                    return platformFont;
        }
    }
#endif
#endif

    return nullptr;
}

inline int mapFontWidthVariantToCTFeatureSelector(FontWidthVariant variant)
{
    switch(variant) {
    case RegularWidth:
        return TextSpacingProportional;

    case HalfWidth:
        return TextSpacingHalfWidth;

    case ThirdWidth:
        return TextSpacingThirdWidth;

    case QuarterWidth:
        return TextSpacingQuarterWidth;
    }

    ASSERT_NOT_REACHED();
    return TextSpacingProportional;
}

static CFDictionaryRef cascadeToLastResortAttributesDictionary()
{
    static CFDictionaryRef attributes = nullptr;
    if (attributes)
        return attributes;

    RetainPtr<CTFontDescriptorRef> lastResort = adoptCF(CTFontDescriptorCreateWithNameAndSize(CFSTR("LastResort"), 0));

    CFTypeRef descriptors[] = { lastResort.get() };
    RetainPtr<CFArrayRef> array = adoptCF(CFArrayCreate(kCFAllocatorDefault, descriptors, WTF_ARRAY_LENGTH(descriptors), &kCFTypeArrayCallBacks));

    CFTypeRef keys[] = { kCTFontCascadeListAttribute };
    CFTypeRef values[] = { array.get() };
    attributes = CFDictionaryCreate(kCFAllocatorDefault, keys, values, WTF_ARRAY_LENGTH(keys), &kCFTypeDictionaryKeyCallBacks, &kCFTypeDictionaryValueCallBacks);

    return attributes;
}

static RetainPtr<CFDictionaryRef> cascadeToLastResortAndVariationsFontDescriptor(CTFontRef originalFont)
{
// FIXME: Remove this when <rdar://problem/28449441> is fixed.
#define WORKAROUND_CORETEXT_VARIATIONS_WITH_FALLBACK_LIST_BUG (ENABLE(VARIATION_FONTS) && ((PLATFORM(MAC) && __MAC_OS_X_VERSION_MIN_REQUIRED < 101300) || (PLATFORM(IOS) && __IPHONE_OS_VERSION_MIN_REQUIRED < 110000)))

    CFDictionaryRef attributes = cascadeToLastResortAttributesDictionary();
#if WORKAROUND_CORETEXT_VARIATIONS_WITH_FALLBACK_LIST_BUG
    auto variations = adoptCF(static_cast<CFDictionaryRef>(CTFontCopyAttribute(originalFont, kCTFontVariationAttribute)));
    if (!variations || !CFDictionaryGetCount(variations.get())
#if PLATFORM(IOS) || __MAC_OS_X_VERSION_MIN_REQUIRED >= 1070
        || CTFontDescriptorIsSystemUIFont(adoptCF(CTFontCopyFontDescriptor(originalFont)).get()))
#else
        || [toNSFont(originalFont) __isSystemFont])
#endif
#endif
    {
        UNUSED_PARAM(originalFont);
        return attributes;
    }
#if WORKAROUND_CORETEXT_VARIATIONS_WITH_FALLBACK_LIST_BUG
    auto mutableAttributes = adoptCF(CFDictionaryCreateMutableCopy(kCFAllocatorDefault, 2, attributes));
    CFDictionaryAddValue(mutableAttributes.get(), kCTFontVariationAttribute, variations.get());
    return mutableAttributes.get();
#endif
#undef WORKAROUND_CORETEXT_VARIATIONS_WITH_FALLBACK_LIST_BUG
}

static CFDictionaryRef createFeatureSettingDictionary(int featureTypeIdentifier, int featureSelectorIdentifier)
{
    RetainPtr<CFNumberRef> featureTypeIdentifierNumber = adoptCF(CFNumberCreate(kCFAllocatorDefault, kCFNumberIntType, &featureTypeIdentifier)); 
    RetainPtr<CFNumberRef> featureSelectorIdentifierNumber = adoptCF(CFNumberCreate(kCFAllocatorDefault, kCFNumberIntType, &featureSelectorIdentifier));

    const void* settingKeys[] = { kCTFontFeatureTypeIdentifierKey, kCTFontFeatureSelectorIdentifierKey };
    const void* settingValues[] = { featureTypeIdentifierNumber.get(), featureSelectorIdentifierNumber.get() };

    return CFDictionaryCreate(kCFAllocatorDefault, settingKeys, settingValues, WTF_ARRAY_LENGTH(settingKeys), &kCFTypeDictionaryKeyCallBacks, &kCFTypeDictionaryValueCallBacks);
}

static CFDictionaryRef disableSwashesFontAttributes()
{
    static CFDictionaryRef attributes;
    if (attributes)
        return attributes;

    RetainPtr<CFDictionaryRef> lineInitialSwashesOffSetting = adoptCF(createFeatureSettingDictionary(kSmartSwashType, kLineInitialSwashesOffSelector));
    RetainPtr<CFDictionaryRef> lineFinalSwashesOffSetting = adoptCF(createFeatureSettingDictionary(kSmartSwashType, kLineFinalSwashesOffSelector));

    const void* settingDictionaries[] = { lineInitialSwashesOffSetting.get(), lineFinalSwashesOffSetting.get() };
    RetainPtr<CFArrayRef> featureSettings = adoptCF(CFArrayCreate(kCFAllocatorDefault, settingDictionaries, WTF_ARRAY_LENGTH(settingDictionaries), &kCFTypeArrayCallBacks));

    const void* keys[] = { kCTFontFeatureSettingsAttribute };
    const void* values[] = { featureSettings.get() };
    attributes = CFDictionaryCreate(kCFAllocatorDefault, keys, values, WTF_ARRAY_LENGTH(keys), &kCFTypeDictionaryKeyCallBacks, &kCFTypeDictionaryValueCallBacks);

    return attributes;
}

CTFontRef FontPlatformData::ctFont() const
{
    if (m_ctFont)
        return m_ctFont.get();

    ASSERT(m_font);
#if PLATFORM(MAC) && __MAC_OS_X_VERSION_MIN_REQUIRED < 101200
    ASSERT(m_cgFont);
#endif
    RetainPtr<CTFontDescriptorRef> sourceDescriptor = adoptCF(CTFontCopyFontDescriptor(m_font.get()));
    RetainPtr<CTFontDescriptorRef> descriptor = adoptCF(CTFontDescriptorCreateCopyWithAttributes(sourceDescriptor.get(), cascadeToLastResortAndVariationsFontDescriptor(m_font.get()).get()));
    RetainPtr<CFStringRef> postScriptName = adoptCF(CTFontDescriptorCopyAttribute(descriptor.get(), kCTFontNameAttribute));
    // Hoefler Text Italic has line-initial and -final swashes enabled by default, so disable them.
    if (CFEqual(postScriptName.get(), CFSTR("HoeflerText-Italic")) || CFEqual(postScriptName.get(), CFSTR("HoeflerText-BlackItalic"))) {
        descriptor = adoptCF(CTFontDescriptorCreateCopyWithAttributes(sourceDescriptor.get(), disableSwashesFontAttributes()));
    }
#if PLATFORM(MAC) && __MAC_OS_X_VERSION_MIN_REQUIRED == 1050
    m_ctFont = adoptCF(CTFontCreateWithPlatformFont(CTFontGetPlatformFont(m_font.get(), nullptr), m_size, 0, descriptor.get()));
    RELEASE_ASSERT(CTFontGetPlatformFont(m_font.get(), nullptr) == CTFontGetPlatformFont(m_ctFont.get(), nullptr));
#else
    m_ctFont = adoptCF(CTFontCreateCopyWithAttributes(m_font.get(), m_size, 0, descriptor.get()));
#endif

    if (m_widthVariant != RegularWidth) {
        int featureTypeValue = kTextSpacingType;
        int featureSelectorValue = mapFontWidthVariantToCTFeatureSelector(m_widthVariant);
        RetainPtr<CFNumberRef> featureType = adoptCF(CFNumberCreate(kCFAllocatorDefault, kCFNumberIntType, &featureTypeValue));
        RetainPtr<CFNumberRef> featureSelector = adoptCF(CFNumberCreate(kCFAllocatorDefault, kCFNumberIntType, &featureSelectorValue));
        RetainPtr<CTFontDescriptorRef> newDescriptor = adoptCF(CTFontDescriptorCreateCopyWithFeature(descriptor.get(), featureType.get(), featureSelector.get()));
#if PLATFORM(MAC) && __MAC_OS_X_VERSION_MIN_REQUIRED == 1050
        RetainPtr<CTFontRef> newFont = adoptCF(CTFontCreateWithPlatformFont(CTFontGetPlatformFont(m_font.get(), nullptr), m_size, 0, newDescriptor.get()));
#else
        RetainPtr<CTFontRef> newFont = adoptCF(CTFontCreateWithFontDescriptor(newDescriptor.get(), m_size, 0));
#endif

        if (newFont) {
            RELEASE_ASSERT(CTFontGetPlatformFont(m_font.get(), nullptr) == CTFontGetPlatformFont(newFont.get(), nullptr));
            m_ctFont = newFont;
        }
    }

    return m_ctFont.get();
}

RetainPtr<CFTypeRef> FontPlatformData::objectForEqualityCheck(CTFontRef ctFont)
{
#if PLATFORM(IOS) || __MAC_OS_X_VERSION_MIN_REQUIRED >= 1070
    auto fontDescriptor = adoptCF(CTFontCopyFontDescriptor(ctFont));
    // FIXME: https://bugs.webkit.org/show_bug.cgi?id=138683 This is a shallow pointer compare for web fonts
    // because the URL contains the address of the font. This means we might erroneously get false negatives.
    RetainPtr<CFURLRef> url = adoptCF(static_cast<CFURLRef>(CTFontDescriptorCopyAttribute(fontDescriptor.get(), kCTFontReferenceURLAttribute)));
    ASSERT(!url || CFGetTypeID(url.get()) == CFURLGetTypeID());
    return url;
#elif PLATFORM(MAC) && __MAC_OS_X_VERSION_MIN_REQUIRED == 1060
    return adoptCF(CTFontCopyGraphicsFont(ctFont, NULL));
#elif PLATFORM(MAC) && __MAC_OS_X_VERSION_MIN_REQUIRED == 1050
    ATSFontRef atsFont = CTFontGetPlatformFont(ctFont, NULL);
    RELEASE_ASSERT(atsFont != kATSFontRefUnspecified);
    return adoptCF(CFDataCreate(kCFAllocatorDefault, (UInt8 *)&atsFont, sizeof(atsFont)));
#endif
}

RetainPtr<CFTypeRef> FontPlatformData::objectForEqualityCheck() const
{
    return objectForEqualityCheck(ctFont());
}

RefPtr<SharedBuffer> FontPlatformData::openTypeTable(uint32_t table) const
{
    if (RetainPtr<CFDataRef> data = adoptCF(CTFontCopyTable(font(), table, kCTFontTableOptionNoOptions)))
        return SharedBuffer::create(data.get());
    
    return nullptr;
}

#ifndef NDEBUG
String FontPlatformData::description() const
{
    auto fontDescription = adoptCF(CFCopyDescription(font()));
    return String(fontDescription.get()) + " " + String::number(m_size)
            + (m_syntheticBold ? " synthetic bold" : "") + (m_syntheticOblique ? " synthetic oblique" : "") + (m_orientation ? " vertical orientation" : "");
}
#endif

} // namespace WebCore
