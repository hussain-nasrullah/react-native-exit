#import "RNExit.h"

@implementation RNExit

- (dispatch_queue_t)methodQueue
{
    return dispatch_get_main_queue();
}

- (BOOL)requiresMainQueueSetup
{
    return YES;
}

RCT_EXPORT_MODULE()

- (UIViewController *)currentTopViewController
{
    UIViewController *topVC;
    if (@available(iOS 13, *)){
        topVC = [UIApplication sharedApplication].keyWindow.rootViewController;
    } else {
        topVC = [[[[UIApplication sharedApplication] delegate] window] rootViewController];
    }
    while (topVC.presentedViewController)
    {
        topVC = topVC.presentedViewController;
    }
    if ([topVC isKindOfClass:[UINavigationController class]]) {
        return [(UINavigationController *)topVC topViewController];
    }
    return topVC;
}

// Recursively remove NSNull and unsupported types
- (id)sanitizeForUserDefaults:(id)obj
{
    if ([obj isKindOfClass:[NSDictionary class]]) {
        NSMutableDictionary *sanitized = [NSMutableDictionary dictionary];
        for (NSString *key in obj) {
            id value = [self sanitizeForUserDefaults:obj[key]];
            if (value) {
                sanitized[key] = value;
            }
        }
        return sanitized;
    } else if ([obj isKindOfClass:[NSArray class]]) {
        NSMutableArray *sanitized = [NSMutableArray array];
        for (id item in obj) {
            id value = [self sanitizeForUserDefaults:item];
            if (value) {
                [sanitized addObject:value];
            }
        }
        return sanitized;
    } else if ([obj isKindOfClass:[NSNull class]]) {
        return nil;
    } else if ([obj isKindOfClass:[NSString class]] ||
               [obj isKindOfClass:[NSNumber class]] ||
               [obj isKindOfClass:[NSData class]] ||
               [obj isKindOfClass:[NSDate class]]) {
        return obj;
    } else {
        // Unsupported type
        return nil;
    }
}

RCT_REMAP_METHOD(exitApp,
                 exitApp:(NSDictionary *)data
                 withNavigationExitType:(NSString *)navigationExitType)
{
    dispatch_async(dispatch_get_main_queue(), ^{
        @try {
            NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
            NSDictionary *sanitizedData = [self sanitizeForUserDefaults:data];
            [userDefaults setObject:sanitizedData forKey:@"pkb_exit_data"]; // need to change name
            [userDefaults synchronize];

            [[NSNotificationCenter defaultCenter] postNotificationName:@"PeekabooConnectExit" // need to change name
                                                                object:nil
                                                              userInfo:sanitizedData];

            if ([navigationExitType isEqualToString:@"STAY"]) {
                return;
            }
            if ([navigationExitType isEqualToString:@"POP"]) {
                [[self currentTopViewController] popoverPresentationController];
                return;
            }

            [[self currentTopViewController] dismissViewControllerAnimated:YES completion:nil];
        }
        @catch(NSException *exception) {
            NSLog(@"Exception occurred while exiting: %@", exception.reason);
        }
    });
}

@end
