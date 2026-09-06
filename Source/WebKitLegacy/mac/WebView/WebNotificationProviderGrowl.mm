/*
 * Copyright (C) 2012 Apple Inc. All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 *
 * 1.  Redistributions of source code must retain the above copyright
 *     notice, this list of conditions and the following disclaimer.
 * 2.  Redistributions in binary form must reproduce the above copyright
 *     notice, this list of conditions and the following disclaimer in the
 *     documentation and/or other materials provided with the distribution.
 * 3.  Neither the name of Apple Inc. ("Apple") nor the names of
 *     its contributors may be used to endorse or promote products derived
 *     from this software without specific prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY APPLE AND ITS CONTRIBUTORS "AS IS" AND ANY
 * EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
 * WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
 * DISCLAIMED. IN NO EVENT SHALL APPLE OR ITS CONTRIBUTORS BE LIABLE FOR ANY
 * DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
 * (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
 * LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
 * ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
 * (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF
 * THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

#import "WebNotificationProviderGrowl.h"

#import <WebIconDatabase.h>
#import <WebSecurityOriginPrivate.h>

#if ENABLE(NOTIFICATIONS)
#import <WebCore/NotificationPermissionCallback.h>
#endif
#if ENABLE(LEGACY_NOTIFICATIONS)
#import <WebCore/VoidCallback.h>
#endif

static IMP originalWasClickedImp = 0;
static IMP originalTimedOutImp = 0;

static void wasClicked(NSObject<GrowlApplicationBridgeDelegate> *self, SEL selector, id clickContext)
{
    [[WebNotificationProviderGrowl shared] growlNotificationWasClicked:clickContext];
    if (originalWasClickedImp)
        originalWasClickedImp(self, selector, clickContext);
}

static void timedOut(NSObject<GrowlApplicationBridgeDelegate> *self, SEL selector, id clickContext)
{
    [[WebNotificationProviderGrowl shared] growlNotificationTimedOut:clickContext];
    if (originalTimedOutImp)
        originalTimedOutImp(self, selector, clickContext);
}

static RetainPtr<NSMutableDictionary> addWebNotificationToBestRegistrationDictionary()
{
    RetainPtr<NSDictionary> registrationDictionary = [GrowlApplicationBridge bestRegistrationDictionary];
    RetainPtr<NSMutableDictionary> newRegistrationDictionary = adoptNS([registrationDictionary.get() mutableCopy]);
    RetainPtr<NSMutableArray> allNotifications = adoptNS([[registrationDictionary.get() objectForKey:@"AllNotifications"] mutableCopy]);
    RetainPtr<NSMutableArray> defaultNotifications = adoptNS([[registrationDictionary.get() objectForKey:@"DefaultNotifications"] mutableCopy]);
    [allNotifications.get() addObject:@"WebNotification"];
    [defaultNotifications.get() addObject:@"WebNotification"];
    [newRegistrationDictionary.get() setObject:allNotifications.get() forKey:@"AllNotifications"];
    [newRegistrationDictionary.get() setObject:defaultNotifications.get() forKey:@"DefaultNotifications"];

    return newRegistrationDictionary;
}

@implementation WebNotificationProviderGrowl

+ (WebNotificationProviderGrowl *)shared
{
    static WebNotificationProviderGrowl *provider = [[WebNotificationProviderGrowl alloc] init];
    return provider;
}

- (id)init
{
    if (!(self = [super init]))
        return nil;
    _permissions = adoptNS([[NSMutableDictionary alloc] init]);
    _suppressions = adoptNS([[NSMutableDictionary alloc] init]);

    [GrowlApplicationBridge setGrowlDelegate:self];

    return self;
}

- (void)registerWebView:(WebView *)webView
{
    ASSERT(!_registeredWebViews.contains(webView));
    _registeredWebViews.add(webView);
}

- (void)unregisterWebView:(WebView *)webView
{
    ASSERT(_registeredWebViews.contains(webView));
    _registeredWebViews.remove(webView);
}

- (void)showNotification:(WebNotification *)notification fromWebView:(WebView *)webView
{
    ASSERT(_registeredWebViews.contains(webView));

    uint64_t notificationID = [notification notificationID];
    _notifications.add(notificationID, notification);
    _notificationViewMap.add(notificationID, webView);

    NSData *iconData = nil;
    NSImage *icon = [[WebIconDatabase sharedIconDatabase] iconForURL:[notification iconURL] withSize:WebIconSmallSize];
    if (icon)
        iconData = [icon TIFFRepresentation];

    // this part patches an application's own delegate to call our wasClicked and timedOut methods and adds our notification to the dictionary
    // FIXME: - in case the application's delegate doesn't implement both wasClicked and timedOut this is done once for every web notification
    //        - application's dictionary entries might get lost in case the application uses +[GrowlApplicationBridge registerWithDictionary:] to dynamically (de)register notifications at runtime
    //          -> this could be solved by also patching +[GrowlApplicationBridge registerWithDictionary:] and add our notification to the passed dictionary
    //        - no checks are done whether or not the AllNotifications or DefaultNotifications arrays are actually present in the existing registration dictionary
    NSObject<GrowlApplicationBridgeDelegate> *growlDelegate = [GrowlApplicationBridge growlDelegate];
    if (growlDelegate
        && growlDelegate != self
        && !originalWasClickedImp
        && !originalTimedOutImp)
    {
        Method methodWasClicked = class_getInstanceMethod([growlDelegate class], @selector(growlNotificationWasClicked:));
        if (methodWasClicked)
            originalWasClickedImp = method_setImplementation(methodWasClicked, reinterpret_cast<IMP>(wasClicked));
        else
            class_addMethod([growlDelegate class], @selector(growlNotificationWasClicked:), reinterpret_cast<IMP>(wasClicked), method_getTypeEncoding(class_getInstanceMethod([self class], @selector(growlNotificationWasClicked:))));

        Method methodTimedOut = class_getInstanceMethod([growlDelegate class], @selector(growlNotificationTimedOut:));
        if (methodTimedOut)
            originalTimedOutImp = method_setImplementation(methodTimedOut, reinterpret_cast<IMP>(timedOut));
        else
            class_addMethod([growlDelegate class], @selector(growlNotificationTimedOut:), reinterpret_cast<IMP>(timedOut), method_getTypeEncoding(class_getInstanceMethod([self class], @selector(growlNotificationTimedOut:))));

        // have Growl reread the patched delegate in order to have it call the changed and/or added method implementations
        [GrowlApplicationBridge setGrowlDelegate:growlDelegate];

        // register our patched registration dictionary with Growl
        [GrowlApplicationBridge registerWithDictionary:addWebNotificationToBestRegistrationDictionary().get()];
    } else {
        static NSDictionary *registrationDictionaryFromBundle = [GrowlApplicationBridge registrationDictionaryFromBundle:nil];
        if (registrationDictionaryFromBundle != nil)
            // register our patched registration dictionary with Growl
            [GrowlApplicationBridge registerWithDictionary:addWebNotificationToBestRegistrationDictionary().get()];
    }

    NSString *tag = [notification tag];
    if ([tag isEqualToString:@""])
        [GrowlApplicationBridge notifyWithTitle:[notification title] /* notifyWithTitle is a required parameter */
                                    description:[notification body] /* description is a required parameter */
                               notificationName:@"WebNotification" /* notification name is a required parameter, and must exist in the dictionary we registered with growl */
                                       iconData:iconData /* not required, growl defaults to using the application icon, only needed if you want to specify an icon. */
                                       priority:0 /* how high of priority the alert is, 0 is default */
                                       isSticky:NO /* indicates if we want the alert to stay on screen till clicked */
                                   clickContext:[NSNumber numberWithUnsignedLongLong:notificationID]]; /* click context is passed to the delegate methods, nil for none */
    else
        [GrowlApplicationBridge notifyWithTitle:[notification title] /* notifyWithTitle is a required parameter */
                                    description:[notification body] /* description is a required parameter */
                               notificationName:@"WebNotification" /* notification name is a required parameter, and must exist in the dictionary we registered with growl */
                                       iconData:iconData /* not required, growl defaults to using the application icon, only needed if you want to specify an icon. */
                                       priority:0 /* how high of priority the alert is, 0 is default */
                                       isSticky:NO /* indicates if we want the alert to stay on screen till clicked */
                                   clickContext:[NSNumber numberWithUnsignedLongLong:notificationID] /* click context is passed to the delegate methods, nil for none */
                                     identifier:[notification tag]]; /* An identifier for this notification. Notifications with equal identifiers are coalesced. */

    [webView _notificationDidShow:notificationID];
}

- (void)cancelNotification:(WebNotification *)notification
{
    uint64_t notificationID = [notification notificationID];
    ASSERT(_notifications.contains(notificationID));

    [_notificationViewMap.get(notificationID) _notificationsDidClose:[NSArray arrayWithObject:[NSNumber numberWithUnsignedLongLong:notificationID]]];
}

- (void)notificationDestroyed:(WebNotification *)notification
{
    _notifications.remove([notification notificationID]);
    _notificationViewMap.remove([notification notificationID]);
}

- (void)clearNotifications:(NSArray *)notificationIDs
{
    NSEnumerator *enumerator = [notificationIDs objectEnumerator];
    NSNumber *notificationID;
    while ((notificationID = [enumerator nextObject])) {
        uint64_t id = [notificationID unsignedLongLongValue];
        RetainPtr<WebNotification> notification = _notifications.take(id);
        _notificationViewMap.remove(id);
    }
}

- (void)webView:(WebView *)webView didShowNotification:(uint64_t)notificationID
{
    [_notifications.get(notificationID).get() dispatchShowEvent];
}

- (void)webView:(WebView *)webView didClickNotification:(uint64_t)notificationID
{
    [_notifications.get(notificationID).get() dispatchClickEvent];
}

- (void)webView:(WebView *)webView didCloseNotifications:(NSArray *)notificationIDs
{
    NSEnumerator *enumerator = [notificationIDs objectEnumerator];
    NSNumber *notificationID;
    while ((notificationID = [enumerator nextObject])) {
        uint64_t id = [notificationID unsignedLongLongValue];
        NotificationIDMap::iterator it = _notifications.find(id);
        ASSERT(it != _notifications.end());
        [it->value.get() dispatchCloseEvent];
        _notifications.remove(it);
        _notificationViewMap.remove(id);
    }
}

- (WebNotificationPermission)policyForOrigin:(WebSecurityOrigin *)origin
{
    NSNumber *permission = [_permissions.get() objectForKey:[origin stringValue]];
    if (!permission)
        return WebNotificationPermissionNotAllowed;
    if ([permission boolValue])
        return WebNotificationPermissionAllowed;
    return WebNotificationPermissionDenied;
}

- (BOOL)isOriginSuppressed:(WebSecurityOrigin *)origin
{
    NSNumber *suppression = [_suppressions.get() objectForKey:[origin stringValue]];
    if (!suppression || ![suppression boolValue])
        return FALSE;
    return TRUE;
}

- (void)setWebNotificationOrigin:(NSString *)origin permission:(BOOL)allowed suppress:(BOOL)suppressed
{
    [_permissions.get() setObject:[NSNumber numberWithBool:allowed] forKey:origin];
    [_suppressions.get() setObject:[NSNumber numberWithBool:suppressed] forKey:origin];
}

/* Begin methods from GrowlApplicationBridgeDelegate */
- (NSDictionary *)registrationDictionaryForGrowl { /* Only implement this method if you do not plan on just placing a plist with the same data in your app bundle (see growl documentation) */
    static NSString *bundleIdentifier = nil;
    if (bundleIdentifier == nil) {
        NSBundle *mainBundle = [NSBundle mainBundle];
        if (mainBundle != nil) {
            NSDictionary *infoDictionary = [mainBundle infoDictionary];
            if (infoDictionary != nil) {
                bundleIdentifier = [infoDictionary objectForKey:@"CFBundleIdentifier"];
                if (bundleIdentifier == nil) {
                    bundleIdentifier = [[infoDictionary objectForKey:@"CFBundleExecutablePath"] lastPathComponent];
                }
            }
        }
    }

    NSArray *array = [NSArray arrayWithObjects:@"WebNotification", nil]; /* each string represents a notification name that will be valid for us to use in alert methods */
    NSDictionary *dict = [NSDictionary dictionaryWithObjectsAndKeys:
                          bundleIdentifier,
                          @"ApplicationId",
                          [NSNumber numberWithInt:1], /* growl 0.7 through growl 1.1 use ticket version 1 */
                          @"TicketVersion", /* Required key in dictionary */
                          array, /* defines which notification names our application can use */
                          @"AllNotifications", /* Required key in dictionary */
                          array, /* using the same array sets all notification names on by default */
                          @"DefaultNotifications", /* Required key in dictionary */
                          nil];
    return dict;
}

- (void)growlNotificationWasClicked:(id)clickContext {
    if (clickContext && [clickContext isKindOfClass:[NSNumber class]]) {
        uint64_t notificationID = [(NSNumber *)clickContext unsignedLongLongValue];
        [_notificationViewMap.get(notificationID) _notificationDidClick:notificationID];
        [_notificationViewMap.get(notificationID) _notificationsDidClose:[NSArray arrayWithObjects:clickContext, nil]];
    }
    return;
}

- (void)growlNotificationTimedOut:(id)clickContext {
    if (clickContext && [clickContext isKindOfClass:[NSNumber class]]) {
        uint64_t notificationID = [(NSNumber *)clickContext unsignedLongLongValue];
        [_notificationViewMap.get(notificationID) _notificationsDidClose:[NSArray arrayWithObjects:clickContext, nil]];
    }
    return;
}

/* These methods are not required to be implemented, so we will skip them in this example 
- (NSString *) applicationNameForGrowl;
- (NSData *) applicationIconDataForGrowl;
*/ 
/* There is no good reason not to rely on the what Growl provides for the next two methods, in otherwords, do not override these methods
- (void) growlIsReady;
- (void) growlIsInstalled;
*/
/* End Methods from GrowlApplicationBridgeDelegate */

@end

@implementation WebNotificationPolicyListenerGrowl

#if ENABLE(NOTIFICATIONS)
- (id)initWithCallback:(RefPtr<WebCore::NotificationPermissionCallback>&&)callback origin:(WebSecurityOrigin *)origin
{
    if (!(self = [super initWithCallback:WTFMove(callback)]))
        return nil;

    [origin retain];
    _origin = origin;
    return self;
}
#endif

#if ENABLE(LEGACY_NOTIFICATIONS)
- (id)initWithVoidCallback:(RefPtr<WebCore::VoidCallback>&&)callback origin:(WebSecurityOrigin *)origin
{
    if (!(self = [super initWithVoidCallback:callback]))
        return nil;

    [origin retain];
    _origin = origin;
    return self;
}
#endif
            

- (void)alertDidEnd:(NSAlert *)alert returnCode:(NSInteger)returnCode contextInfo:(void *)contextInfo
{
    [[WebNotificationProviderGrowl shared] setWebNotificationOrigin:[_origin stringValue] permission:(returnCode == NSAlertFirstButtonReturn) suppress:([[alert suppressionButton] state] == NSOnState)];
    [alert release];

    if (returnCode == NSAlertFirstButtonReturn)
        [self allow];
    else
        [self deny];

    [self release];
}

- (WebSecurityOrigin *)origin
{
    return _origin;
}

- (void)dealloc
{
    [_origin release];
    _origin = nil;
    [super dealloc];
}

@end
