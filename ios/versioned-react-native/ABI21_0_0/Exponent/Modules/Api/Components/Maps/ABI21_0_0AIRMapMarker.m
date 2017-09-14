/**
 * Copyright (c) 2015-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 */

#import "ABI21_0_0AIRMapMarker.h"

#import <ReactABI21_0_0/ABI21_0_0RCTBridge.h>
#import <ReactABI21_0_0/ABI21_0_0RCTEventDispatcher.h>
#import <ReactABI21_0_0/ABI21_0_0RCTImageLoader.h>
#import <ReactABI21_0_0/ABI21_0_0RCTUtils.h>
#import <ReactABI21_0_0/UIView+ReactABI21_0_0.h>

@implementation ABI21_0_0AIREmptyCalloutBackgroundView
@end

@implementation ABI21_0_0AIRMapMarker {
    BOOL _hasSetCalloutOffset;
    ABI21_0_0RCTImageLoaderCancellationBlock _reloadImageCancellationBlock;
    MKPinAnnotationView *_pinView;
}

- (void)ReactABI21_0_0SetFrame:(CGRect)frame
{
    // Make sure we use the image size when available
    CGSize size = self.image ? self.image.size : frame.size;
    CGRect bounds = {CGPointZero, size};

    // The MapView is basically in charge of figuring out the center position of the marker view. If the view changed in
    // height though, we need to compensate in such a way that the bottom of the marker stays at the same spot on the
    // map.
    CGFloat dy = (bounds.size.height - self.bounds.size.height) / 2;
    CGPoint center = (CGPoint){ self.center.x, self.center.y - dy };

    // Avoid crashes due to nan coords
    if (isnan(center.x) || isnan(center.y) ||
            isnan(bounds.origin.x) || isnan(bounds.origin.y) ||
            isnan(bounds.size.width) || isnan(bounds.size.height)) {
        ABI21_0_0RCTLogError(@"Invalid layout for (%@)%@. position: %@. bounds: %@",
                self.ReactABI21_0_0Tag, self, NSStringFromCGPoint(center), NSStringFromCGRect(bounds));
        return;
    }

    self.center = center;
    self.bounds = bounds;
}

- (void)insertReactABI21_0_0Subview:(id<ABI21_0_0RCTComponent>)subview atIndex:(NSInteger)atIndex {
    if ([subview isKindOfClass:[ABI21_0_0AIRMapCallout class]]) {
        self.calloutView = (ABI21_0_0AIRMapCallout *)subview;
    } else {
        [super insertReactABI21_0_0Subview:(UIView *)subview atIndex:atIndex];
    }
}

- (void)removeReactABI21_0_0Subview:(id<ABI21_0_0RCTComponent>)subview {
    if ([subview isKindOfClass:[ABI21_0_0AIRMapCallout class]] && self.calloutView == subview) {
        self.calloutView = nil;
    } else {
        [super removeReactABI21_0_0Subview:(UIView *)subview];
    }
}

- (MKAnnotationView *)getAnnotationView
{
    if ([self shouldUsePinView]) {
        // In this case, we want to render a platform "default" marker.
        if (_pinView == nil) {
            _pinView = [[MKPinAnnotationView alloc] initWithAnnotation:self reuseIdentifier: nil];
            [self addGestureRecognizerToView:_pinView];
            _pinView.annotation = self;
        }

        _pinView.draggable = self.draggable;
        _pinView.layer.zPosition = self.zIndex;

        // TODO(lmr): Looks like this API was introduces in iOS 8. We may want to handle differently for earlier
        // versions. Right now it's just leaving it with the default color. People needing the colors are free to
        // use their own custom markers.
        if ([_pinView respondsToSelector:@selector(setPinTintColor:)]) {
            _pinView.pinTintColor = self.pinColor;
        }

        return _pinView;
    } else {
        // If it has subviews, it means we are wanting to render a custom marker with arbitrary ReactABI21_0_0 views.
        // if it has a non-null image, it means we want to render a custom marker with the image.
        // In either case, we want to return the ABI21_0_0AIRMapMarker since it is both an MKAnnotation and an
        // MKAnnotationView all at the same time.
        self.layer.zPosition = self.zIndex;
        return self;
    }
}

- (void)fillCalloutView:(ABI21_0_0SMCalloutView *)calloutView
{
    // Set everything necessary on the calloutView before it becomes visible.

    // Apply the MKAnnotationView's desired calloutOffset (from the top-middle of the view)
    if ([self shouldUsePinView] && !_hasSetCalloutOffset) {
        calloutView.calloutOffset = CGPointMake(-8,0);
    } else {
        calloutView.calloutOffset = self.calloutOffset;
    }

    if (self.calloutView) {
        calloutView.title = nil;
        calloutView.subtitle = nil;
        if (self.calloutView.tooltip) {
            // if tooltip is true, then the user wants their ReactABI21_0_0 view to be the "tooltip" as wwell, so we set
            // the background view to something empty/transparent
            calloutView.backgroundView = [ABI21_0_0AIREmptyCalloutBackgroundView new];
        } else {
            // the default tooltip look is wanted, and the user is just filling the content with their ReactABI21_0_0 subviews.
            // as a result, we use the default "masked" background view.
            calloutView.backgroundView = [ABI21_0_0SMCalloutMaskedBackgroundView new];
        }

        // when this is set, the callout's content will be whatever ReactABI21_0_0 views the user has put as the callout's
        // children.
        calloutView.contentView = self.calloutView;

    } else {

        // if there is no calloutView, it means the user wants to use the default callout behavior with title/subtitle
        // pairs.
        calloutView.title = self.title;
        calloutView.subtitle = self.subtitle;
        calloutView.contentView = nil;
        calloutView.backgroundView = [ABI21_0_0SMCalloutMaskedBackgroundView new];
    }
}

- (void)showCalloutView
{
    MKAnnotationView *annotationView = [self getAnnotationView];

    [self setSelected:YES animated:NO];

    id event = @{
            @"action": @"marker-select",
            @"id": self.identifier ?: @"unknown",
            @"coordinate": @{
                    @"latitude": @(self.coordinate.latitude),
                    @"longitude": @(self.coordinate.longitude)
            }
    };

    if (self.map.onMarkerSelect) self.map.onMarkerSelect(event);
    if (self.onSelect) self.onSelect(event);

    if (![self shouldShowCalloutView]) {
        // no callout to show
        return;
    }

    [self fillCalloutView:self.map.calloutView];

    // This is where we present our custom callout view... MapKit's built-in callout doesn't have the flexibility
    // we need, but a lot of work was done by Nick Farina to make this identical to MapKit's built-in.
    [self.map.calloutView presentCalloutFromRect:annotationView.bounds
                                         inView:annotationView
                              constrainedToView:self.map
                                       animated:YES];
}

#pragma mark - Tap Gesture & Events.

- (void)addTapGestureRecognizer {
    [self addGestureRecognizerToView:nil];
}

- (void)addGestureRecognizerToView:(UIView *)view {
    if (!view) {
        view = self;
    }
    UITapGestureRecognizer *tapGestureRecognizer = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(_handleTap:)];
    // setting this to NO allows the parent MapView to continue receiving marker selection events
    tapGestureRecognizer.cancelsTouchesInView = NO;
    [view addGestureRecognizer:tapGestureRecognizer];
}

- (void)_handleTap:(UITapGestureRecognizer *)recognizer {
    ABI21_0_0AIRMapMarker *marker = self;
    if (!marker) return;
    
    if (marker.selected) {
        CGPoint touchPoint = [recognizer locationInView:marker.map.calloutView];
        if ([marker.map.calloutView hitTest:touchPoint withEvent:nil]) {
            
            // the callout got clicked, not the marker
            id event = @{
                         @"action": @"callout-press",
                         };
            
            if (marker.onCalloutPress) marker.onCalloutPress(event);
            if (marker.calloutView && marker.calloutView.onPress) marker.calloutView.onPress(event);
            if (marker.map.onCalloutPress) marker.map.onCalloutPress(event);
            return;
        }
    }
    
    // the actual marker got clicked
    id event = @{
                 @"action": @"marker-press",
                 @"id": marker.identifier ?: @"unknown",
                 @"coordinate": @{
                         @"latitude": @(marker.coordinate.latitude),
                         @"longitude": @(marker.coordinate.longitude)
                         }
                 };
    
    if (marker.onPress) marker.onPress(event);
    if (marker.map.onMarkerPress) marker.map.onMarkerPress(event);
    
    [marker.map selectAnnotation:marker animated:NO];
}

- (void)hideCalloutView
{
    // hide the callout view
    [self.map.calloutView dismissCalloutAnimated:YES];

    [self setSelected:NO animated:NO];

    id event = @{
            @"action": @"marker-deselect",
            @"id": self.identifier ?: @"unknown",
            @"coordinate": @{
                    @"latitude": @(self.coordinate.latitude),
                    @"longitude": @(self.coordinate.longitude)
            }
    };

    if (self.map.onMarkerDeselect) self.map.onMarkerDeselect(event);
    if (self.onDeselect) self.onDeselect(event);
}

- (void)setCalloutOffset:(CGPoint)calloutOffset
{
    _hasSetCalloutOffset = YES;
    [super setCalloutOffset:calloutOffset];
}

- (BOOL)shouldShowCalloutView
{
    return self.calloutView != nil || self.title != nil || self.subtitle != nil;
}

- (BOOL)shouldUsePinView
{
    return self.ReactABI21_0_0Subviews.count == 0 && !self.imageSrc;
}

- (void)setOpacity:(double)opacity
{
  [self setAlpha:opacity];
}

- (void)setImageSrc:(NSString *)imageSrc
{
    _imageSrc = imageSrc;

    if (_reloadImageCancellationBlock) {
        _reloadImageCancellationBlock();
        _reloadImageCancellationBlock = nil;
    }
    _reloadImageCancellationBlock = [_bridge.imageLoader loadImageWithURLRequest:[ABI21_0_0RCTConvert NSURLRequest:_imageSrc]
                                                                            size:self.bounds.size
                                                                           scale:ABI21_0_0RCTScreenScale()
                                                                         clipped:YES
                                                                      resizeMode:ABI21_0_0RCTResizeModeCenter
                                                                   progressBlock:nil
                                                                partialLoadBlock:nil
                                                                 completionBlock:^(NSError *error, UIImage *image) {
                                                                     if (error) {
                                                                         // TODO(lmr): do something with the error?
                                                                         NSLog(@"%@", error);
                                                                     }
                                                                     dispatch_async(dispatch_get_main_queue(), ^{
                                                                         self.image = image;
                                                                     });
                                                                 }];
}

- (void)setPinColor:(UIColor *)pinColor
{
    _pinColor = pinColor;

    if ([_pinView respondsToSelector:@selector(setPinTintColor:)]) {
        _pinView.pinTintColor = _pinColor;
    }
}

- (void)setZIndex:(NSInteger)zIndex
{
    _zIndex = zIndex;
    self.layer.zPosition = _zIndex;
}

@end
