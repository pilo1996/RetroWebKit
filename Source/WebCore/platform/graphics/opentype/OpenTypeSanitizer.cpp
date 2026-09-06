/*
 * Copyright (C) 2009 Google Inc. All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions are
 * met:
 *
 *     * Redistributions of source code must retain the above copyright
 * notice, this list of conditions and the following disclaimer.
 *     * Redistributions in binary form must reproduce the above
 * copyright notice, this list of conditions and the following disclaimer
 * in the documentation and/or other materials provided with the
 * distribution.
 *     * Neither the name of Google Inc. nor the names of its
 * contributors may be used to endorse or promote products derived from
 * this software without specific prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
 * "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
 * LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
 * A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT
 * OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
 * SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT
 * LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
 * DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
 * THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
 * (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
 * OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

#include "config.h"
#if USE(OPENTYPE_SANITIZER)
#include "OpenTypeSanitizer.h"

#include "SharedBuffer.h"
#include <ots/opentype-sanitiser.h>
#include <ots/ots-memory-stream.h>

namespace WebCore {

RefPtr<SharedBuffer> OpenTypeSanitizer::sanitize()
{
    // This is the largest web font size which we'll try to transcode.
    static const size_t maxWebFontSize = 30 * 1024 * 1024; // 30 MB
    if (m_buffer.size() > maxWebFontSize)
        return nullptr;

    // A transcoded font is usually smaller than an original font.
    // However, it can be slightly bigger than the original one due to
    // name table replacement and/or padding for glyf table.
    //
    // With WOFF fonts, however, we'll be decompressing, so the result can be
    // much larger than the original.

    ots::ExpandingMemoryStream output(m_buffer.size(), maxWebFontSize);
    if (!Process(&output, reinterpret_cast<const uint8_t*>(m_buffer.data()), m_buffer.size()))
        return nullptr;

    const size_t transcodeLen = output.Tell();
    return SharedBuffer::create(static_cast<unsigned char*>(output.get()), transcodeLen);
}

ots::TableAction OpenTypeSanitizer::GetTableAction(uint32_t tag)
{
    switch(tag)
    {
    // pass these three tables through as OTS would simply reject broken fonts - but i.e. CoreText can work around those problems
    case OTS_TAG('G', 'D', 'E', 'F'):
    case OTS_TAG('G', 'P', 'O', 'S'):
    case OTS_TAG('G', 'S', 'U', 'B'):
#if ENABLE(VARIATION_FONTS)
    // variation tables
    case OTS_TAG('a', 'v', 'a', 'r'):
    case OTS_TAG('c', 'v', 'a', 'r'):
    case OTS_TAG('f', 'v', 'a', 'r'):
    case OTS_TAG('g', 'v', 'a', 'r'):
    case OTS_TAG('H', 'V', 'A', 'R'):
    case OTS_TAG('M', 'V', 'A', 'R'):
    case OTS_TAG('V', 'V', 'A', 'R'):
#endif
    // color (emoji) tables
    case OTS_TAG('C', 'B', 'D', 'T'):
    case OTS_TAG('C', 'B', 'L', 'C'):
    case OTS_TAG('C', 'O', 'L', 'R'):
    case OTS_TAG('C', 'P', 'A', 'L'):
    case OTS_TAG('S', 'V', 'G', ' '):
    case OTS_TAG('s', 'b', 'i', 'x'): // supported in OS X 10.7 and later
        return ots::TABLE_ACTION_PASSTHRU;

    default:
        return ots::TABLE_ACTION_DEFAULT;
    }
}

void OpenTypeSanitizer::Message(int level, const char *format, ...) MSGFUNC_FMT_ATTR
{
    UNUSED_PARAM(level);
    UNUSED_PARAM(format);
}

} // namespace WebCore

#endif // USE(OPENTYPE_SANITIZER)
