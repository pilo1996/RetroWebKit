/*
 * Copyright (C) 2014 Apple Inc. All rights reserved.
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
#import "SystemSleepListenerMac.h"

#if PLATFORM(MAC)

#import <wtf/MainThread.h>

#if __MAC_OS_X_VERSION_MIN_REQUIRED == 1050
@interface WebSystemSleepObserver : NSObject {
@private
    WTF::WeakPtr<WebCore::SystemSleepListenerMac> _weakThis;
}

@property (nonatomic, readonly) WTF::WeakPtr<WebCore::SystemSleepListenerMac> weakThis;

- (id)initWithSystemSleepListenerMac:(WTF::WeakPtr<WebCore::SystemSleepListenerMac>)weakThis;
- (void)willSleep:(NSNotification *)notification;
- (void)didWake:(NSNotification *)notification;

@end

@implementation WebSystemSleepObserver

@synthesize weakThis = _weakThis;

- (id)initWithSystemSleepListenerMac:(WTF::WeakPtr<WebCore::SystemSleepListenerMac>)weakThis
{
    self = [super init];
    if (self != nil)
        _weakThis = weakThis;
    return self;
}

- (void)willSleep:(NSNotification *)notification
{
    UNUSED_PARAM(notification);

    WebSystemSleepObserver *sleepObserver = [self retain];

    callOnMainThread([sleepObserver] {
        if ([sleepObserver weakThis])
            [sleepObserver weakThis]->client().systemWillSleep();
        [sleepObserver release];
    });
}

- (void)didWake:(NSNotification *)notification
{
    UNUSED_PARAM(notification);

    WebSystemSleepObserver *sleepObserver = [self retain];

    callOnMainThread([sleepObserver] {
        if ([sleepObserver weakThis])
            [sleepObserver weakThis]->client().systemDidWake();
        [sleepObserver release];
    });
}

@end
#endif

namespace WebCore {

std::unique_ptr<SystemSleepListener> SystemSleepListener::create(Client& client)
{
    return std::unique_ptr<SystemSleepListener>(new SystemSleepListenerMac(client));
}

SystemSleepListenerMac::SystemSleepListenerMac(Client& client)
    : SystemSleepListener(client)
    , m_weakPtrFactory(this)
#if __MAC_OS_X_VERSION_MIN_REQUIRED >= 1060
    , m_sleepObserver(nil)
    , m_wakeObserver(nil)
#else
    , m_sleepWakeObserver(nil)
#endif
{
    NSNotificationCenter *center = [[NSWorkspace sharedWorkspace] notificationCenter];
#if __MAC_OS_X_VERSION_MIN_REQUIRED >= 1060
    NSOperationQueue *queue = [NSOperationQueue mainQueue];
#endif

    auto weakThis = m_weakPtrFactory.createWeakPtr();

#if __MAC_OS_X_VERSION_MIN_REQUIRED >= 1060
    m_sleepObserver = [center addObserverForName:NSWorkspaceWillSleepNotification object:nil queue:queue usingBlock:^(NSNotification *) {
        callOnMainThread([weakThis] {
            if (weakThis)
                weakThis->m_client.systemWillSleep();
        });
    }];

    m_wakeObserver = [center addObserverForName:NSWorkspaceDidWakeNotification object:nil queue:queue usingBlock:^(NSNotification *) {
        callOnMainThread([weakThis] {
            if (weakThis)
                weakThis->m_client.systemDidWake();
        });
    }];
#else
    m_sleepWakeObserver = adoptNS([[WebSystemSleepObserver alloc] initWithSystemSleepListenerMac:weakThis]);

    [center addObserver:m_sleepWakeObserver.get() selector:@selector(willSleep:) name:NSWorkspaceWillSleepNotification object:nil];

    [center addObserver:m_sleepWakeObserver.get() selector:@selector(didWake:) name:NSWorkspaceDidWakeNotification object:nil];
#endif
}

SystemSleepListenerMac::~SystemSleepListenerMac()
{
    NSNotificationCenter* center = [[NSWorkspace sharedWorkspace] notificationCenter];
#if __MAC_OS_X_VERSION_MIN_REQUIRED >= 1060
    [center removeObserver:m_sleepObserver];
    [center removeObserver:m_wakeObserver];
#else
    [center removeObserver:m_sleepWakeObserver.get()];
#endif
}

}

#endif // PLATFORM(MAC)
