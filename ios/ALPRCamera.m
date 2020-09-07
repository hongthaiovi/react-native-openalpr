//
//  RCTCamera.m
//  RNOpenAlpr
//
//  Created by Evan Rosenfeld on 2/24/17.
//  Copyright © 2017 CarDash. All rights reserved.
//

#import "ALPRCamera.h"
#import "ALPRCameraManager.h"
#import <React/RCTLog.h>
#import <React/RCTUtils.h>

#import <React/UIView+React.h>

#import "CameraTouchFocusView.h"
#import "RecognizedPlateBorderView.h"

@interface ALPRCamera ()


@property (nonatomic, weak) ALPRCameraManager *manager;
@property (nonatomic, weak) RCTBridge *bridge;
@property (nonatomic, strong) CameraTouchFocusView *camFocus;
@property (nonatomic, strong) UIView *detectReview;

@end

@implementation ALPRCamera
{
    BOOL _multipleTouches;
    BOOL _touchToFocus;
    BOOL _showPlateOutline;
    NSString *_plateOutlineColor;
}

- (void) setPlateOutlineColor:(NSString *)color {
    _plateOutlineColor = color;
}

- (void)setTouchToFocus:(BOOL)enabled {
    _touchToFocus = enabled;
}

- (void)setShowPlateOutline:(BOOL)enabled {
    _showPlateOutline = enabled;
}

- (id)initWithManager:(ALPRCameraManager*)manager bridge:(RCTBridge *)bridge
{
    
    if ((self = [super init])) {
        self.manager = manager;
        self.bridge = bridge;
        UIPinchGestureRecognizer *pinchGesture = [[UIPinchGestureRecognizer alloc] initWithTarget:self action:@selector(handlePinchToZoomRecognizer:)];
        [self addGestureRecognizer:pinchGesture];
        [self.manager initializeCaptureSessionInput:AVMediaTypeVideo];
        [self.manager startSession];
        _multipleTouches = NO;
        _touchToFocus = YES;
        _showPlateOutline = YES;
    }
    return self;
}
//PlateResult
- (void)updatePlateBorder:(NSArray *)results orientation:(UIDeviceOrientation)orientation {
    if (!_showPlateOutline) return;
    [self.detectReview.subviews makeObjectsPerformSelector: @selector(removeFromSuperview)];
    if (!UIDeviceOrientationIsValidInterfaceOrientation(orientation)) return;
    for (int j = 0; j < results.count; j++) {
        PlateResult *result = results[j];
        NSArray *points = result.points;
        NSMutableArray *newPoints = [NSMutableArray array];
        for (int i = 0; i < points.count; i++) {
            CGPoint pt = [[points objectAtIndex:i] CGPointValue];
            CGPoint newPt;
            switch (orientation) {
                case UIDeviceOrientationPortrait:
                    newPt = CGPointMake(pt.y / result.rows, (result.cols - pt.x) / result.cols);
                    break;
                case UIDeviceOrientationLandscapeLeft:
                    newPt = CGPointMake(pt.x / result.cols, pt.y / result.rows);
                    break;
                case UIDeviceOrientationLandscapeRight:
                    newPt = CGPointMake((result.cols - pt.x) / result.cols, (result.rows - pt.y) / result.rows);
                    break;
                default:
                    break;
            }
            [newPoints addObject:[NSValue valueWithCGPoint:[self.manager.previewLayer pointForCaptureDevicePointOfInterest:newPt]]];
        }
        RecognizedPlateBorderView *plateBorder = [RecognizedPlateBorderView new];
        plateBorder.colorString = self->_plateOutlineColor;
        plateBorder.alpha = 1;
        plateBorder.frame = self.bounds;
        [plateBorder updateCorners:newPoints];
        [self.detectReview addSubview:plateBorder];
    }
}

- (void)layoutSubviews
{
    [super layoutSubviews];
    self.detectReview = [UIView new];
    self.manager.previewLayer.frame = self.bounds;
    self.detectReview.frame = self.bounds;
    [self.detectReview setBackgroundColor: [UIColor clearColor]];
    [self setBackgroundColor:[UIColor blackColor]];
    [self.layer insertSublayer:self.manager.previewLayer atIndex:0];
    [self addSubview:self.detectReview];
    
}

- (void)insertReactSubview:(UIView *)view atIndex:(NSInteger)atIndex
{
    [self insertSubview:view atIndex:atIndex + 1];
    return;
}

- (void)removeReactSubview:(UIView *)subview
{
    [subview removeFromSuperview];
    return;
}

- (void)removeFromSuperview
{
    [self.manager stopSession];
    [super removeFromSuperview];
}


- (void) touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event
{
    // Update the touch state.
    if ([[event touchesForView:self] count] > 1) {
        _multipleTouches = YES;
    }
    
}

- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event
{
    if (!_touchToFocus) return;
    
    BOOL allTouchesEnded = ([touches count] == [[event touchesForView:self] count]);
    
    // Do not conflict with zooming and etc.
    if (allTouchesEnded && !_multipleTouches) {
        UITouch *touch = [[event allTouches] anyObject];
        CGPoint touchPoint = [touch locationInView:touch.view];
        // Focus camera on this point
        [self.manager focusAtThePoint:touchPoint];
        
        if (self.camFocus)
        {
            [self.camFocus removeFromSuperview];
        }
        
        // Show animated rectangle on the touched area
        if (_touchToFocus) {
            self.camFocus = [[CameraTouchFocusView alloc]initWithFrame:CGRectMake(touchPoint.x-40, touchPoint.y-40, 80, 80)];
            [self.camFocus setBackgroundColor:[UIColor clearColor]];
            [self addSubview:self.camFocus];
            [self.camFocus setNeedsDisplay];
            
            [UIView beginAnimations:nil context:NULL];
            [UIView setAnimationDuration:1.0];
            [self.camFocus setAlpha:0.0];
            [UIView commitAnimations];
        }
    }
    
    if (allTouchesEnded) {
        _multipleTouches = NO;
    }
    
}

-(void) handlePinchToZoomRecognizer:(UIPinchGestureRecognizer*)pinchRecognizer {
    
    if (pinchRecognizer.state == UIGestureRecognizerStateChanged) {
        return;
    }
}


@end
