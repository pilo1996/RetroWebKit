/*
 * Copyright (C) 2004-2017 Apple Inc. All rights reserved.
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
#import "WebCoreResourceHandleAsOperationQueueDelegate.h"

#if !USE(CFURLCONNECTION)

#import "AuthenticationChallenge.h"
#import "AuthenticationMac.h"
#import "CFNetworkSPI.h"
#import "Logging.h"
#import "ResourceHandle.h"
#import "ResourceHandleClient.h"
#import "ResourceRequest.h"
#import "ResourceResponse.h"
#import "SharedBuffer.h"
#import "WebCoreURLResponse.h"
#import <wtf/MainThread.h>

using namespace WebCore;

@implementation WebCoreResourceHandleAsOperationQueueDelegate

- (id)initWithHandle:(ResourceHandle*)handle
{
    self = [self init];
    if (!self)
        return nil;

    m_handle = handle;
#if __MAC_OS_X_VERSION_MIN_REQUIRED >= 1070
    m_semaphore = dispatch_semaphore_create(0);
#else
    ASSERT_NOT_REACHED();
#endif

    return self;
}

- (void)detachHandle
{
    m_handle = nullptr;

    m_requestResult = nullptr;
    m_cachedResponseResult = nullptr;
    m_boolResult = NO;
#if __MAC_OS_X_VERSION_MIN_REQUIRED >= 1070
    dispatch_semaphore_signal(m_semaphore); // OK to signal even if we are not waiting.
#else
    ASSERT_NOT_REACHED();
#endif
}

- (void)dealloc
{
#if __MAC_OS_X_VERSION_MIN_REQUIRED >= 1070
    dispatch_release(m_semaphore);
#else
    ASSERT_NOT_REACHED();
#endif
    [super dealloc];
}

- (void)continueWillSendRequest:(NSURLRequest *)newRequest
{
    m_requestResult = newRequest;
#if __MAC_OS_X_VERSION_MIN_REQUIRED >= 1070
    dispatch_semaphore_signal(m_semaphore);
#else
    ASSERT_NOT_REACHED();
#endif
}

- (void)continueDidReceiveResponse
{
#if __MAC_OS_X_VERSION_MIN_REQUIRED >= 1070
    dispatch_semaphore_signal(m_semaphore);
#else
    ASSERT_NOT_REACHED();
#endif
}

- (void)continueCanAuthenticateAgainstProtectionSpace:(BOOL)canAuthenticate
{
    m_boolResult = canAuthenticate;
#if __MAC_OS_X_VERSION_MIN_REQUIRED >= 1070
    dispatch_semaphore_signal(m_semaphore);
#else
    ASSERT_NOT_REACHED();
#endif
}

- (void)continueWillCacheResponse:(NSCachedURLResponse *)response
{
    m_cachedResponseResult = response;
#if __MAC_OS_X_VERSION_MIN_REQUIRED >= 1070
    dispatch_semaphore_signal(m_semaphore);
#else
    ASSERT_NOT_REACHED();
#endif
}

- (NSURLRequest *)connection:(NSURLConnection *)connection willSendRequest:(NSURLRequest *)newRequest redirectResponse:(NSURLResponse *)redirectResponse
{
    ASSERT(!isMainThread());
    UNUSED_PARAM(connection);

#if !PLATFORM(IOS) && __MAC_OS_X_VERSION_MIN_REQUIRED <= 1070
    redirectResponse = synthesizeRedirectResponseIfNecessary(m_handle, newRequest, redirectResponse);
#else
    redirectResponse = synthesizeRedirectResponseIfNecessary([connection currentRequest], newRequest, redirectResponse);
#endif

    // See <rdar://problem/5380697>. This is a workaround for a behavior change in CFNetwork where willSendRequest gets called more often.
    if (!redirectResponse)
        return newRequest;

#if !LOG_DISABLED
    if ([redirectResponse isKindOfClass:[NSHTTPURLResponse class]])
        LOG(Network, "Handle %p delegate connection:%p willSendRequest:%@ redirectResponse:%d, Location:<%@>", m_handle, connection, [newRequest description], static_cast<int>([(id)redirectResponse statusCode]), [[(id)redirectResponse allHeaderFields] objectForKey:@"Location"]);
    else
        LOG(Network, "Handle %p delegate connection:%p willSendRequest:%@ redirectResponse:non-HTTP", m_handle, connection, [newRequest description]); 
#endif

#if __MAC_OS_X_VERSION_MIN_REQUIRED >= 1070
    RetainPtr<id> protector(self);

    dispatch_async(dispatch_get_main_queue(), ^{
        if (!m_handle) {
            m_requestResult = nullptr;
            dispatch_semaphore_signal(m_semaphore);
            return;
        }

        m_handle->willSendRequest(newRequest, redirectResponse);
    });

    dispatch_semaphore_wait(m_semaphore, DISPATCH_TIME_FOREVER);
#else
    ASSERT_NOT_REACHED();
#endif
    return m_requestResult.autorelease();
}

- (void)connection:(NSURLConnection *)connection didReceiveAuthenticationChallenge:(NSURLAuthenticationChallenge *)challenge
{
    ASSERT(!isMainThread());
    UNUSED_PARAM(connection);

    LOG(Network, "Handle %p delegate connection:%p didReceiveAuthenticationChallenge:%p", m_handle, connection, challenge);

#if __MAC_OS_X_VERSION_MIN_REQUIRED >= 1070
    dispatch_async(dispatch_get_main_queue(), ^{
        if (!m_handle) {
            [[challenge sender] cancelAuthenticationChallenge:challenge];
            return;
        }
        m_handle->didReceiveAuthenticationChallenge(core(challenge));
    });
#else
    UNUSED_PARAM(challenge);
    ASSERT_NOT_REACHED();
#endif
}

#if USE(PROTECTION_SPACE_AUTH_CALLBACK)
- (BOOL)connection:(NSURLConnection *)connection canAuthenticateAgainstProtectionSpace:(NSURLProtectionSpace *)protectionSpace
{
    ASSERT(!isMainThread());
    UNUSED_PARAM(connection);

    LOG(Network, "Handle %p delegate connection:%p canAuthenticateAgainstProtectionSpace:%@://%@:%u realm:%@ method:%@ %@%@", m_handle, connection, [protectionSpace protocol], [protectionSpace host], [protectionSpace port], [protectionSpace realm], [protectionSpace authenticationMethod], [protectionSpace isProxy] ? @"proxy:" : @"", [protectionSpace isProxy] ? [protectionSpace proxyType] : @"");

    RetainPtr<id> protector(self);

#if __MAC_OS_X_VERSION_MIN_REQUIRED >= 1070
    dispatch_async(dispatch_get_main_queue(), ^{
        if (!m_handle) {
            m_boolResult = NO;
            dispatch_semaphore_signal(m_semaphore);
            return;
        }
        m_handle->canAuthenticateAgainstProtectionSpace(ProtectionSpace(protectionSpace));
    });

    dispatch_semaphore_wait(m_semaphore, DISPATCH_TIME_FOREVER);
#else
    ASSERT_NOT_REACHED();
#endif
    return m_boolResult;
}
#endif

- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)r
{
    ASSERT(!isMainThread());

    LOG(Network, "Handle %p delegate connection:%p didReceiveResponse:%p (HTTP status %d, reported MIMEType '%s')", m_handle, connection, r, [r respondsToSelector:@selector(statusCode)] ? [(id)r statusCode] : 0, [[r MIMEType] UTF8String]);

#if __MAC_OS_X_VERSION_MIN_REQUIRED >= 1070
    RetainPtr<id> protector(self);

    dispatch_async(dispatch_get_main_queue(), ^{
        if (!m_handle || !m_handle->client()) {
            dispatch_semaphore_signal(m_semaphore);
            return;
        }

        // Avoid MIME type sniffing if the response comes back as 304 Not Modified.
        int statusCode = [r respondsToSelector:@selector(statusCode)] ? [(id)r statusCode] : 0;
        if (statusCode != 304) {
            bool isMainResourceLoad = m_handle->firstRequest().requester() == ResourceRequest::Requester::Main;
            adjustMIMETypeIfNecessary([r _CFURLResponse], isMainResourceLoad);
        }

        if ([m_handle->firstRequest().nsURLRequest(DoNotUpdateHTTPBody) _propertyForKey:@"ForceHTMLMIMEType"])
            [r _setMIMEType:@"text/html"];
        
        ResourceResponse resourceResponse(r);
#if ENABLE(WEB_TIMING)
        ResourceHandle::getConnectionTimingData(connection, resourceResponse.deprecatedNetworkLoadMetrics());
#else
        UNUSED_PARAM(connection);
#endif
        m_handle->didReceiveResponse(WTFMove(resourceResponse));
    });

    dispatch_semaphore_wait(m_semaphore, DISPATCH_TIME_FOREVER);
#else
    ASSERT_NOT_REACHED();
    UNUSED_PARAM(r);
    UNUSED_PARAM(connection);
#endif

}

- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data lengthReceived:(long long)lengthReceived
{
    ASSERT(!isMainThread());
    UNUSED_PARAM(connection);
    UNUSED_PARAM(lengthReceived);

    LOG(Network, "Handle %p delegate connection:%p didReceiveData:%p lengthReceived:%lld", m_handle, connection, data, lengthReceived);

#if __MAC_OS_X_VERSION_MIN_REQUIRED >= 1070
    dispatch_async(dispatch_get_main_queue(), ^{
        if (!m_handle || !m_handle->client())
            return;
        // FIXME: If we get more than 2B bytes in a single chunk, this code won't do the right thing.
        // However, with today's computers and networking speeds, this won't happen in practice.
        // Could be an issue with a giant local file.

        // FIXME: https://bugs.webkit.org/show_bug.cgi?id=19793
        // -1 means we do not provide any data about transfer size to inspector so it would use
        // Content-Length headers or content size to show transfer size.
        m_handle->client()->didReceiveBuffer(m_handle, SharedBuffer::create(data), -1);
    });
#else
    UNUSED_PARAM(data);
    ASSERT_NOT_REACHED();
#endif
}

- (void)connection:(NSURLConnection *)connection didSendBodyData:(NSInteger)bytesWritten totalBytesWritten:(NSInteger)totalBytesWritten totalBytesExpectedToWrite:(NSInteger)totalBytesExpectedToWrite
{
    ASSERT(!isMainThread());
    UNUSED_PARAM(connection);
    UNUSED_PARAM(bytesWritten);

    LOG(Network, "Handle %p delegate connection:%p didSendBodyData:%d totalBytesWritten:%d totalBytesExpectedToWrite:%d", m_handle, connection, bytesWritten, totalBytesWritten, totalBytesExpectedToWrite);

#if __MAC_OS_X_VERSION_MIN_REQUIRED >= 1070
    dispatch_async(dispatch_get_main_queue(), ^{
        if (!m_handle || !m_handle->client())
            return;
        m_handle->client()->didSendData(m_handle, totalBytesWritten, totalBytesExpectedToWrite);
    });
#else
    UNUSED_PARAM(totalBytesWritten);
    UNUSED_PARAM(totalBytesExpectedToWrite);
    ASSERT_NOT_REACHED();
#endif
}

- (void)connectionDidFinishLoading:(NSURLConnection *)connection
{
    ASSERT(!isMainThread());
    UNUSED_PARAM(connection);

    LOG(Network, "Handle %p delegate connectionDidFinishLoading:%p", m_handle, connection);

#if __MAC_OS_X_VERSION_MIN_REQUIRED >= 1070
    dispatch_async(dispatch_get_main_queue(), ^{
        if (!m_handle || !m_handle->client())
            return;

        m_handle->client()->didFinishLoading(m_handle);
    });
#else
    ASSERT_NOT_REACHED();
#endif
}

- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error
{
    ASSERT(!isMainThread());
    UNUSED_PARAM(connection);

    LOG(Network, "Handle %p delegate connection:%p didFailWithError:%@", m_handle, connection, error);

#if __MAC_OS_X_VERSION_MIN_REQUIRED >= 1070
    dispatch_async(dispatch_get_main_queue(), ^{
        if (!m_handle || !m_handle->client())
            return;

        m_handle->client()->didFail(m_handle, error);
    });
#else
    UNUSED_PARAM(error);
    ASSERT_NOT_REACHED();
#endif
}


- (NSCachedURLResponse *)connection:(NSURLConnection *)connection willCacheResponse:(NSCachedURLResponse *)cachedResponse
{
    ASSERT(!isMainThread());
    UNUSED_PARAM(connection);

    LOG(Network, "Handle %p delegate connection:%p willCacheResponse:%p", m_handle, connection, cachedResponse);

#if __MAC_OS_X_VERSION_MIN_REQUIRED >= 1070
    RetainPtr<id> protector(self);

    dispatch_async(dispatch_get_main_queue(), ^{
        if (!m_handle || !m_handle->client()) {
            m_cachedResponseResult = nullptr;
            dispatch_semaphore_signal(m_semaphore);
            return;
        }

        // Workaround for <rdar://problem/6300990> Caching does not respect Vary HTTP header.
        // FIXME: WebCore cache has issues with Vary, too (bug 58797, bug 71509).
        if ([[cachedResponse response] isKindOfClass:[NSHTTPURLResponse class]]
            && [[(NSHTTPURLResponse *)[cachedResponse response] allHeaderFields] objectForKey:@"Vary"]) {
            m_cachedResponseResult = nullptr;
            dispatch_semaphore_signal(m_semaphore);
            return;
        }

        m_handle->client()->willCacheResponseAsync(m_handle, cachedResponse);
    });

    dispatch_semaphore_wait(m_semaphore, DISPATCH_TIME_FOREVER);
#else
    UNUSED_PARAM(cachedResponse);
    ASSERT_NOT_REACHED();
#endif
    return m_cachedResponseResult.autorelease();
}

@end

@implementation WebCoreResourceHandleWithCredentialStorageAsOperationQueueDelegate

- (BOOL)connectionShouldUseCredentialStorage:(NSURLConnection *)connection
{
    ASSERT(!isMainThread());
    UNUSED_PARAM(connection);
    return NO;
}

@end

#endif // !USE(CFURLCONNECTION)

