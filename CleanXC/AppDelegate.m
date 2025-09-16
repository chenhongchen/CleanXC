//
//  AppDelegate.m
//  CleanXC
//
//  Created by chc on 2025/9/16.
//

#import "AppDelegate.h"
#import "ViewController.h"

@interface AppDelegate ()

@property (strong) ViewController *viewController;

@end

@implementation AppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
    printf("Application did finish launching\n");
    fflush(stdout);
    
    // 创建主窗口
    self.window = [[NSWindow alloc] initWithContentRect:NSMakeRect(100, 100, 600, 400)
                                              styleMask:NSWindowStyleMaskTitled | NSWindowStyleMaskClosable | NSWindowStyleMaskMiniaturizable | NSWindowStyleMaskResizable
                                                backing:NSBackingStoreBuffered
                                                  defer:NO];
    
    self.window.title = @"Xcode 缓存清理工具";
    [self.window center];
    self.window.minSize = NSMakeSize(600, 400);
    
    printf("Window created: %p\n", (__bridge void *)self.window);
    fflush(stdout);
    
    // 创建视图控制器
    self.viewController = [[ViewController alloc] init];
    self.window.contentViewController = self.viewController;
    
    printf("ViewController created: %p\n", (__bridge void *)self.viewController);
    fflush(stdout);
    
    // 显示窗口
    [self.window makeKeyAndOrderFront:nil];
    [NSApp activateIgnoringOtherApps:YES];
    [self.window orderFrontRegardless];
    [self.window setIsVisible:YES];
    
    printf("Window should be visible now\n");
    fflush(stdout);
}

- (BOOL)applicationShouldHandleReopen:(NSApplication *)sender hasVisibleWindows:(BOOL)flag {
    [NSApp activateIgnoringOtherApps:YES];
    if (self.window) {
        if (self.window.isMiniaturized) {
            [self.window deminiaturize:sender];
        }
        [self.window makeKeyAndOrderFront:sender];
    }
    return YES;
}

- (void)applicationDidBecomeActive:(NSNotification *)notification {
    if (self.window) {
        if (self.window.isMiniaturized) {
            [self.window deminiaturize:nil];
        }
        [self.window makeKeyAndOrderFront:nil];
    }
}

- (BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication *)sender {
    return YES;
}

- (void)applicationWillTerminate:(NSNotification *)aNotification {
    // Insert code here to tear down your application
}

- (BOOL)applicationSupportsSecureRestorableState:(NSApplication *)app {
    return YES;
}

@end
