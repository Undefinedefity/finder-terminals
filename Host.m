#import <AppKit/AppKit.h>
#import <os/log.h>

#import "Requests.h"

static NSDictionary *takeRequest(NSURL *url) {
    if (![url.pathExtension isEqualToString:@"plist"] ||
        ![[NSUUID alloc] initWithUUIDString:url.URLByDeletingPathExtension.lastPathComponent]) {
        return nil;
    }

    NSData *data = [NSData dataWithContentsOfURL:url];
    if (!data || unlink(url.fileSystemRepresentation) != 0) {
        return nil;
    }

    id request = [NSPropertyListSerialization propertyListWithData:data options:NSPropertyListImmutable
                                                           format:NULL error:nil];
    return [request isKindOfClass:NSDictionary.class] ? request : nil;
}

int main(void) {
    @autoreleasepool {
        [NSApplication sharedApplication];
        NSURL *directory = requestDirectory();
        if (!directory) {
            return 1;
        }

        NSDictionary *attributes = @{NSFilePosixPermissions: @0700};
        NSError *error;
        if (![NSFileManager.defaultManager createDirectoryAtURL:directory
                                   withIntermediateDirectories:YES attributes:attributes error:&error]) {
            os_log_error(OS_LOG_DEFAULT, "Finder Terminals: could not prepare requests directory (%{public}@ %ld)",
                         error.domain, (long)error.code);
            return 1;
        }

        NSArray<NSURL *> *files = [NSFileManager.defaultManager contentsOfDirectoryAtURL:directory
            includingPropertiesForKeys:nil options:NSDirectoryEnumerationSkipsHiddenFiles error:nil];
        NSWorkspace *workspace = NSWorkspace.sharedWorkspace;
        dispatch_group_t pending = dispatch_group_create();
        for (NSURL *file in files) {
            NSDictionary *request = takeRequest(file);
            id identifier = request[@"terminal"];
            id path = request[@"directory"];
            id created = request[@"created"];
            if (![identifier isKindOfClass:NSString.class] ||
                ![@[GhosttyID, OttyID] containsObject:identifier] ||
                ![path isKindOfClass:NSString.class] || ![path isAbsolutePath] ||
                ![created isKindOfClass:NSDate.class] || fabs([created timeIntervalSinceNow]) > 30) {
                continue;
            }

            NSURL *app = [workspace URLForApplicationWithBundleIdentifier:identifier];
            if (!app) {
                continue;
            }
            NSURL *folder = [NSURL fileURLWithPath:path isDirectory:YES];
            dispatch_group_enter(pending);
            [workspace openURLs:@[folder] withApplicationAtURL:app
                    configuration:NSWorkspaceOpenConfiguration.configuration
                completionHandler:^(NSRunningApplication *application, NSError *error) {
                if (error) {
                    os_log_error(OS_LOG_DEFAULT, "Finder Terminals: failed to open %{public}@ (%{public}@ %ld)",
                                 identifier, error.domain, (long)error.code);
                }
                dispatch_group_leave(pending);
            }];
        }
        while (dispatch_group_wait(pending, DISPATCH_TIME_NOW) != 0) {
            [NSRunLoop.currentRunLoop runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.1]];
        }
    }
    return 0;
}
