/*
 * Copyright (C) 2006, 2010, 2015 Apple Inc. All rights reserved.
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

#include "config.h"

#if PLATFORM(MAC)
#include "PowerObserverMac.h"

// On Snow Leopard and newer we'll ask IOKit to deliver notifications on a queue.
#if __MAC_OS_X_VERSION_MIN_REQUIRED == 1050
#define IOKIT_WITHOUT_LIBDISPATCH 1
#endif

#if !defined(IOKIT_WITHOUT_LIBDISPATCH) && !PLATFORM(IOS) && __MAC_OS_X_VERSION_MAX_ALLOWED == 1060
extern "C" void IONotificationPortSetDispatchQueue(IONotificationPortRef notify, dispatch_queue_t queue);
#endif

namespace WebCore {

PowerObserver::PowerObserver(WTF::Function<void()>&& powerOnHander)
    : m_powerOnHander(WTFMove(powerOnHander))
    , m_powerConnection(0)
    , m_notificationPort(nullptr)
    , m_notifierReference(0)
#ifdef IOKIT_WITHOUT_LIBDISPATCH
    , m_runLoopSource(0)    
#else
    , m_dispatchQueue(dispatch_queue_create("com.apple.WebKit.PowerObserver", 0))
#endif
{
    m_powerConnection = IORegisterForSystemPower(this, &m_notificationPort, [](void* context, io_service_t service, uint32_t messageType, void* messageArgument) {
        static_cast<PowerObserver*>(context)->didReceiveSystemPowerNotification(service, messageType, messageArgument);
    }, &m_notifierReference);
    if (!m_powerConnection)
        return;

#ifdef IOKIT_WITHOUT_LIBDISPATCH
    m_runLoopSource = IONotificationPortGetRunLoopSource(m_notificationPort);
    CFRunLoopAddSource(CFRunLoopGetMain(), m_runLoopSource, kCFRunLoopCommonModes);
#else
    IONotificationPortSetDispatchQueue(m_notificationPort, m_dispatchQueue);
#endif
}

PowerObserver::~PowerObserver()
{
    if (!m_powerConnection)
        return;

#ifdef IOKIT_WITHOUT_LIBDISPATCH
    CFRunLoopRemoveSource(CFRunLoopGetMain(), m_runLoopSource, kCFRunLoopCommonModes);
#else
    dispatch_release(m_dispatchQueue);
#endif

    IODeregisterForSystemPower(&m_notifierReference);
    IOServiceClose(m_powerConnection);
    IONotificationPortDestroy(m_notificationPort);
}

#ifdef IOKIT_WITHOUT_LIBDISPATCH
void PowerObserver::runLoopCallBack(CFRunLoopObserverRef observer, CFRunLoopActivity /*activity*/, void* info)
{
    static_cast<PowerObserver*>(info)->m_powerOnHander();
    CFRunLoopObserverInvalidate(observer);
    CFRelease(observer);
}
#endif

void PowerObserver::didReceiveSystemPowerNotification(io_service_t, uint32_t messageType, void* messageArgument)
{
    IOAllowPowerChange(m_powerConnection, reinterpret_cast<long>(messageArgument));

    // We only care about the "wake from sleep" message.
    if (messageType != kIOMessageSystemWillPowerOn)
        return;

#ifdef IOKIT_WITHOUT_LIBDISPATCH
    CFRunLoopObserverContext context = { 0, this, 0, 0, 0 };
    CFRunLoopObserverRef runLoopObserver = CFRunLoopObserverCreate(NULL, kCFRunLoopBeforeWaiting | kCFRunLoopExit, false /* don't repeat */,
        0, runLoopCallBack, &context);
    CFRunLoopAddObserver(CFRunLoopGetMain(), runLoopObserver, kCFRunLoopCommonModes);
#else
    // We need to restart the timer on the main thread.
    CFRunLoopPerformBlock(CFRunLoopGetMain(), kCFRunLoopCommonModes, ^() {
        m_powerOnHander();
    });
#endif
}

} // namespace WebCore

#endif
