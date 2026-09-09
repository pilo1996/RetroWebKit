/*
 * Copyright (C) 2011-2014 Apple Inc. All rights reserved.
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

#include "config.h"
#include "SleepDisablerCocoa.h"

#if PLATFORM(COCOA)

#include "IOPMLibSPI.h"
#include <wtf/RetainPtr.h>

namespace WebCore {

std::unique_ptr<SleepDisabler> SleepDisabler::create(const char* reason, Type type)
{
    return std::unique_ptr<SleepDisabler>(new SleepDisablerCocoa(reason, type));
}

SleepDisablerCocoa::SleepDisablerCocoa(const char* reason, Type type)
    : SleepDisabler(reason, type)
    , m_sleepAssertion(0)
#if !PLATFORM(IOS) && __MAC_OS_X_VERSION_MIN_REQUIRED == 1050
    , m_systemActivityTimer([] { UpdateSystemActivity(IdleActivity); })
#endif
{
#if !PLATFORM(IOS) && __MAC_OS_X_VERSION_MIN_REQUIRED >= 1060
    RetainPtr<CFStringRef> reasonCF = adoptCF(CFStringCreateWithCString(kCFAllocatorDefault, reason, kCFStringEncodingUTF8));
#else
    UNUSED_PARAM(reason);
#endif

    CFStringRef assertionType;
    switch (type) {
    case Type::Display:
#if !PLATFORM(IOS) && __MAC_OS_X_VERSION_MIN_REQUIRED >= 1060
        assertionType = kIOPMAssertionTypePreventUserIdleDisplaySleep;
#else
        assertionType = kIOPMAssertionTypeNoDisplaySleep;
#endif
        break;
    case Type::System:
#if !PLATFORM(IOS) && __MAC_OS_X_VERSION_MIN_REQUIRED >= 1060
        assertionType = kIOPMAssertionTypePreventUserIdleSystemSleep;
#else
        assertionType = kIOPMAssertionTypeNoIdleSleep;
#endif
        break;
    default:
        ASSERT_NOT_REACHED();
        assertionType = nullptr;
        break;
    }
#if !PLATFORM(IOS) && __MAC_OS_X_VERSION_MIN_REQUIRED >= 1060
    IOPMAssertionCreateWithDescription(assertionType, reasonCF.get(), nullptr, nullptr, nullptr, 0, nullptr, &m_sleepAssertion);
#else
    IOPMAssertionCreate(assertionType, kIOPMAssertionLevelOn, &m_sleepAssertion);
    m_systemActivityTimer.startRepeating(2_min);
#endif
}

SleepDisablerCocoa::~SleepDisablerCocoa()
{
    IOPMAssertionRelease(m_sleepAssertion);
}

}

#endif // PLATFORM(COCOA)
