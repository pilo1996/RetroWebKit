#import <Cocoa/Cocoa.h>

#import "RetroBrowserAppDelegate.h"

int main(int argc, const char *argv[])
{
    (void)argc;
    (void)argv;
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
    NSApplication *application = [NSApplication sharedApplication];
    RetroBrowserAppDelegate *delegate = [[RetroBrowserAppDelegate alloc] init];
    [application setDelegate:delegate];
    [application run];
    [delegate release];
    [pool drain];
    return 0;
}
