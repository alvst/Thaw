//
//  ThawAssessmentModeHiding.m
//  Project: Thaw
//
//  Copyright (Ice) © 2023–2025 Jordan Baird
//  Copyright (Thaw) © 2026 Toni Förster
//  Licensed under the GNU GPLv3
//

#import "ThawAssessmentModeHiding.h"
#import <dlfcn.h>

// Private MenuBarClientCore interfaces, declared locally. The classes are
// resolved at runtime via NSClassFromString and every call is wrapped in
// @try/@catch, so a missing class or a renamed selector degrades gracefully
// instead of crashing. The framework lives only in the dyld shared cache, so it
// must be dlopen'd before the classes resolve; it is an Apple platform binary,
// so this needs no entitlement and no library-validation exception.
@interface MBAssessmentModeConfiguration : NSObject
- (instancetype)initWithAllowedSystemItems:(NSArray<NSNumber *> *)systemItems
                  allowedBundleIdentifiers:(NSArray<NSString *> *)bundleIdentifiers;
@end

@interface MBAssessmentModeAssertion : NSObject
- (void)activateWithConfiguration:(id)configuration
                completionHandler:(void (^)(NSError *_Nullable error))completionHandler;
- (void)invalidate;
@end

static const char *kMenuBarClientCorePath =
    "/System/Library/PrivateFrameworks/MenuBarClientCore.framework/MenuBarClientCore";

/// Ensures MenuBarClientCore is loaded so its ObjC classes resolve. Loaded once
/// and cached; returns whether the load succeeded.
static BOOL ThawEnsureMenuBarClientCoreLoaded(void) {
    static dispatch_once_t onceToken;
    static BOOL loaded = NO;
    dispatch_once(&onceToken, ^{
        loaded = (dlopen(kMenuBarClientCorePath, RTLD_NOW) != NULL);
        if (!loaded) {
            NSLog(@"[ThawAssessmentModeHiding] failed to dlopen MenuBarClientCore: %s", dlerror());
        }
    });
    return loaded;
}

BOOL ThawAssessmentModeHidingAvailable(void) {
    if (!ThawEnsureMenuBarClientCoreLoaded()) {
        return NO;
    }
    return NSClassFromString(@"MBAssessmentModeConfiguration") != nil &&
           NSClassFromString(@"MBAssessmentModeAssertion") != nil;
}

void *ThawAssessmentModeHidingActivate(NSArray<NSString *> *allowedBundleIdentifiers,
                                       NSArray<NSNumber *> *allowedSystemItems,
                                       void (^_Nullable onFailure)(void)) {
    if (!ThawEnsureMenuBarClientCoreLoaded()) {
        return NULL;
    }

    Class configurationClass = NSClassFromString(@"MBAssessmentModeConfiguration");
    Class assertionClass = NSClassFromString(@"MBAssessmentModeAssertion");
    if (!configurationClass || !assertionClass) {
        NSLog(@"[ThawAssessmentModeHiding] MBAssessmentMode classes unavailable; cannot activate");
        return NULL;
    }

    @try {
        MBAssessmentModeConfiguration *configuration =
            [[configurationClass alloc] initWithAllowedSystemItems:(allowedSystemItems ?: @[])
                                          allowedBundleIdentifiers:(allowedBundleIdentifiers ?: @[])];
        if (!configuration) {
            return NULL;
        }

        MBAssessmentModeAssertion *assertion = [[assertionClass alloc] init];
        if (!assertion) {
            return NULL;
        }

        void (^failureCopy)(void) = onFailure ? [onFailure copy] : nil;
        [assertion activateWithConfiguration:configuration
                           completionHandler:^(NSError *_Nullable error) {
            if (error) {
                NSLog(@"[ThawAssessmentModeHiding] activation reported error: %@", error);
                if (failureCopy) {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        failureCopy();
                    });
                }
            }
        }];

        // Hand the assertion back as a retained, opaque handle. It must stay
        // alive for the restriction to remain in effect.
        return (void *)CFBridgingRetain(assertion);
    } @catch (NSException *exception) {
        NSLog(@"[ThawAssessmentModeHiding] activation threw: %@", exception);
        return NULL;
    }
}

void ThawAssessmentModeHidingInvalidate(void *handle) {
    if (handle == NULL) {
        return;
    }
    MBAssessmentModeAssertion *assertion = (MBAssessmentModeAssertion *)CFBridgingRelease(handle);
    @try {
        [assertion invalidate];
    } @catch (NSException *exception) {
        NSLog(@"[ThawAssessmentModeHiding] invalidate threw: %@", exception);
    }
}
