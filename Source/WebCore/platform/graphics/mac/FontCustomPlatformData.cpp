/*
 * Copyright (C) 2007, 2008, 2010 Apple Inc. All rights reserved.
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

#include "config.h"
#include "FontCustomPlatformData.h"

#include "FontCache.h"
#include "FontDescription.h"
#include "FontPlatformData.h"
#include "SharedBuffer.h"
#if __MAC_OS_X_VERSION_MIN_REQUIRED == 1050
#include "CoreGraphicsSPI.h"
#include <wtf/HashMap.h>
#include <wtf/NeverDestroyed.h>
#include <wtf/Ref.h>
#include <ATS/ATSFont.h>
#endif
#include <CoreGraphics/CoreGraphics.h>
#include <CoreText/CoreText.h>

#if __MAC_OS_X_VERSION_MIN_REQUIRED == 1050
extern "C" { UInt16 ATSFontGetGlyphCount(ATSFontRef inFontRef); }
#endif

namespace WebCore {

#if PLATFORM(MAC) && __MAC_OS_X_VERSION_MIN_REQUIRED == 1050

Ref<ATSFontContainerRefWrapper> ATSFontContainerRefWrapper::create(ATSFontContainerRef atsContainer)
{
    return adoptRef(*new ATSFontContainerRefWrapper(atsContainer));
}

WEBCORE_EXPORT ATSFontContainerRefWrapper::~ATSFontContainerRefWrapper()
{
    ATSFontDeactivate(m_atsContainer, NULL, kATSOptionFlagsDefault);
}
 
ATSFontContainerRefWrapper::ATSFontContainerRefWrapper(ATSFontContainerRef atsContainer)
    : m_atsContainer(atsContainer)
{
}

#endif

FontCustomPlatformData::~FontCustomPlatformData()
{
}

FontPlatformData FontCustomPlatformData::fontPlatformData(const FontDescription& fontDescription, bool bold, bool italic, const FontFeatureSettings& fontFaceFeatures, const FontVariantSettings& fontFaceVariantSettings, FontSelectionSpecifiedCapabilities fontFaceCapabilities)
{
    int size = fontDescription.computedPixelSize();
    FontOrientation orientation = fontDescription.orientation();
    FontWidthVariant widthVariant = fontDescription.widthVariant();
#if PLATFORM(MAC) && __MAC_OS_X_VERSION_MIN_REQUIRED == 1060
    RetainPtr<CTFontRef> newFont = adoptCF(CTFontCreateWithGraphicsFont(m_cgFont.get(), size, nullptr, nullptr));
#elif PLATFORM(MAC) && __MAC_OS_X_VERSION_MIN_REQUIRED == 1050
    RetainPtr<CTFontRef> newFont = adoptCF(CTFontCreateWithPlatformFont(CTFontGetPlatformFont(m_ctFont.get(), nullptr), size, nullptr, nullptr));
    if (CTFontGetPlatformFont(m_ctFont.get(), nullptr) != CTFontGetPlatformFont(newFont.get(), nullptr)) {
        CFShow(CFSTR("CTFont size adaption failed for font:"));
        CFShow(m_ctFont.get());
        CFShow(CFSTR("CoreText instead returned the following font:"));
        CFShow(newFont.get());
    }
#else
    RetainPtr<CTFontRef> newFont = adoptCF(CTFontCreateWithFontDescriptor(m_fontDescriptor.get(), size, nullptr));
#endif
    RetainPtr<CTFontRef> font = preparePlatformFont(newFont.get(), fontDescription, &fontFaceFeatures, &fontFaceVariantSettings, fontFaceCapabilities, fontDescription.computedSize());
    ASSERT(font);
#if PLATFORM(MAC) && __MAC_OS_X_VERSION_MIN_REQUIRED == 1050
    RELEASE_ASSERT(CTFontGetPlatformFont(newFont.get(), nullptr) == CTFontGetPlatformFont(font.get(), nullptr));

    return FontPlatformData(font.get(), &m_atsContainer.get(), size, bold, italic, orientation, widthVariant, fontDescription.textRenderingMode());
#else
    return FontPlatformData(font.get(), size, bold, italic, orientation, widthVariant, fontDescription.textRenderingMode());
#endif
}

std::unique_ptr<FontCustomPlatformData> createFontCustomPlatformData(SharedBuffer& buffer)
{
#if PLATFORM(IOS) || __MAC_OS_X_VERSION_MIN_REQUIRED >= 1070
    RetainPtr<CFDataRef> bufferData = buffer.createCFData();

    RetainPtr<CTFontDescriptorRef> fontDescriptor = adoptCF(CTFontManagerCreateFontDescriptorFromData(bufferData.get()));
    if (!fontDescriptor)
        return nullptr;

    return std::make_unique<FontCustomPlatformData>(fontDescriptor.get());
#elif __MAC_OS_X_VERSION_MIN_REQUIRED >= 1060
    RetainPtr<CGFontRef> cgFontRef = nullptr;
    RetainPtr<CFDataRef> bufferData = buffer.createCFData();

    RetainPtr<CGDataProviderRef> dataProvider = adoptCF(CGDataProviderCreateWithCFData(bufferData.get()));

    cgFontRef = adoptCF(CGFontCreateWithDataProvider(dataProvider.get()));
    if (!cgFontRef)
        return nullptr;

    return std::make_unique<FontCustomPlatformData>(cgFontRef.get());
#else
    // Use ATS to activate the font.
    ATSFontContainerRef containerRef = kATSFontContainerRefUnspecified;

    // The value "3" means that the font is private and can't be seen by anyone else
    OSStatus err = ATSFontActivateFromMemory(const_cast<char*>(buffer.data()), buffer.size(), 3, kATSFontFormatUnspecified, NULL, kATSOptionFlagsDefault, &containerRef);
    if (err != noErr || containerRef == kATSFontRefUnspecified) {
        return nullptr;
    }
    ItemCount fontCount;
    err = ATSFontFindFromContainer(containerRef, kATSOptionFlagsDefault, 0, NULL, &fontCount);

    // We just support the first working font in the list.
    if (err != noErr || fontCount == 0) {
        ATSFontDeactivate(containerRef, NULL, kATSOptionFlagsDefault);
        return nullptr;
    }

    MallocPtr<ATSFontRef> fontRefs = MallocPtr<ATSFontRef>::malloc(sizeof(ATSFontRef) * fontCount);
    err = ATSFontFindFromContainer(containerRef, kATSOptionFlagsDefault, fontCount, fontRefs.get(), NULL);
    if (err != noErr) {
        ATSFontDeactivate(containerRef, NULL, kATSOptionFlagsDefault);
        return nullptr;
    }

    RetainPtr<CTFontRef> ctFontRef;
    for (ItemCount index = 0; index < fontCount && fontRefs.get()[index] != kATSFontRefUnspecified; index++) {
        RetainPtr<CFStringRef> postScriptName;
        CFStringRef string;
        err = ATSFontGetPostScriptName(fontRefs.get()[index], kATSOptionFlagsDefault, &string);
        postScriptName = adoptCF(string);

        // Workaround for <rdar://problem/5675504>.
        UInt16 glyphCount;
        if (err == noErr
            && postScriptName
            && (glyphCount = ATSFontGetGlyphCount(fontRefs.get()[index])))
        {
            RetainPtr<CFStringRef> ctFontPostScriptName;
            RetainPtr<CTFontRef> ctFontCandidate = adoptCF(CTFontCreateWithPlatformFont(fontRefs.get()[index], 0, nullptr, nullptr));
            // Make sure CoreText did create the right font and that it's size can be changed
            // CoreText Fonts without valid PostScript name sooner or later will cause problems, so reject them
            if (ctFontCandidate
                && CTFontGetPlatformFont(
                       adoptCF(CTFontCreateWithPlatformFont(CTFontGetPlatformFont(ctFontCandidate.get(), nullptr), CTFontGetSize(ctFontCandidate.get()) * 2, nullptr, nullptr)).get(),
                       nullptr) == fontRefs.get()[index]
                && (ctFontPostScriptName = adoptCF(CTFontCopyPostScriptName(ctFontCandidate.get())))
                && CFEqual(ctFontPostScriptName.get(), postScriptName.get())
                && CTFontGetGlyphCount(ctFontCandidate.get()) == glyphCount)
            {
                ctFontRef = ctFontCandidate;
                break;
            }
        }
    }

    if (!ctFontRef) {
        ATSFontDeactivate(containerRef, NULL, kATSOptionFlagsDefault);
        return nullptr;
    }

    return std::make_unique<FontCustomPlatformData>(ATSFontContainerRefWrapper::create(containerRef), ctFontRef.get());
#endif
}

bool FontCustomPlatformData::supportsFormat(const String& format)
{
    return equalLettersIgnoringASCIICase(format, "truetype")
        || equalLettersIgnoringASCIICase(format, "opentype")
#if PLATFORM(IOS) || (PLATFORM(MAC) && __MAC_OS_X_VERSION_MIN_REQUIRED >= 101200) || USE(WOFF2) || USE(OPENTYPE_SANITIZER)
        || equalLettersIgnoringASCIICase(format, "woff2")
#if ENABLE(VARIATION_FONTS)
        || equalLettersIgnoringASCIICase(format, "woff2-variations")
#endif
#endif
#if ENABLE(VARIATION_FONTS)
        || equalLettersIgnoringASCIICase(format, "woff-variations")
        || equalLettersIgnoringASCIICase(format, "truetype-variations")
        || equalLettersIgnoringASCIICase(format, "opentype-variations")
#endif
        || equalLettersIgnoringASCIICase(format, "woff");
}

}
