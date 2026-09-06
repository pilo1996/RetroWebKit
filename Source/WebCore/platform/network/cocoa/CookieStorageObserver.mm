/*
 * Copyright (C) 2017 Apple Inc. All rights reserved.
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

#import "config.h"
#import "CookieStorageObserver.h"

#if !((PLATFORM(MAC) && __MAC_OS_X_VERSION_MIN_REQUIRED >= 101300) || (PLATFORM(IOS) && __IPHONE_OS_VERSION_MIN_REQUIRED >= 110000))
#import "CFNetworkSPI.h"
#endif
#import "NSURLConnectionSPI.h"
#import <wtf/MainThread.h>

#if (PLATFORM(MAC) && __MAC_OS_X_VERSION_MIN_REQUIRED >= 101300) || (PLATFORM(IOS) && __IPHONE_OS_VERSION_MIN_REQUIRED >= 110000)

@interface WebNSHTTPCookieStorageInternal : NSObject {
@public
    id internal;
}
@end

@implementation WebNSHTTPCookieStorageInternal
@end

@interface WebCookieObserverAdapter : NSObject {
    WebCore::CookieStorageObserver* observer;
}
- (id)initWithObserver:(WebCore::CookieStorageObserver&)theObserver;
- (void)cookiesChangedNotificationHandler:(NSNotification *)notification;

@end

@implementation WebCookieObserverAdapter

- (id)initWithObserver:(WebCore::CookieStorageObserver&)theObserver
{
    self = [super init];
    if (!self)
        return nil;

    observer = &theObserver;

    return self;
}

- (void)cookiesChangedNotificationHandler:(NSNotification *)notification
{
    UNUSED_PARAM(notification);
    observer->cookiesDidChange();
}

@end

#endif

namespace WebCore {

#if !((PLATFORM(MAC) && __MAC_OS_X_VERSION_MIN_REQUIRED >= 101300) || (PLATFORM(IOS) && __IPHONE_OS_VERSION_MIN_REQUIRED >= 110000))

static void cookiesChanged(CFHTTPCookieStorageRef, void* context)
{
    ASSERT(!isMainThread());
    static_cast<CookieStorageObserver*>(context)->cookiesDidChange();
}

#endif

RefPtr<CookieStorageObserver> CookieStorageObserver::create(NSHTTPCookieStorage *cookieStorage)
{
    return adoptRef(new CookieStorageObserver(cookieStorage));
}

CookieStorageObserver::CookieStorageObserver(NSHTTPCookieStorage *cookieStorage)
    : m_cookieStorage(cookieStorage)
{
    ASSERT(isMainThread());
    ASSERT(m_cookieStorage);
}

CookieStorageObserver::~CookieStorageObserver()
{
    ASSERT(isMainThread());

    if (m_cookieChangeCallback) {
#if (PLATFORM(MAC) && __MAC_OS_X_VERSION_MIN_REQUIRED >= 101300) || (PLATFORM(IOS) && __IPHONE_OS_VERSION_MIN_REQUIRED >= 110000)
        ASSERT(m_observerAdapter);
#endif
        stopObserving();
    }
}

void CookieStorageObserver::startObserving(WTF::Function<void()>&& callback)
{
    ASSERT(isMainThread());
    ASSERT(!m_cookieChangeCallback);
#if (PLATFORM(MAC) && __MAC_OS_X_VERSION_MIN_REQUIRED >= 101300) || (PLATFORM(IOS) && __IPHONE_OS_VERSION_MIN_REQUIRED >= 110000)
    ASSERT(!m_observerAdapter);
#endif

    m_cookieChangeCallback = WTFMove(callback);
#if (PLATFORM(MAC) && __MAC_OS_X_VERSION_MIN_REQUIRED >= 101300) || (PLATFORM(IOS) && __IPHONE_OS_VERSION_MIN_REQUIRED >= 110000)
    m_observerAdapter = adoptNS([[WebCookieObserverAdapter alloc] initWithObserver:*this]);

    if (!m_hasRegisteredInternalsForNotifications) {
        if (m_cookieStorage.get() != [NSHTTPCookieStorage sharedHTTPCookieStorage]) {
            auto selector = NSSelectorFromString(@"registerForPostingNotificationsWithContext:");
            id internalObject = (static_cast<WebNSHTTPCookieStorageInternal *>(m_cookieStorage.get()))->internal;
            RELEASE_ASSERT([internalObject respondsToSelector:selector]);
            [internalObject performSelector:selector withObject:m_cookieStorage.get()];
        }

        m_hasRegisteredInternalsForNotifications = true;
    }

    [[NSNotificationCenter defaultCenter] addObserver:m_observerAdapter.get() selector:@selector(cookiesChangedNotificationHandler:) name:NSHTTPCookieManagerCookiesChangedNotification object:m_cookieStorage.get()];
#else
    CFHTTPCookieStorageAddObserver([m_cookieStorage.get() _cookieStorage], [NSURLConnection resourceLoaderRunLoop], kCFRunLoopCommonModes, cookiesChanged, this);
    CFHTTPCookieStorageScheduleWithRunLoop([m_cookieStorage.get() _cookieStorage], [NSURLConnection resourceLoaderRunLoop], kCFRunLoopCommonModes);
#endif
}

void CookieStorageObserver::stopObserving()
{
    ASSERT(isMainThread());
    ASSERT(m_cookieChangeCallback);
#if (PLATFORM(MAC) && __MAC_OS_X_VERSION_MIN_REQUIRED >= 101300) || (PLATFORM(IOS) && __IPHONE_OS_VERSION_MIN_REQUIRED >= 110000)
    ASSERT(m_observerAdapter);

    [[NSNotificationCenter defaultCenter] removeObserver:m_observerAdapter.get() name:NSHTTPCookieManagerCookiesChangedNotification object:nil];

    m_observerAdapter = nil;
#else
    CFHTTPCookieStorageRemoveObserver([m_cookieStorage.get() _cookieStorage], [NSURLConnection resourceLoaderRunLoop], kCFRunLoopCommonModes, cookiesChanged, this);
#endif
    m_cookieChangeCallback = nullptr;
}

void CookieStorageObserver::cookiesDidChange()
{
    RefPtr<CookieStorageObserver> protectedThis = this;
    callOnMainThread([protectedThis] {
        if (protectedThis->m_cookieChangeCallback)
            protectedThis->m_cookieChangeCallback();
    });
}

} // namespace WebCore
