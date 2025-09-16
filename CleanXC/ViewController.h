//
//  ViewController.h
//  CleanXC
//
//  Created by chc on 2025/9/16.
//

#import <Cocoa/Cocoa.h>

@interface ViewController : NSViewController

@property (strong) NSOutlineView *outlineView;
@property (strong) NSButton *cleanButton;
@property (strong) NSButton *refreshButton;
@property (strong) NSTextField *totalSizeLabel;
@property (strong) NSProgressIndicator *progressIndicator;

- (void)cleanButtonClicked:(id)sender;
- (void)refreshButtonClicked:(id)sender;

@end

