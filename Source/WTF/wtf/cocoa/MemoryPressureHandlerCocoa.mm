/*
 * Copyright (C) 2011-2017 Apple Inc. All Rights Reserved.
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

#import "config.h"
#import "MemoryPressureHandler.h"

#import <mach/mach.h>
#import <mach/task_info.h>
#import <malloc/malloc.h>
#import <notify.h>
#import <wtf/CurrentTime.h>

#if __MAC_OS_X_VERSION_MIN_REQUIRED <= 1060
#include <mach/vm_statistics.h>
#include <mach/mach_types.h>
#include <mach/mach_init.h>
#include <mach/mach_host.h>
#endif

#define ENABLE_FMW_FOOTPRINT_COMPARISON 0

extern "C" void cache_simulate_memory_warning_event(uint64_t);

#if PLATFORM(MAC) && __MAC_OS_X_VERSION_MIN_REQUIRED <= 1060

@interface MemoryPressureHandlerObjCAdapter : NSObject {
    std::function<void (void)> m_memoryPressureCallback;
    BOOL m_enabled;
}
-(id)initWithCallback:(std::function<void (void)>)callback;
-(void)timerOnMainThread;
-(void)startTimer:(unsigned)seconds;
-(void)disableTimerCallback;
@end

@implementation MemoryPressureHandlerObjCAdapter

-(id)initWithCallback:(std::function<void (void)>)callback;
{
    self = [super init];
    if (self) {
        m_memoryPressureCallback = callback;
        m_enabled = FALSE;
    }
    return self;
}

-(void)timerOnMainThread
{
    if (m_enabled && m_memoryPressureCallback)
        m_memoryPressureCallback();
}

-(void)startTimer:(unsigned)seconds
{
    ASSERT(m_memoryPressureCallback);
    m_enabled = TRUE;
    [self performSelector:@selector(timerOnMainThread) withObject:nil afterDelay:seconds];
}

-(void)disableTimerCallback
{
    m_enabled = FALSE;
}

@end

#endif

namespace WTF {

void MemoryPressureHandler::platformReleaseMemory(Critical critical)
{
#if PLATFORM(IOS) || __MAC_OS_X_VERSION_MIN_REQUIRED >= 1070
    if (critical == Critical::Yes && (!isUnderMemoryPressure() || m_isSimulatingMemoryPressure)) {
        // libcache listens to OS memory notifications, but for process suspension
        // or memory pressure simulation, we need to prod it manually:
        cache_simulate_memory_warning_event(DISPATCH_MEMORYPRESSURE_CRITICAL);
    }
#else
    UNUSED_PARAM(critical);
#endif
}

#if PLATFORM(IOS) || __MAC_OS_X_VERSION_MIN_REQUIRED >= 1070
static dispatch_source_t _cache_event_source = 0;
static dispatch_source_t _timer_event_source = 0;
#endif
static int _notifyTokens[3] = {-1};

// Disable memory event reception for a minimum of s_minimumHoldOffTime
// seconds after receiving an event. Don't let events fire any sooner than
// s_holdOffMultiplier times the last cleanup processing time. Effectively 
// this is 1 / s_holdOffMultiplier percent of the time.
// These value seems reasonable and testing verifies that it throttles frequent
// low memory events, greatly reducing CPU usage.
static const unsigned s_minimumHoldOffTime = 5;
#if !PLATFORM(IOS)
static const unsigned s_holdOffMultiplier = 20;
#endif

void MemoryPressureHandler::install()
{
#if PLATFORM(IOS) || __MAC_OS_X_VERSION_MIN_REQUIRED >= 1070
    if (m_installed || _timer_event_source)
        return;

    dispatch_async(dispatch_get_main_queue(), ^{
#if PLATFORM(IOS)
        _cache_event_source = dispatch_source_create(DISPATCH_SOURCE_TYPE_MEMORYPRESSURE, 0, DISPATCH_MEMORYPRESSURE_NORMAL | DISPATCH_MEMORYPRESSURE_WARN | DISPATCH_MEMORYPRESSURE_CRITICAL, dispatch_get_main_queue());
#elif PLATFORM(MAC)
        _cache_event_source = dispatch_source_create(DISPATCH_SOURCE_TYPE_MEMORYPRESSURE, 0, DISPATCH_MEMORYPRESSURE_CRITICAL, dispatch_get_main_queue());
#endif

        dispatch_set_context(_cache_event_source, this);
        dispatch_source_set_event_handler(_cache_event_source, ^{
            bool critical = true;
#if PLATFORM(IOS)
            unsigned long status = dispatch_source_get_data(_cache_event_source);
            critical = status == DISPATCH_MEMORYPRESSURE_CRITICAL;
            auto& memoryPressureHandler = MemoryPressureHandler::singleton();
            bool wasCritical = memoryPressureHandler.isUnderMemoryPressure();
            memoryPressureHandler.setUnderMemoryPressure(critical);
            if (status == DISPATCH_MEMORYPRESSURE_NORMAL) {
                if (ReliefLogger::loggingEnabled())
                    NSLog(@"System is no longer under (%s) memory pressure.", wasCritical ? "critical" : "non-critical");
                return;
            }

            if (ReliefLogger::loggingEnabled())
                NSLog(@"Got memory pressure notification (%s)", critical ? "critical" : "non-critical");
#endif
            MemoryPressureHandler::singleton().respondToMemoryPressure(critical ? Critical::Yes : Critical::No);
        });
        dispatch_resume(_cache_event_source);
    });

    // Allow simulation of memory pressure with "notifyutil -p org.WebKit.lowMemory"
    notify_register_dispatch("org.WebKit.lowMemory", &_notifyTokens[0], dispatch_get_main_queue(), ^(int) {
#if ENABLE(FMW_FOOTPRINT_COMPARISON)
        auto footprintBefore = pagesPerVMTag();
#endif
        beginSimulatedMemoryPressure();

        WTF::releaseFastMallocFreeMemory();
        malloc_zone_pressure_relief(nullptr, 0);

#if ENABLE(FMW_FOOTPRINT_COMPARISON)
        auto footprintAfter = pagesPerVMTag();
        logFootprintComparison(footprintBefore, footprintAfter);
#endif

        dispatch_async(dispatch_get_main_queue(), ^{
            endSimulatedMemoryPressure();
        });
    });

    notify_register_dispatch("org.WebKit.lowMemory.begin", &_notifyTokens[1], dispatch_get_main_queue(), ^(int) {
        beginSimulatedMemoryPressure();
    });
    notify_register_dispatch("org.WebKit.lowMemory.end", &_notifyTokens[2], dispatch_get_main_queue(), ^(int) {
        endSimulatedMemoryPressure();
    });
#else
    if (m_installed)
        return;

    std::function<void (void)> callback = [] {
        bool critical = false;
        int wasNotified = 0;
        static unsigned counter = 0;
        static natural_t pageoutsPrevious = static_cast<natural_t>(0xffffffffffffffffULL);
        mach_msg_type_number_t count;

        int status = notify_check(_notifyTokens[0], &wasNotified);
        if (status == NOTIFY_STATUS_OK && wasNotified) // been forced ?
            counter++;

#if !defined(__LP64__)
        task_basic_info_data_t taskInfo;
        count = TASK_BASIC_INFO_COUNT;
        kern_return_t errTaskInfo = task_info(mach_task_self(), TASK_BASIC_INFO, (task_info_t)&taskInfo, &count);
        if (errTaskInfo == KERN_SUCCESS && taskInfo.virtual_size > 1024*1024*3584ULL) // > 3.5 GB ?
            counter++;
#endif

        vm_statistics_data_t vmInfo;
        count = HOST_VM_INFO_COUNT;
        kern_return_t errVMInfo = host_statistics(mach_host_self(), HOST_VM_INFO, (host_info_t)&vmInfo, &count);
        if (errVMInfo == KERN_SUCCESS && vmInfo.pageouts != pageoutsPrevious && pageoutsPrevious != static_cast<natural_t>(0xffffffffffffffffULL)) // paging out ?
            counter++;

        if ((errVMInfo != KERN_SUCCESS || vmInfo.pageouts == pageoutsPrevious)
#if !defined(__LP64__)
            && (errTaskInfo != KERN_SUCCESS || taskInfo.virtual_size <= 1024*1024*3584ULL)
#endif
            && (status != NOTIFY_STATUS_OK || !wasNotified))
        {
            counter = 0;
        }
        if (errVMInfo == KERN_SUCCESS)
            pageoutsPrevious = vmInfo.pageouts;
        if (counter >= 3)
            critical = true;
        if (counter == 0) {
            MemoryPressureHandler::singleton().uninstall();
            MemoryPressureHandler::singleton().holdOff(s_minimumHoldOffTime);
            return;
        }
        MemoryPressureHandler::singleton().respondToMemoryPressure(critical ? Critical::Yes : Critical::No);
    };

    if (!m_memoryPressureHandlerAdapter)
        m_memoryPressureHandlerAdapter = adoptNS([[MemoryPressureHandlerObjCAdapter alloc] initWithCallback:callback]);
    [m_memoryPressureHandlerAdapter.get() startTimer:s_minimumHoldOffTime];

    if (_notifyTokens[0] == -1) {
        notify_register_check("org.WebKit.lowMemory", &_notifyTokens[0]);
        int wasNotified;
        notify_check(_notifyTokens[0], &wasNotified);
    }
#endif

    m_installed = true;
}

void MemoryPressureHandler::uninstall()
{
    if (!m_installed)
        return;

#if PLATFORM(IOS) || __MAC_OS_X_VERSION_MIN_REQUIRED >= 1070
    dispatch_async(dispatch_get_main_queue(), ^{
        if (_cache_event_source) {
            dispatch_source_cancel(_cache_event_source);
            dispatch_release(_cache_event_source);
            _cache_event_source = 0;
        }

        if (_timer_event_source) {
            dispatch_source_cancel(_timer_event_source);
            dispatch_release(_timer_event_source);
            _timer_event_source = 0;
        }
    });
#else
    [m_memoryPressureHandlerAdapter.get() disableTimerCallback];
#endif

    m_installed = false;

#if !(PLATFORM(MAC) && __MAC_OS_X_VERSION_MIN_REQUIRED <= 1060)
    for (auto& token : _notifyTokens)
        notify_cancel(token);
#endif
}

void MemoryPressureHandler::holdOff(unsigned seconds)
{
#if PLATFORM(IOS) || __MAC_OS_X_VERSION_MIN_REQUIRED >= 1070
    dispatch_async(dispatch_get_main_queue(), ^{
        _timer_event_source = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, dispatch_get_main_queue());
        if (_timer_event_source) {
            dispatch_set_context(_timer_event_source, this);
            dispatch_source_set_timer(_timer_event_source, dispatch_time(DISPATCH_TIME_NOW, seconds * NSEC_PER_SEC), DISPATCH_TIME_FOREVER, 1 * s_minimumHoldOffTime);
            dispatch_source_set_event_handler(_timer_event_source, ^{
                if (_timer_event_source) {
                    dispatch_source_cancel(_timer_event_source);
                    dispatch_release(_timer_event_source);
                    _timer_event_source = 0;
                }
                MemoryPressureHandler::singleton().install();
            });
            dispatch_resume(_timer_event_source);
        }
    });
#else
    [m_memoryPressureHandlerAdapter.get() startTimer:seconds];
#endif
}

void MemoryPressureHandler::respondToMemoryPressure(Critical critical, Synchronous synchronous)
{
#if !PLATFORM(IOS)
    uninstall();
    double startTime = monotonicallyIncreasingTime();
#endif

    releaseMemory(critical, synchronous);

#if !PLATFORM(IOS)
    unsigned holdOffTime = (monotonicallyIncreasingTime() - startTime) * s_holdOffMultiplier;
    holdOff(std::max(holdOffTime, s_minimumHoldOffTime));
#endif
}

std::optional<MemoryPressureHandler::ReliefLogger::MemoryUsage> MemoryPressureHandler::ReliefLogger::platformMemoryUsage()
{
#if PLATFORM(IOS) || __MAC_OS_X_VERSION_MIN_REQUIRED >= 1070
    task_vm_info_data_t vmInfo;
    mach_msg_type_number_t count = TASK_VM_INFO_COUNT;
    kern_return_t err = task_info(mach_task_self(), TASK_VM_INFO, (task_info_t) &vmInfo, &count);
    if (err != KERN_SUCCESS)
        return std::nullopt;

    return MemoryUsage {static_cast<size_t>(vmInfo.internal), static_cast<size_t>(vmInfo.phys_footprint)};
#else
    return std::nullopt;
#endif
}

} // namespace WTF
