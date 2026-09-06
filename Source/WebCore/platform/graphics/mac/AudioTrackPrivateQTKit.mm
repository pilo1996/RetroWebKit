/*
 * Copyright (C) 2013 Apple Inc. All rights reserved.
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
 * THIS SOFTWARE IS PROVIDED BY APPLE INC. AND ITS CONTRIBUTORS ``AS IS''
 * AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO,
 * THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR
 * PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL APPLE INC. OR ITS CONTRIBUTORS
 * BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
 * CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
 * SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
 * INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
 * CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
 * ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF
 * THE POSSIBILITY OF SUCH DAMAGE.
 */

#if ENABLE(VIDEO_TRACK)

#import "AudioTrackPrivateQTKit.h"

namespace WebCore {

AudioTrackPrivateQTKit::AudioTrackPrivateQTKit(QTTrack *qtTrack)
    : m_qtTrack(qtTrack)
{
    m_index = [[[m_qtTrack.get() movie] tracks] indexOfObject:m_qtTrack.get()];
    m_id = [(NSNumber *)[m_qtTrack.get() attributeForKey:QTTrackIDAttribute] stringValue];
    m_label = (NSString *)[m_qtTrack.get() attributeForKey:QTTrackDisplayNameAttribute];
    m_language = emptyAtom();

    NSString *mediaType = (NSString *)[m_qtTrack.get() attributeForKey:QTTrackMediaTypeAttribute];
    if ([mediaType isEqualToString:QTMediaTypeSound])
        m_kind = Main;
    else
        m_kind = None;

    AudioTrackPrivate::setEnabled([m_qtTrack.get() isEnabled]);
}

void AudioTrackPrivateQTKit::setEnabled(bool enabled)
{
    [m_qtTrack.get() setEnabled:enabled];
    AudioTrackPrivate::setEnabled(enabled);
}

}

#endif // ENABLE(VIDEO_TRACK)
