// Copyright 2004-present Facebook. All Rights Reserved.

/**
 * Copyright (c) 2015-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 */

#include "ABI21_0_0RCTJSCHelpers.h"

#import <Foundation/Foundation.h>

#import <ReactABI21_0_0/ABI21_0_0RCTBridge+Private.h>
#import <ReactABI21_0_0/ABI21_0_0RCTCxxUtils.h>
#import <ReactABI21_0_0/ABI21_0_0RCTLog.h>
#import <cxxReactABI21_0_0/ABI21_0_0Platform.h>
#import <ABI21_0_0jschelpers/ABI21_0_0Value.h>

using namespace facebook::ReactABI21_0_0;

namespace {

JSValueRef nativeLoggingHook(
    JSContextRef ctx, JSObjectRef function, JSObjectRef thisObject, size_t argumentCount,
    const JSValueRef arguments[], JSValueRef *exception) {
  ABI21_0_0RCTLogLevel level = ABI21_0_0RCTLogLevelInfo;
  if (argumentCount > 1) {
    level = MAX(level, (ABI21_0_0RCTLogLevel)Value(ctx, arguments[1]).asNumber());
  }
  if (argumentCount > 0) {
    JSContext *contextObj = contextForGlobalContextRef(JSC_JSContextGetGlobalContext(ctx));
    JSValue *msg = [JSC_JSValue(ctx) valueWithJSValueRef:arguments[0] inContext:contextObj];
    _ABI21_0_0RCTLogJavaScriptInternal(level, [msg toString]);
  }
  return Value::makeUndefined(ctx);
}

JSValueRef nativePerformanceNow(
    JSContextRef ctx, JSObjectRef function, JSObjectRef thisObject, size_t argumentCount,
    const JSValueRef arguments[], JSValueRef *exception) {
  return Value::makeNumber(ctx, CACurrentMediaTime() * 1000);
}

}

void ABI21_0_0RCTPrepareJSCExecutor() {
  ReactABI21_0_0Marker::logTaggedMarker = [](const ReactABI21_0_0Marker::ReactABI21_0_0MarkerId, const char *tag) {};
  JSCNativeHooks::loggingHook = nativeLoggingHook;
  JSCNativeHooks::nowHook = nativePerformanceNow;
  JSCNativeHooks::installPerfHooks = ABI21_0_0RCTFBQuickPerformanceLoggerConfigureHooks;
}
