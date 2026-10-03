#import "RetroBrowserAppDelegate.h"

#import "WebDataSource.h"
#import "WebFrame.h"
#import "WebView.h"

static NSString * const BackToolbarItemIdentifier = @"RetroBrowserBack";
static NSString * const ForwardToolbarItemIdentifier = @"RetroBrowserForward";
static NSString * const ReloadToolbarItemIdentifier = @"RetroBrowserReload";
static NSString * const AddressToolbarItemIdentifier = @"RetroBrowserAddress";

@implementation RetroBrowserAppDelegate

- (void)dealloc
{
    [_addressField release];
    [_webView release];
    [_window release];
    [super dealloc];
}

- (void)applicationDidFinishLaunching:(NSNotification *)notification
{
    (void)notification;
    NSRect frame = NSMakeRect(120, 120, 900, 650);
    NSUInteger style = NSTitledWindowMask | NSClosableWindowMask | NSMiniaturizableWindowMask | NSResizableWindowMask;
    _window = [[NSWindow alloc] initWithContentRect:frame styleMask:style backing:NSBackingStoreBuffered defer:NO];
    [_window setTitle:@"RetroBrowser"];
    [_window setMinSize:NSMakeSize(480, 320)];

    NSView *contentView = [_window contentView];
    _webView = [[WebView alloc] initWithFrame:[contentView bounds] frameName:@"RetroBrowserMainFrame" groupName:@"RetroBrowser"];
    [_webView setAutoresizingMask:NSViewWidthSizable | NSViewHeightSizable];
    [_webView setFrameLoadDelegate:self];
    [contentView addSubview:_webView];

    NSToolbar *toolbar = [[[NSToolbar alloc] initWithIdentifier:@"RetroBrowserToolbar"] autorelease];
    [toolbar setDelegate:self];
    [toolbar setAllowsUserCustomization:YES];
    [toolbar setAutosavesConfiguration:YES];
    [toolbar setDisplayMode:NSToolbarDisplayModeIconOnly];
    [_window setToolbar:toolbar];

    [_window makeKeyAndOrderFront:nil];
    [NSApp activateIgnoringOtherApps:YES];
    [_addressField setStringValue:@"https://example.com/"];
    [self openAddress:nil];
}

- (BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication *)sender
{
    (void)sender;
    return YES;
}

- (void)goBack:(id)sender { (void)sender; [_webView goBack]; }
- (void)goForward:(id)sender { (void)sender; [_webView goForward]; }
- (void)reload:(id)sender { (void)sender; [[_webView mainFrame] reload]; }

- (void)openAddress:(id)sender
{
    (void)sender;
    NSString *address = [_addressField stringValue];
    if (![address length])
        return;
    if ([address rangeOfString:@"://"].location == NSNotFound && ![address hasPrefix:@"about:"] && ![address hasPrefix:@"file:"])
        address = [@"http://" stringByAppendingString:address];
    NSURL *URL = [NSURL URLWithString:address];
    if (URL)
        [[_webView mainFrame] loadRequest:[NSURLRequest requestWithURL:URL]];
}

- (void)webView:(WebView *)sender didFinishLoadForFrame:(WebFrame *)frame
{
    if (frame != [sender mainFrame])
        return;
    NSString *URLString = [[[[frame dataSource] request] URL] absoluteString];
    if ([URLString length])
        [_addressField setStringValue:URLString];
    NSString *title = [sender mainFrameTitle];
    [_window setTitle:[title length] ? title : @"RetroBrowser"];
}

- (NSArray *)toolbarAllowedItemIdentifiers:(NSToolbar *)toolbar
{
    (void)toolbar;
    return [NSArray arrayWithObjects:BackToolbarItemIdentifier, ForwardToolbarItemIdentifier,
        ReloadToolbarItemIdentifier, AddressToolbarItemIdentifier,
        NSToolbarFlexibleSpaceItemIdentifier, NSToolbarSpaceItemIdentifier, nil];
}

- (NSArray *)toolbarDefaultItemIdentifiers:(NSToolbar *)toolbar
{
    (void)toolbar;
    return [NSArray arrayWithObjects:BackToolbarItemIdentifier, ForwardToolbarItemIdentifier,
        ReloadToolbarItemIdentifier, AddressToolbarItemIdentifier, nil];
}

- (NSToolbarItem *)toolbar:(NSToolbar *)toolbar itemForItemIdentifier:(NSString *)identifier willBeInsertedIntoToolbar:(BOOL)flag
{
    (void)toolbar;
    (void)flag;
    NSToolbarItem *item = [[[NSToolbarItem alloc] initWithItemIdentifier:identifier] autorelease];
    if ([identifier isEqualToString:AddressToolbarItemIdentifier]) {
        if (!_addressField) {
            _addressField = [[NSTextField alloc] initWithFrame:NSMakeRect(0, 0, 520, 24)];
            [_addressField setTarget:self];
            [_addressField setAction:@selector(openAddress:)];
        }
        [item setView:_addressField];
        [item setMinSize:NSMakeSize(180, 24)];
        [item setMaxSize:NSMakeSize(1000, 24)];
        [item setLabel:@"Address"];
        return item;
    }
    if ([identifier isEqualToString:BackToolbarItemIdentifier]) {
        [item setLabel:@"Back"];
        [item setTarget:self];
        [item setAction:@selector(goBack:)];
    } else if ([identifier isEqualToString:ForwardToolbarItemIdentifier]) {
        [item setLabel:@"Forward"];
        [item setTarget:self];
        [item setAction:@selector(goForward:)];
    } else if ([identifier isEqualToString:ReloadToolbarItemIdentifier]) {
        [item setLabel:@"Reload"];
        [item setTarget:self];
        [item setAction:@selector(reload:)];
    }
    [item setPaletteLabel:[item label]];
    return item;
}

@end
