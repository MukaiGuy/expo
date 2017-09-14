// Copyright 2015-present 650 Industries. All rights reserved.

#import "ABI21_0_0EXScopedEventEmitter.h"

@class ABI21_0_0EXKernelModule;

@protocol ABI21_0_0EXKernelModuleDelegate <NSObject>

- (void)kernelModule: (ABI21_0_0EXKernelModule *)module taskDidForegroundWithType: (NSInteger)type params: (NSDictionary *)params;
- (void)kernelModule:(ABI21_0_0EXKernelModule *)module
didRequestManifestWithUrl:(NSURL *)url
         originalUrl:(NSURL *)originalUrl
             success:(void (^)(NSString *manifestString))success
             failure:(void (^)(NSError *err))failure;

/**
 *  Whether the kernel JS should show any devtools UI or respond to devtools commands.
 */
- (BOOL)kernelModuleShouldEnableDevtools:(ABI21_0_0EXKernelModule *)module;

/**
 *  Whether the kernel JS should auto reload an experience after it encounters a fatal JS error.
 */
- (BOOL)kernelModuleShouldAutoReloadCurrentTask:(ABI21_0_0EXKernelModule *)module;

/**
 *  Whether to enable legacy gesture/button for the Expo menu.
 */
- (BOOL)kernelModuleShouldEnableLegacyMenuBehavior:(ABI21_0_0EXKernelModule *)module;
- (void)kernelModule:(ABI21_0_0EXKernelModule *)module didSelectEnableLegacyMenuBehavior:(BOOL)isEnabled;

/**
 *  Dictionary of `key` => `user facing label` items to show in the kernel JS dev menu.
 */
- (NSDictionary <NSString *, NSString *> *)devMenuItemsForKernelModule:(ABI21_0_0EXKernelModule *)module;

- (void)kernelModule:(ABI21_0_0EXKernelModule *)module didSelectDevMenuItemWithKey:(NSString *)key;

// TODO: kill this as an ABI21_0_0RCTDevSettings followup
- (void)kernelModuleDidSelectKernelDevMenu: (ABI21_0_0EXKernelModule *)module DEPRECATED_ATTRIBUTE;

- (void)kernelModule:(ABI21_0_0EXKernelModule *)module didOpenUrl:(NSString *)url;

@end

@interface ABI21_0_0EXKernelModule : ABI21_0_0EXScopedEventEmitter

- (void)dispatchJSEvent: (NSString *)eventName
                   body: (NSDictionary *)eventBody
              onSuccess: (void (^)(NSDictionary *))success
              onFailure: (void (^)(NSString *))failure;

@end
