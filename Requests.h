#import <Foundation/Foundation.h>
#include <pwd.h>
#include <unistd.h>

static NSString *const GhosttyID = @"com.mitchellh.ghostty";
static NSString *const OttyID = @"io.appmakes.otty";

static inline NSURL *requestDirectory(void) {
    struct passwd *account = getpwuid(getuid());
    if (!account || !account->pw_dir) {
        return nil;
    }
    NSString *home = [[NSFileManager defaultManager]
        stringWithFileSystemRepresentation:account->pw_dir length:strlen(account->pw_dir)];
    return [[NSURL fileURLWithPath:home isDirectory:YES]
        URLByAppendingPathComponent:@"Library/Application Support/Finder Terminals/Requests"
                        isDirectory:YES];
}
