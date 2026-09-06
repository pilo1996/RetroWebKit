/*
 * Copyright (C) 2007 Apple Inc.
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

#ifndef FontCustomPlatformData_h
#define FontCustomPlatformData_h

#include "FontPlatformData.h"
#include "TextFlags.h"
#include <CoreFoundation/CFBase.h>
#include <wtf/Forward.h>
#include <wtf/Noncopyable.h>
#include <wtf/RetainPtr.h>
#if __MAC_OS_X_VERSION_MIN_REQUIRED == 1050
#include <wtf/RefCounted.h>
#endif

typedef const struct __CTFontDescriptor* CTFontDescriptorRef;
#if __MAC_OS_X_VERSION_MIN_REQUIRED == 1060
typedef struct CGFont* CGFontRef;
#elif __MAC_OS_X_VERSION_MIN_REQUIRED == 1050
typedef const struct __CTFont* CTFontRef;
#endif

namespace WebCore {

class FontDescription;
struct FontSelectionSpecifiedCapabilities;
class SharedBuffer;

template <typename T> class FontTaggedSettings;
typedef FontTaggedSettings<int> FontFeatureSettings;

struct FontCustomPlatformData {
    WTF_MAKE_NONCOPYABLE(FontCustomPlatformData); WTF_MAKE_FAST_ALLOCATED;
public:
#if __MAC_OS_X_VERSION_MIN_REQUIRED >= 1070
    explicit FontCustomPlatformData(CTFontDescriptorRef fontDescriptor)
        : m_fontDescriptor(fontDescriptor)
#elif __MAC_OS_X_VERSION_MIN_REQUIRED == 1060
    explicit FontCustomPlatformData(CGFontRef cgFont)
        : m_cgFont(cgFont)
#elif __MAC_OS_X_VERSION_MIN_REQUIRED == 1050
    explicit FontCustomPlatformData(ATSFontContainerRefWrapper& container, CTFontRef ctFont)
        : m_ctFont(ctFont)
        , m_atsContainer(container)
#endif
    {
    }

    ~FontCustomPlatformData();

    FontPlatformData fontPlatformData(const FontDescription&, bool bold, bool italic, const FontFeatureSettings& fontFaceFeatures, const FontVariantSettings& fontFaceVariantSettings, FontSelectionSpecifiedCapabilities fontFaceCapabilities);

    static bool supportsFormat(const String&);

#if __MAC_OS_X_VERSION_MIN_REQUIRED == 1060
    RetainPtr<CGFontRef> m_cgFont;
#elif __MAC_OS_X_VERSION_MIN_REQUIRED == 1050
    RetainPtr<CTFontRef> m_ctFont;
    Ref<ATSFontContainerRefWrapper> m_atsContainer;
#else
    RetainPtr<CTFontDescriptorRef> m_fontDescriptor;
#endif
};

std::unique_ptr<FontCustomPlatformData> createFontCustomPlatformData(SharedBuffer&);

}

#endif
