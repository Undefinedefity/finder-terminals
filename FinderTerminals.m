#import <AppKit/AppKit.h>
#import <FinderSync/FinderSync.h>
#import <os/log.h>

#import "Requests.h"

@interface FinderTerminals : FIFinderSync
@end

@implementation FinderTerminals

- (instancetype)init {
    self = [super init];
    if (self) {
        FIFinderSyncController.defaultController.directoryURLs =
            [NSSet setWithObject:[NSURL fileURLWithPath:@"/" isDirectory:YES]];
    }
    return self;
}

- (NSURL *)selectedFolder {
    NSArray<NSURL *> *items = FIFinderSyncController.defaultController.selectedItemURLs;
    if (items.count != 1) {
        return nil;
    }

    NSURL *url = items.firstObject;
    NSNumber *isDirectory;
    NSNumber *isPackage;
    return [url getResourceValue:&isDirectory forKey:NSURLIsDirectoryKey error:nil]
        && isDirectory.boolValue
        && [url getResourceValue:&isPackage forKey:NSURLIsPackageKey error:nil]
        && !isPackage.boolValue ? url : nil;
}

- (NSMenu *)menuForMenuKind:(FIMenuKind)kind {
    if (kind != FIMenuKindContextualMenuForItems || ![self selectedFolder]) {
        return nil;
    }

    NSMenu *menu = [[NSMenu alloc] initWithTitle:@""];
    NSMenuItem *ghostty = [menu addItemWithTitle:@"在 Ghostty 中打开"
                                          action:@selector(openInGhostty:)
                                   keyEquivalent:@""];
    ghostty.target = self;
    NSMenuItem *otty = [menu addItemWithTitle:@"在 Otty 中打开"
                                       action:@selector(openInOtty:)
                                keyEquivalent:@""];
    otty.target = self;
    return menu;
}

- (void)openInGhostty:(id)sender {
    [self openSelectedFolderInAppWithIdentifier:GhosttyID];
}

- (void)openInOtty:(id)sender {
    [self openSelectedFolderInAppWithIdentifier:OttyID];
}

- (void)openSelectedFolderInAppWithIdentifier:(NSString *)identifier {
    NSURL *folder = [self selectedFolder];
    NSURL *directory = requestDirectory();
    if (!folder || !directory) {
        return;
    }

    NSURL *request = [directory URLByAppendingPathComponent:
        [NSUUID.UUID.UUIDString stringByAppendingPathExtension:@"plist"]];
    NSError *error;
    NSData *data = [NSPropertyListSerialization
        dataWithPropertyList:@{@"terminal": identifier, @"directory": folder.path, @"created": NSDate.date}
                      format:NSPropertyListBinaryFormat_v1_0 options:0 error:&error];
    if (!data || ![data writeToURL:request options:NSDataWritingAtomic error:&error]) {
        os_log_error(OS_LOG_DEFAULT, "Finder Terminals: could not save request (%{public}@ %ld)",
                     error.domain, (long)error.code);
        return;
    }

    NSURL *host = NSBundle.mainBundle.bundleURL.URLByDeletingLastPathComponent
        .URLByDeletingLastPathComponent.URLByDeletingLastPathComponent;
    NSWorkspaceOpenConfiguration *configuration = NSWorkspaceOpenConfiguration.configuration;
    configuration.activates = NO;
    configuration.createsNewApplicationInstance = YES;
    [NSWorkspace.sharedWorkspace openApplicationAtURL:host
                                       configuration:configuration
                                   completionHandler:^(NSRunningApplication *application, NSError *error) {
        if (error) {
            [NSFileManager.defaultManager removeItemAtURL:request error:nil];
            os_log_error(OS_LOG_DEFAULT, "Finder Terminals: could not start helper (%{public}@ %ld)",
                         error.domain, (long)error.code);
        }
    }];
}

@end
