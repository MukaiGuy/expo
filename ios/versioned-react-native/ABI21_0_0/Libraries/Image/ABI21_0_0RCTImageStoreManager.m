/**
 * Copyright (c) 2015-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 */

#import "ABI21_0_0RCTImageStoreManager.h"

#import <stdatomic.h>

#import <ImageIO/ImageIO.h>
#import <MobileCoreServices/UTType.h>

#import <ReactABI21_0_0/ABI21_0_0RCTAssert.h>
#import <ReactABI21_0_0/ABI21_0_0RCTLog.h>
#import <ReactABI21_0_0/ABI21_0_0RCTUtils.h>

#import "ABI21_0_0RCTImageUtils.h"

static NSString *const ABI21_0_0RCTImageStoreURLScheme = @"rct-image-store";

@implementation ABI21_0_0RCTImageStoreManager
{
  NSMutableDictionary<NSString *, NSData *> *_store;
  NSUInteger _id;
}

@synthesize methodQueue = _methodQueue;

ABI21_0_0RCT_EXPORT_MODULE()

- (void)removeImageForTag:(NSString *)imageTag withBlock:(void (^)())block
{
  dispatch_async(_methodQueue, ^{
    [self removeImageForTag:imageTag];
    if (block) {
      block();
    }
  });
}

- (NSString *)_storeImageData:(NSData *)imageData
{
  ABI21_0_0RCTAssertThread(_methodQueue, @"Must be called on ABI21_0_0RCTImageStoreManager thread");

  if (!_store) {
    _store = [NSMutableDictionary new];
    _id = 0;
  }

  NSString *imageTag = [NSString stringWithFormat:@"%@://%tu", ABI21_0_0RCTImageStoreURLScheme, _id++];
  _store[imageTag] = imageData;
  return imageTag;
}

- (void)storeImageData:(NSData *)imageData withBlock:(void (^)(NSString *imageTag))block
{
  ABI21_0_0RCTAssertParam(block);
  dispatch_async(_methodQueue, ^{
    block([self _storeImageData:imageData]);
  });
}

- (void)getImageDataForTag:(NSString *)imageTag withBlock:(void (^)(NSData *imageData))block
{
  ABI21_0_0RCTAssertParam(block);
  dispatch_async(_methodQueue, ^{
    block(self->_store[imageTag]);
  });
}

- (void)storeImage:(UIImage *)image withBlock:(void (^)(NSString *imageTag))block
{
  ABI21_0_0RCTAssertParam(block);
  dispatch_async(_methodQueue, ^{
    NSString *imageTag = [self _storeImageData:ABI21_0_0RCTGetImageData(image, 0.75)];
    dispatch_async(dispatch_get_main_queue(), ^{
      block(imageTag);
    });
  });
}

ABI21_0_0RCT_EXPORT_METHOD(removeImageForTag:(NSString *)imageTag)
{
  [_store removeObjectForKey:imageTag];
}

ABI21_0_0RCT_EXPORT_METHOD(hasImageForTag:(NSString *)imageTag
                  callback:(ABI21_0_0RCTResponseSenderBlock)callback)
{
  callback(@[@(_store[imageTag] != nil)]);
}

// TODO (#5906496): Name could be more explicit - something like getBase64EncodedDataForTag:?
ABI21_0_0RCT_EXPORT_METHOD(getBase64ForTag:(NSString *)imageTag
                  successCallback:(ABI21_0_0RCTResponseSenderBlock)successCallback
                  errorCallback:(ABI21_0_0RCTResponseErrorBlock)errorCallback)
{
  NSData *imageData = _store[imageTag];
  if (!imageData) {
    errorCallback(ABI21_0_0RCTErrorWithMessage([NSString stringWithFormat:@"Invalid imageTag: %@", imageTag]));
    return;
  }
  // Dispatching to a background thread to perform base64 encoding
  dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
    successCallback(@[[imageData base64EncodedStringWithOptions:0]]);
  });
}

ABI21_0_0RCT_EXPORT_METHOD(addImageFromBase64:(NSString *)base64String
                  successCallback:(ABI21_0_0RCTResponseSenderBlock)successCallback
                  errorCallback:(ABI21_0_0RCTResponseErrorBlock)errorCallback)

{
  // Dispatching to a background thread to perform base64 decoding
  dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
    NSData *imageData = [[NSData alloc] initWithBase64EncodedString:base64String options:0];
    if (imageData) {
      dispatch_async(self->_methodQueue, ^{
        successCallback(@[[self _storeImageData:imageData]]);
      });
    } else {
      errorCallback(ABI21_0_0RCTErrorWithMessage(@"Failed to add image from base64String"));
    }
  });
}

#pragma mark - ABI21_0_0RCTURLRequestHandler

- (BOOL)canHandleRequest:(NSURLRequest *)request
{
  return [request.URL.scheme caseInsensitiveCompare:ABI21_0_0RCTImageStoreURLScheme] == NSOrderedSame;
}

- (id)sendRequest:(NSURLRequest *)request withDelegate:(id<ABI21_0_0RCTURLRequestDelegate>)delegate
{
  __block atomic_bool cancelled = ATOMIC_VAR_INIT(NO);
  void (^cancellationBlock)(void) = ^{
    atomic_store(&cancelled, YES);
  };

  // Dispatch async to give caller time to cancel the request
  dispatch_async(_methodQueue, ^{
    if (atomic_load(&cancelled)) {
      return;
    }

    NSString *imageTag = request.URL.absoluteString;
    NSData *imageData = self->_store[imageTag];
    if (!imageData) {
      NSError *error = ABI21_0_0RCTErrorWithMessage([NSString stringWithFormat:@"Invalid imageTag: %@", imageTag]);
      [delegate URLRequest:cancellationBlock didCompleteWithError:error];
      return;
    }

    CGImageSourceRef sourceRef = CGImageSourceCreateWithData((__bridge CFDataRef)imageData, NULL);
    if (!sourceRef) {
      NSError *error = ABI21_0_0RCTErrorWithMessage([NSString stringWithFormat:@"Unable to decode data for imageTag: %@", imageTag]);
      [delegate URLRequest:cancellationBlock didCompleteWithError:error];
      return;
    }
    CFStringRef UTI = CGImageSourceGetType(sourceRef);
    CFRelease(sourceRef);

    NSString *MIMEType = (__bridge_transfer NSString *)UTTypeCopyPreferredTagWithClass(UTI, kUTTagClassMIMEType);
    NSURLResponse *response = [[NSURLResponse alloc] initWithURL:request.URL
                                                        MIMEType:MIMEType
                                           expectedContentLength:imageData.length
                                                textEncodingName:nil];

    [delegate URLRequest:cancellationBlock didReceiveResponse:response];
    [delegate URLRequest:cancellationBlock didReceiveData:imageData];
    [delegate URLRequest:cancellationBlock didCompleteWithError:nil];

  });

  return cancellationBlock;
}

- (void)cancelRequest:(id)requestToken
{
  if (requestToken) {
    ((void (^)(void))requestToken)();
  }
}

@end

@implementation ABI21_0_0RCTImageStoreManager (Deprecated)

- (NSString *)storeImage:(UIImage *)image
{
  ABI21_0_0RCTAssertMainQueue();
  ABI21_0_0RCTLogWarn(@"ABI21_0_0RCTImageStoreManager.storeImage() is deprecated and has poor performance. Use an alternative method instead.");
  __block NSString *imageTag;
  dispatch_sync(_methodQueue, ^{
    imageTag = [self _storeImageData:ABI21_0_0RCTGetImageData(image, 0.75)];
  });
  return imageTag;
}

- (UIImage *)imageForTag:(NSString *)imageTag
{
  ABI21_0_0RCTAssertMainQueue();
  ABI21_0_0RCTLogWarn(@"ABI21_0_0RCTImageStoreManager.imageForTag() is deprecated and has poor performance. Use an alternative method instead.");
  __block NSData *imageData;
  dispatch_sync(_methodQueue, ^{
    imageData = self->_store[imageTag];
  });
  return [UIImage imageWithData:imageData];
}

- (void)getImageForTag:(NSString *)imageTag withBlock:(void (^)(UIImage *image))block
{
  ABI21_0_0RCTAssertParam(block);
  dispatch_async(_methodQueue, ^{
    NSData *imageData = self->_store[imageTag];
    dispatch_async(dispatch_get_main_queue(), ^{
      // imageWithData: is not thread-safe, so we can't do this on methodQueue
      block([UIImage imageWithData:imageData]);
    });
  });
}

@end

@implementation ABI21_0_0RCTBridge (ABI21_0_0RCTImageStoreManager)

- (ABI21_0_0RCTImageStoreManager *)imageStoreManager
{
  return [self moduleForClass:[ABI21_0_0RCTImageStoreManager class]];
}

@end
