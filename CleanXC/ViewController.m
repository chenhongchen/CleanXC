//
//  ViewController.m
//  CleanXC
//
//  Created by chc on 2025/9/16.
//

#import "ViewController.h"

@interface ViewController () <NSOutlineViewDataSource, NSOutlineViewDelegate>

@property (nonatomic, strong) NSMutableArray *cleanItems; // root items
@property (nonatomic, strong) NSMutableSet *selectedDeviceSupportChildren; // full paths
@property (nonatomic, strong) NSMutableSet *selectedRootPaths; // root paths selected for cleanup
@property (nonatomic, strong) NSOperationQueue *operationQueue;

@end

@implementation ViewController

- (void)loadView {
    // 创建主视图
    self.view = [[NSView alloc] initWithFrame:NSMakeRect(0, 0, 800, 600)];
    self.view.wantsLayer = YES;
    self.view.layer.backgroundColor = [NSColor controlBackgroundColor].CGColor;
}

- (void)viewDidLoad {
    [super viewDidLoad];

    NSLog(@"ViewController viewDidLoad called");
    
    [self setupUI];
    [self setupCleanItems];
    [self calculateSizes];
    
    NSLog(@"ViewController setup completed");
}

- (void)setupUI {
    // 创建标题标签
    NSTextField *titleLabel = [[NSTextField alloc] init];
    titleLabel.stringValue = @"Xcode 缓存清理工具";
    titleLabel.font = [NSFont boldSystemFontOfSize:24];
    titleLabel.textColor = [NSColor labelColor];
    titleLabel.backgroundColor = [NSColor clearColor];
    titleLabel.bordered = NO;
    titleLabel.editable = NO;
    titleLabel.selectable = NO;
    titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:titleLabel];
    
    // 创建可展开的 outlineView
    self.outlineView = [[NSOutlineView alloc] init];
    self.outlineView.dataSource = self;
    self.outlineView.delegate = self;
    self.outlineView.headerView = [[NSTableHeaderView alloc] init];
    self.outlineView.translatesAutoresizingMaskIntoConstraints = NO;
    
    // 创建表格列
    NSTableColumn *nameColumn = [[NSTableColumn alloc] initWithIdentifier:@"name"];
    nameColumn.title = @"目录名称";
    nameColumn.width = 150;
    nameColumn.minWidth = 100;
    nameColumn.maxWidth = 200;
    [self.outlineView addTableColumn:nameColumn];
    
    NSTableColumn *pathColumn = [[NSTableColumn alloc] initWithIdentifier:@"path"];
    pathColumn.title = @"路径";
    pathColumn.width = 300;
    pathColumn.minWidth = 200;
    pathColumn.maxWidth = 500;
    [self.outlineView addTableColumn:pathColumn];
    
    NSTableColumn *sizeColumn = [[NSTableColumn alloc] initWithIdentifier:@"size"];
    sizeColumn.title = @"大小";
    sizeColumn.width = 120;
    sizeColumn.minWidth = 80;
    sizeColumn.maxWidth = 150;
    [self.outlineView addTableColumn:sizeColumn];
    
    NSTableColumn *statusColumn = [[NSTableColumn alloc] initWithIdentifier:@"status"];
    statusColumn.title = @"状态";
    statusColumn.width = 120;
    statusColumn.minWidth = 80;
    statusColumn.maxWidth = 150;
    [self.outlineView addTableColumn:statusColumn];
    
    NSTableColumn *descriptionColumn = [[NSTableColumn alloc] initWithIdentifier:@"description"];
    descriptionColumn.title = @"描述";
    descriptionColumn.width = 200;
    descriptionColumn.minWidth = 150;
    descriptionColumn.maxWidth = 300;
    [self.outlineView addTableColumn:descriptionColumn];

    // 复选列（添加更宽的列，便于根据层级缩进）
    NSTableColumn *checkColumn = [[NSTableColumn alloc] initWithIdentifier:@"checked"];
    checkColumn.title = @"选择";
    checkColumn.width = 60;
    checkColumn.minWidth = 40;
    [self.outlineView addTableColumn:checkColumn];
    // 把复选列移动到最左边，确保可见
    [self.outlineView moveColumn:self.outlineView.numberOfColumns - 1 toColumn:0];
    // 指定“目录名称”列作为大纲列，确保展开箭头始终在名称列
    self.outlineView.outlineTableColumn = nameColumn;
    // 行高稍微增大，便于勾选框垂直居中
    self.outlineView.rowHeight = 22.0;
    
    // 创建滚动视图
    NSScrollView *scrollView = [[NSScrollView alloc] init];
    scrollView.documentView = self.outlineView;
    scrollView.hasVerticalScroller = YES;
    scrollView.hasHorizontalScroller = YES;
    scrollView.autohidesScrollers = YES;
    scrollView.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:scrollView];
    
    // 创建总大小标签
    self.totalSizeLabel = [[NSTextField alloc] init];
    self.totalSizeLabel.stringValue = @"总大小: 计算中...";
    self.totalSizeLabel.font = [NSFont systemFontOfSize:16];
    self.totalSizeLabel.textColor = [NSColor labelColor];
    self.totalSizeLabel.backgroundColor = [NSColor clearColor];
    self.totalSizeLabel.bordered = NO;
    self.totalSizeLabel.editable = NO;
    self.totalSizeLabel.selectable = NO;
    self.totalSizeLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:self.totalSizeLabel];
    
    // 创建进度指示器
    self.progressIndicator = [[NSProgressIndicator alloc] init];
    self.progressIndicator.style = NSProgressIndicatorStyleSpinning;
    self.progressIndicator.hidden = YES;
    self.progressIndicator.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:self.progressIndicator];
    
    // 创建清理按钮
    self.cleanButton = [[NSButton alloc] init];
    self.cleanButton.title = @"一键清理";
    self.cleanButton.bezelStyle = NSBezelStyleRounded;
    self.cleanButton.target = self;
    self.cleanButton.action = @selector(cleanButtonClicked:);
    self.cleanButton.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:self.cleanButton];
    
    // 创建刷新按钮
    self.refreshButton = [[NSButton alloc] init];
    self.refreshButton.title = @"刷新";
    self.refreshButton.bezelStyle = NSBezelStyleRounded;
    self.refreshButton.target = self;
    self.refreshButton.action = @selector(refreshButtonClicked:);
    self.refreshButton.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:self.refreshButton];
    
    // 设置约束
    [NSLayoutConstraint activateConstraints:@[
        // 标题标签约束
        [titleLabel.topAnchor constraintEqualToAnchor:self.view.topAnchor constant:20],
        [titleLabel.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:20],
        
        // 滚动视图约束
        [scrollView.topAnchor constraintEqualToAnchor:titleLabel.bottomAnchor constant:20],
        [scrollView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:20],
        [scrollView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-20],
        [scrollView.bottomAnchor constraintEqualToAnchor:self.totalSizeLabel.topAnchor constant:-20],
        
        // 总大小标签约束
        [self.totalSizeLabel.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:20],
        [self.totalSizeLabel.bottomAnchor constraintEqualToAnchor:self.cleanButton.topAnchor constant:-20],
        
        // 进度指示器约束
        [self.progressIndicator.centerYAnchor constraintEqualToAnchor:self.totalSizeLabel.centerYAnchor],
        [self.progressIndicator.leadingAnchor constraintEqualToAnchor:self.totalSizeLabel.trailingAnchor constant:20],
        
        // 清理按钮约束
        [self.cleanButton.trailingAnchor constraintEqualToAnchor:self.refreshButton.leadingAnchor constant:-10],
        [self.cleanButton.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor constant:-20],
        [self.cleanButton.widthAnchor constraintEqualToConstant:100],
        
        // 刷新按钮约束
        [self.refreshButton.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-20],
        [self.refreshButton.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor constant:-20],
        [self.refreshButton.widthAnchor constraintEqualToConstant:80]
    ]];
    
    // 设置操作队列
    self.operationQueue = [[NSOperationQueue alloc] init];
    self.operationQueue.maxConcurrentOperationCount = 1;

    self.selectedDeviceSupportChildren = [NSMutableSet set];
    self.selectedRootPaths = [NSMutableSet set];
}

- (void)setupCleanItems {
    self.cleanItems = [NSMutableArray array];
    
    // 定义需要清理的目录
    NSArray *paths = @[
        @{@"name": @"DerivedData", @"path": [NSHomeDirectory() stringByAppendingPathComponent:@"Library/Developer/Xcode/DerivedData"], @"description": @"Xcode 运行安装 APP 产生的缓存文件"},
        @{@"name": @"DerivedData2", @"path": [NSHomeDirectory() stringByAppendingPathComponent:@"Library/Developer/Xcode/DerivedData2"], @"description": @"Xcode 运行安装 APP 产生的缓存文件"},
        @{@"name": @"Products", @"path": [NSHomeDirectory() stringByAppendingPathComponent:@"Library/Developer/Xcode/Products"], @"description": @"APP 打包的 app icon 历史版本"},
        @{@"name": @"CoreSimulator", @"path": [NSHomeDirectory() stringByAppendingPathComponent:@"Library/Developer/CoreSimulator/Devices"], @"description": @"模拟器的缓存数据"},
        @{@"name": @"iOS DeviceSupport", @"path": [NSHomeDirectory() stringByAppendingPathComponent:@"Library/Developer/Xcode/iOS DeviceSupport"], @"description": @"对旧设备的支持"},
        @{@"name": @"Xcode Plug-ins", @"path": [NSHomeDirectory() stringByAppendingPathComponent:@"Library/Application Support/Developer/Shared/Xcode/Plug-ins"], @"description": @"Xcode 中的无效的插件"},
        @{@"name": @"Simulator Runtimes", @"path": [NSHomeDirectory() stringByAppendingPathComponent:@"Library/Developer/CoreSimulator/Profiles/Runtimes"], @"description": @"旧版本的模拟器支持"},
        @{@"name": @"XCPGDevices", @"path": [NSHomeDirectory() stringByAppendingPathComponent:@"Library/Developer/XCPGDevices"], @"description": @"playground 的项目缓存"},
        @{@"name": @"Documentation", @"path": [NSHomeDirectory() stringByAppendingPathComponent:@"Library/Developer/Shared/Documentation/DocSets"], @"description": @"旧的文档"},
        @{@"name": @"iPhoneSimulator SDKs", @"path": @"/Applications/Xcode.app/Contents/Developer/Platforms/iPhoneSimulator.platform/Developer/SDKs", @"description": @"模拟器中的SDK版本"}
    ];
    
    for (NSDictionary *pathInfo in paths) {
        NSMutableDictionary *item = [pathInfo mutableCopy];
        item[@"size"] = @0;
        item[@"sizeString"] = @"计算中...";
        item[@"status"] = @"就绪";
        // 对 iOS DeviceSupport 加载子项
        if ([item[@"name"] isEqualToString:@"iOS DeviceSupport"]) {
            NSString *root = item[@"path"];
            NSArray *subdirs = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:root error:nil];
            NSMutableArray *children = [NSMutableArray array];
            for (NSString *sub in subdirs) {
                NSString *full = [root stringByAppendingPathComponent:sub];
                BOOL isDir = NO;
                [[NSFileManager defaultManager] fileExistsAtPath:full isDirectory:&isDir];
                if (isDir) {
                    NSMutableDictionary *child = [@{ @"name": sub, @"path": full, @"description": @"设备支持版本", @"checked": @YES } mutableCopy];
                    child[@"size"] = @0;
                    child[@"sizeString"] = @"计算中...";
                    [children addObject:child];
                    [self.selectedDeviceSupportChildren addObject:full];
                }
            }
            item[@"children"] = children;
        }
        // 根目录默认选中
        if (item[@"path"]) {
            [self.selectedRootPaths addObject:item[@"path"]];
        }
        [self.cleanItems addObject:item];
    }
}

- (void)calculateSizes {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        long long totalSize = 0;
        
        for (NSMutableDictionary *item in self.cleanItems) {
            NSString *path = item[@"path"];
            long long size = 0;
            if ([item[@"name"] isEqualToString:@"iOS DeviceSupport"] && item[@"children"]) {
                for (NSMutableDictionary *child in item[@"children"]) {
                    long long childSize = [self calculateDirectorySize:child[@"path"]];
                    child[@"size"] = @(childSize);
                    child[@"sizeString"] = [self formatFileSize:childSize];
                    if ([self.selectedDeviceSupportChildren containsObject:child[@"path"]]) {
                        size += childSize;
                    }
                }
            } else {
                size = [self calculateDirectorySize:path];
            }
            
            item[@"size"] = @(size);
            item[@"sizeString"] = [self formatFileSize:size];
            totalSize += size;
        }
        
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.outlineView reloadData];
            self.totalSizeLabel.stringValue = [NSString stringWithFormat:@"总大小: %@", [self formatFileSize:totalSize]];
        });
    });
}

- (long long)calculateDirectorySize:(NSString *)directoryPath {
    NSFileManager *fileManager = [NSFileManager defaultManager];
    
    if (![fileManager fileExistsAtPath:directoryPath]) {
        return 0;
    }
    
    NSArray *contents = [fileManager contentsOfDirectoryAtPath:directoryPath error:nil];
    long long totalSize = 0;
    
    for (NSString *item in contents) {
        NSString *fullPath = [directoryPath stringByAppendingPathComponent:item];
        NSDictionary *attributes = [fileManager attributesOfItemAtPath:fullPath error:nil];
        
        if (attributes) {
            if ([attributes[NSFileType] isEqualToString:NSFileTypeDirectory]) {
                totalSize += [self calculateDirectorySize:fullPath];
            } else {
                totalSize += [attributes[NSFileSize] longLongValue];
            }
        }
    }
    
    return totalSize;
}

- (NSString *)formatFileSize:(long long)size {
    if (size < 1024) {
        return [NSString stringWithFormat:@"%lld B", size];
    } else if (size < 1024 * 1024) {
        return [NSString stringWithFormat:@"%.1f KB", size / 1024.0];
    } else if (size < 1024 * 1024 * 1024) {
        return [NSString stringWithFormat:@"%.1f MB", size / (1024.0 * 1024.0)];
    } else {
        return [NSString stringWithFormat:@"%.1f GB", size / (1024.0 * 1024.0 * 1024.0)];
    }
}

- (void)cleanButtonClicked:(id)sender {
    NSAlert *alert = [[NSAlert alloc] init];
    alert.messageText = @"确认清理";
    alert.informativeText = @"确定要清理所有 Xcode 缓存文件吗？此操作不可撤销。";
    alert.alertStyle = NSAlertStyleWarning;
    [alert addButtonWithTitle:@"确定"];
    [alert addButtonWithTitle:@"取消"];
    
    [alert beginSheetModalForWindow:self.view.window completionHandler:^(NSModalResponse returnCode) {
        if (returnCode == NSAlertFirstButtonReturn) {
            [self performCleanup];
        }
    }];
}

- (void)refreshButtonClicked:(id)sender {
    // 恢复所有项的状态为“就绪”，并将大小显示为“计算中...”
    for (NSMutableDictionary *item in self.cleanItems) {
        item[@"status"] = @"就绪";
        item[@"sizeString"] = @"计算中...";
        if (item[@"children"]) {
            for (NSMutableDictionary *child in item[@"children"]) {
                child[@"status"] = @"就绪";
                child[@"sizeString"] = @"计算中...";
            }
        }
    }
    [self.outlineView reloadData];
    [self calculateSizes];
}

- (void)performCleanup {
    self.cleanButton.enabled = NO;
    self.refreshButton.enabled = NO;
    self.progressIndicator.hidden = NO;
    [self.progressIndicator startAnimation:nil];
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        __block long long totalCleaned = 0;
        
        for (NSMutableDictionary *item in self.cleanItems) {
            dispatch_async(dispatch_get_main_queue(), ^{
                item[@"status"] = @"正在清理...";
                [self.outlineView reloadData];
            });
            
            NSString *path = item[@"path"];
            long long size = [item[@"size"] longLongValue];
            
            NSFileManager *fileManager = [NSFileManager defaultManager];
            __block BOOL didClean = NO;
            if ([item[@"name"] isEqualToString:@"iOS DeviceSupport"] && item[@"children"]) {
                NSMutableArray *children = item[@"children"];
                NSMutableIndexSet *indexesToRemove = [NSMutableIndexSet indexSet];
                [children enumerateObjectsUsingBlock:^(NSMutableDictionary *child, NSUInteger idx, BOOL *stop) {
                    NSString *childPath = child[@"path"];
                    if (![self.selectedDeviceSupportChildren containsObject:childPath]) return; 
                    if ([fileManager fileExistsAtPath:childPath]) {
                        NSError *err;
                        [fileManager removeItemAtPath:childPath error:&err];
                        if (!err) {
                            totalCleaned += [child[@"size"] longLongValue];
                            [indexesToRemove addIndex:idx];
                            didClean = YES;
                        }
                    } else {
                        // 如果本就不存在，也从列表移除
                        [indexesToRemove addIndex:idx];
                        didClean = YES;
                    }
                }];
                // 从数据源移除已删除的子项，并从选择集中去除
                [indexesToRemove enumerateIndexesUsingBlock:^(NSUInteger idx, BOOL *stop) {
                    NSString *removedPath = children[idx][@"path"];
                    [self.selectedDeviceSupportChildren removeObject:removedPath];
                }];
                [children removeObjectsAtIndexes:indexesToRemove];
                
            } else {
                if ([fileManager fileExistsAtPath:path]) {
                    // 其它根目录，仅当被勾选时才清理
                    if ([self.selectedRootPaths containsObject:path]) {
                        NSError *error;
                        [fileManager removeItemAtPath:path error:&error];
                        if (!error) {
                            totalCleaned += size;
                            didClean = YES;
                        }
                    }
                }
            }
            
            dispatch_async(dispatch_get_main_queue(), ^{
                if ([item[@"name"] isEqualToString:@"iOS DeviceSupport"]) {
                    item[@"status"] = didClean ? @"清理完成" : @"跳过";
                    // 重新计算父项显示大小（按剩余子项大小之和，不受是否勾选影响）
                    long long sum = 0;
                    for (NSDictionary *child in item[@"children"]) {
                        sum += [child[@"size"] longLongValue];
                    }
                    item[@"size"] = @(sum);
                    item[@"sizeString"] = [self formatFileSize:sum];
                    [self.outlineView reloadItem:item reloadChildren:YES];
                } else {
                    if (didClean) {
                        item[@"status"] = @"清理完成";
                        item[@"size"] = @0;
                        item[@"sizeString"] = @"0 B";
                    } else {
                        item[@"status"] = @"跳过";
                        // 未清理，保持原有大小不变
                    }
                    [self.outlineView reloadData];
                }
            });
        }
        
        dispatch_async(dispatch_get_main_queue(), ^{
            self.cleanButton.enabled = YES;
            self.refreshButton.enabled = YES;
            self.progressIndicator.hidden = YES;
            [self.progressIndicator stopAnimation:nil];
            
            // 重新计算当前总大小
            long long currentTotal = 0;
            for (NSDictionary *root in self.cleanItems) {
                currentTotal += [root[@"size"] longLongValue];
            }
            self.totalSizeLabel.stringValue = [NSString stringWithFormat:@"总大小: %@ (已清理: %@)", [self formatFileSize:currentTotal], [self formatFileSize:totalCleaned]];
            
            NSAlert *alert = [[NSAlert alloc] init];
            alert.messageText = @"清理完成";
            alert.informativeText = [NSString stringWithFormat:@"已清理 %@ 的缓存文件", [self formatFileSize:totalCleaned]];
            alert.alertStyle = NSAlertStyleInformational;
            [alert addButtonWithTitle:@"确定"];
            [alert beginSheetModalForWindow:self.view.window completionHandler:nil];
        });
    });
}

#pragma mark - NSOutlineViewDataSource

- (NSInteger)outlineView:(NSOutlineView *)outlineView numberOfChildrenOfItem:(id)item {
    if (!item) return self.cleanItems.count;
    NSDictionary *dict = (NSDictionary *)item;
    NSArray *children = dict[@"children"];
    return children ? children.count : 0;
}

- (id)outlineView:(NSOutlineView *)outlineView child:(NSInteger)index ofItem:(id)item {
    if (!item) return self.cleanItems[index];
    return ((NSDictionary *)item)[@"children"][index];
}

- (BOOL)outlineView:(NSOutlineView *)outlineView isItemExpandable:(id)item {
    return ((NSDictionary *)item)[@"children"] != nil;
}

#pragma mark - NSOutlineViewDelegate

- (NSView *)outlineView:(NSOutlineView *)outlineView viewForTableColumn:(NSTableColumn *)tableColumn item:(id)item {
    NSDictionary *dict = (NSDictionary *)item;
    NSString *identifier = tableColumn.identifier;

    if ([identifier isEqualToString:@"checked"]) {
        // 使用容器单元格承载复选框，便于通过约束实现缩进
        NSTableCellView *cell = [outlineView makeViewWithIdentifier:@"checkedCell" owner:self];
        NSButton *checkbox = nil;
        if (!cell) {
            cell = [[NSTableCellView alloc] initWithFrame:NSMakeRect(0, 0, outlineView.frame.size.width, outlineView.rowHeight)];
            cell.identifier = @"checkedCell";
            checkbox = [[NSButton alloc] initWithFrame:NSMakeRect(0, 0, 18, 18)];
            checkbox.translatesAutoresizingMaskIntoConstraints = NO;
            checkbox.buttonType = NSButtonTypeSwitch;
            checkbox.title = @"";
            checkbox.target = self;
            checkbox.action = @selector(onCheckboxToggled:);
            checkbox.tag = 1001; // 用于后续查找
            [cell addSubview:checkbox];
            [NSLayoutConstraint activateConstraints:@[
                [checkbox.centerYAnchor constraintEqualToAnchor:cell.centerYAnchor],
                [checkbox.widthAnchor constraintEqualToConstant:18.0],
                [checkbox.heightAnchor constraintEqualToConstant:18.0]
            ]];
            // 默认的 leading 约束（会在下面根据层级调整常量）
            NSLayoutConstraint *leading = [checkbox.leadingAnchor constraintEqualToAnchor:cell.leadingAnchor constant:6.0];
            leading.active = YES;
        } else {
            checkbox = (NSButton *)[cell viewWithTag:1001];
        }
        // 绑定 representedObject，防止复用后错位
        cell.objectValue = dict;
        NSString *path = dict[@"path"];
        BOOL isChildOfDeviceSupport = [self parentIsDeviceSupport:item];
        BOOL isDeviceSupportRoot = (dict[@"children"] != nil);

        if (isChildOfDeviceSupport) {
            checkbox.state = [self.selectedDeviceSupportChildren containsObject:path] ? NSControlStateValueOn : NSControlStateValueOff;
            checkbox.allowsMixedState = NO;
        } else if (isDeviceSupportRoot) {
            // 根：iOS DeviceSupport（父），根据子项选择情况显示
            NSArray *children = dict[@"children"] ?: @[];
            NSUInteger selectedCount = 0;
            for (NSDictionary *c in children) {
                if ([self.selectedDeviceSupportChildren containsObject:c[@"path"]]) selectedCount++;
            }
            if (selectedCount == 0) {
                checkbox.state = NSControlStateValueOff;
            } else if (selectedCount == children.count) {
                checkbox.state = NSControlStateValueOn;
            } else {
                checkbox.state = NSControlStateValueMixed;
            }
            checkbox.allowsMixedState = YES;
        } else {
            // 其它根目录
            checkbox.state = [self.selectedRootPaths containsObject:path] ? NSControlStateValueOn : NSControlStateValueOff;
            checkbox.allowsMixedState = NO;
        }
        // 调整缩进：更新 leading 约束的常量
        CGFloat insetX = isChildOfDeviceSupport ? 24.0 : 6.0;
        NSLayoutConstraint *leadingConstraint = nil;
        for (NSLayoutConstraint *c in cell.constraints) {
            if ((c.firstItem == checkbox && c.firstAttribute == NSLayoutAttributeLeading) ||
                (c.secondItem == checkbox && c.secondAttribute == NSLayoutAttributeLeading)) {
                leadingConstraint = c;
                break;
            }
        }
        if (leadingConstraint) {
            leadingConstraint.constant = insetX;
        } else {
            [[checkbox leadingAnchor] constraintEqualToAnchor:cell.leadingAnchor constant:insetX].active = YES;
        }
        checkbox.enabled = YES;
        return cell;
    }

    NSTableCellView *cell = [outlineView makeViewWithIdentifier:identifier owner:self];
    if (!cell) {
        cell = [[NSTableCellView alloc] initWithFrame:NSMakeRect(0, 0, tableColumn.width, self.outlineView.rowHeight)];
        cell.identifier = identifier;
        NSTextField *text = [[NSTextField alloc] initWithFrame:NSZeroRect];
        text.translatesAutoresizingMaskIntoConstraints = NO;
        text.bezeled = NO;
        text.drawsBackground = NO;
        text.editable = NO;
        text.selectable = NO;
        text.usesSingleLineMode = YES;
        text.lineBreakMode = NSLineBreakByTruncatingTail;
        if ([text.cell isKindOfClass:[NSTextFieldCell class]]) {
            NSTextFieldCell *textCell = (NSTextFieldCell *)text.cell;
            textCell.wraps = NO;
            textCell.truncatesLastVisibleLine = YES;
        }
        if ([text respondsToSelector:@selector(setAllowsDefaultTighteningForTruncation:)]) {
            text.allowsDefaultTighteningForTruncation = YES;
        }
        [cell addSubview:text];
        [NSLayoutConstraint activateConstraints:@[
            [text.centerYAnchor constraintEqualToAnchor:cell.centerYAnchor],
            [text.leadingAnchor constraintEqualToAnchor:cell.leadingAnchor constant:0.0],
            [text.trailingAnchor constraintEqualToAnchor:cell.trailingAnchor constant:0.0]
        ]];
        cell.textField = text;
    }
    // 绑定 representedObject，避免复用后显示到错误项
    cell.objectValue = dict;

    // 无论哪一列，都强制单行并尾部省略号
    cell.textField.usesSingleLineMode = YES;
    cell.textField.lineBreakMode = NSLineBreakByTruncatingTail;
    if ([cell.textField.cell isKindOfClass:[NSTextFieldCell class]]) {
        NSTextFieldCell *textCell = (NSTextFieldCell *)cell.textField.cell;
        textCell.wraps = NO;
        textCell.truncatesLastVisibleLine = YES;
    }
    if ([identifier isEqualToString:@"name"]) {
        cell.textField.stringValue = dict[@"name"] ?: @"";
    } else if ([identifier isEqualToString:@"path"]) {
        cell.textField.stringValue = dict[@"path"] ?: @"";
    } else if ([identifier isEqualToString:@"size"]) {
        cell.textField.stringValue = dict[@"sizeString"] ?: @"";
    } else if ([identifier isEqualToString:@"status"]) {
        cell.textField.stringValue = dict[@"status"] ?: @"";
    } else if ([identifier isEqualToString:@"description"]) {
        cell.textField.stringValue = dict[@"description"] ?: @"";
    }
    return cell;
}

- (BOOL)parentIsDeviceSupport:(id)item {
    for (NSDictionary *root in self.cleanItems) {
        if ([root[@"name"] isEqualToString:@"iOS DeviceSupport"]) {
            NSArray *children = root[@"children"];
            if ([children containsObject:item]) return YES;
        }
    }
    return NO;
}

- (void)onCheckboxToggled:(NSButton *)sender {
    // find item via row
    NSInteger row = [self.outlineView rowForView:sender];
    if (row == -1) return;
    id item = [self.outlineView itemAtRow:row];
    NSDictionary *dict = (NSDictionary *)item;
    NSString *path = dict[@"path"];

    BOOL isChildOfDeviceSupport = [self parentIsDeviceSupport:item];
    BOOL isDeviceSupportRoot = (dict[@"children"] != nil);

    if (isChildOfDeviceSupport) {
        if (sender.state == NSControlStateValueOn) {
            [self.selectedDeviceSupportChildren addObject:path];
        } else {
            [self.selectedDeviceSupportChildren removeObject:path];
        }
        // 刷新父节点以呈现混合态/勾选态
        for (NSDictionary *root in self.cleanItems) {
            if ([root[@"name"] isEqualToString:@"iOS DeviceSupport"]) {
                [self.outlineView reloadItem:root reloadChildren:NO];
                break;
            }
        }
    } else if (isDeviceSupportRoot) {
        // 勾选/取消勾选父节点 => 全选/全不选子节点
        NSArray *children = dict[@"children"] ?: @[];
        if (sender.state == NSControlStateValueOff) {
            for (NSDictionary *c in children) {
                [self.selectedDeviceSupportChildren removeObject:c[@"path"]];
            }
        } else { // On 或 Mixed -> 设为全选
            for (NSDictionary *c in children) {
                [self.selectedDeviceSupportChildren addObject:c[@"path"]];
            }
        }
        [self.outlineView reloadItem:item reloadChildren:YES];
    } else {
        // 其它根目录
        if (sender.state == NSControlStateValueOn) {
            [self.selectedRootPaths addObject:path];
        } else {
            [self.selectedRootPaths removeObject:path];
        }
    }
}

@end
