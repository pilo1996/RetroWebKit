#import <Cocoa/Cocoa.h>
#import "WebFrameLoadDelegate.h"

@class WebView;

// Leopard exposes these delegate methods as informal protocols.
@interface RetroBrowserAppDelegate : NSObject <WebFrameLoadDelegate>
{
    NSWindow *_window;
    WebView *_webView;
    NSTextField *_addressField;
}

- (void)goBack:(id)sender;
- (void)goForward:(id)sender;
- (void)reload:(id)sender;
- (void)openAddress:(id)sender;

@end
