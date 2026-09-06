/*
 * Copyright (C) 2010 Apple Inc. All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 * 1. Redistributions of source code must retain the above copyright
 *    notice, this list of conditions and the following disclaimer.
 * 2. Redistributions in binary form must reproduce the above copyright
 *    notice, this list of conditions and the following disclaimer in the
 *    documentation and/or other materials provided with the distribution.
 *
 * THIS SOFTWARE IS PROVIDED BY APPLE INC. AND ITS CONTRIBUTORS ``AS IS''
 * AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO,
 * THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR
 * PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL APPLE INC. OR ITS CONTRIBUTORS
 * BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
 * CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
 * SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
 * INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
 * CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
 * ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF
 * THE POSSIBILITY OF SUCH DAMAGE.
 */

#import "config.h"
#import "TextIndicatorWindow.h"

#if PLATFORM(MAC)

#import "CoreGraphicsSPI.h"
#import "GeometryUtilities.h"
#import "GraphicsContext.h"
#import "PathUtilities.h"
#import "QuartzCoreSPI.h"
#import "TextIndicator.h"
#import "WebActionDisablingCALayerDelegate.h"

const CFTimeInterval bounceAnimationDuration = 0.12;
const CFTimeInterval bounceWithCrossfadeAnimationDuration = 0.3;
const CFTimeInterval fadeInAnimationDuration = 0.15;
const CFTimeInterval timeBeforeFadeStarts = bounceAnimationDuration + 0.2;
const CFTimeInterval fadeOutAnimationDuration = 0.3;

const CGFloat midBounceScale = 1.25;
const CGFloat borderWidth = 0;
const CGFloat cornerRadius = 0;
const CGFloat dropShadowOffsetX = 0;
const CGFloat dropShadowOffsetY = 1;
const CGFloat dropShadowBlurRadius = 2;
const CGFloat rimShadowBlurRadius = 1;

NSString *textLayerKey = @"TextLayer";
NSString *dropShadowLayerKey = @"DropShadowLayer";
NSString *rimShadowLayerKey = @"RimShadowLayer";

#if __MAC_OS_X_VERSION_MIN_REQUIRED == 1050
#define kAnimationCompletionBlock @"animationCompletionBlock"
#endif

using namespace WebCore;

@interface WebTextIndicatorView : NSView {
    RefPtr<TextIndicator> _textIndicator;
    RetainPtr<NSArray> _bounceLayers;
    NSSize _margin;
    bool _hasCompletedAnimation;
    BOOL _fadingOut;
}

- (id)initWithFrame:(NSRect)frame textIndicator:(TextIndicator&)textIndicator margin:(NSSize)margin offset:(NSPoint)offset;

- (void)present;
#if __MAC_OS_X_VERSION_MIN_REQUIRED >= 1060
- (void)hideWithCompletionHandler:(void(^)(void))completionHandler;
#else
- (void)hideWithCompletionHandler:(std::function<void (void)> *)completionHandler;
- (void)animationDidStop:(CAAnimation *)theAnimation finished:(BOOL)flag;
#endif
- (CGColorRef)NSColorToCGColor:(NSColor *)color;

- (void)setAnimationProgress:(float)progress;
- (BOOL)hasCompletedAnimation;

@property (nonatomic, getter=isFadingOut) BOOL fadingOut;

@end

@implementation WebTextIndicatorView

- (BOOL)isFadingOut
{
    return _fadingOut;
}

- (void)setFadingOut:(BOOL)fadingOut
{
    _fadingOut = fadingOut;
}

static bool indicatorWantsBounce(const TextIndicator& indicator)
{
    switch (indicator.presentationTransition()) {
    case TextIndicatorPresentationTransition::BounceAndCrossfade:
    case TextIndicatorPresentationTransition::Bounce:
        return true;

    case TextIndicatorPresentationTransition::FadeIn:
    case TextIndicatorPresentationTransition::None:
        return false;
    }

    ASSERT_NOT_REACHED();
    return false;
}

static bool indicatorWantsContentCrossfade(const TextIndicator& indicator)
{
    if (!indicator.data().contentImageWithHighlight)
        return false;

    switch (indicator.presentationTransition()) {
    case TextIndicatorPresentationTransition::BounceAndCrossfade:
        return true;

    case TextIndicatorPresentationTransition::Bounce:
    case TextIndicatorPresentationTransition::FadeIn:
    case TextIndicatorPresentationTransition::None:
        return false;
    }

    ASSERT_NOT_REACHED();
    return false;
}

static bool indicatorWantsFadeIn(const TextIndicator& indicator)
{
    switch (indicator.presentationTransition()) {
    case TextIndicatorPresentationTransition::FadeIn:
        return true;

    case TextIndicatorPresentationTransition::Bounce:
    case TextIndicatorPresentationTransition::BounceAndCrossfade:
    case TextIndicatorPresentationTransition::None:
        return false;
    }

    ASSERT_NOT_REACHED();
    return false;
}

static bool indicatorWantsManualAnimation(const TextIndicator& indicator)
{
    switch (indicator.presentationTransition()) {
    case TextIndicatorPresentationTransition::FadeIn:
        return true;

    case TextIndicatorPresentationTransition::Bounce:
    case TextIndicatorPresentationTransition::BounceAndCrossfade:
    case TextIndicatorPresentationTransition::None:
        return false;
    }

    ASSERT_NOT_REACHED();
    return false;
}

#if __MAC_OS_X_VERSION_MIN_REQUIRED == 1050
- (void)animationDidStop:(CAAnimation *)theAnimation finished:(BOOL)flag
{
    UNUSED_PARAM(flag);
    std::function<void (void)> *animationCompletionBlock = static_cast<std::function<void (void)> *>([[theAnimation valueForKey:kAnimationCompletionBlock] pointerValue]);
    if (animationCompletionBlock) {
        (*animationCompletionBlock)();
        delete animationCompletionBlock;
    }
}
#endif

- (CGColorRef)NSColorToCGColor:(NSColor *)color
{
    NSInteger numberOfComponents = [color numberOfComponents];
    CGFloat components[numberOfComponents];
    CGColorSpaceRef colorSpace = [[color colorSpace] CGColorSpace];
    [color getComponents:(CGFloat *)&components];
    CGColorRef cgColor = CGColorCreate(colorSpace, components);

    return cgColor;
}

- (id)initWithFrame:(NSRect)frame textIndicator:(TextIndicator&)textIndicator margin:(NSSize)margin offset:(NSPoint)offset
{
    if (!(self = [super initWithFrame:frame]))
        return nil;

    _textIndicator = &textIndicator;
    _margin = margin;

    self.wantsLayer = YES;
    self.layer.anchorPoint = CGPointZero;

    FloatSize contentsImageLogicalSize = _textIndicator->contentImage()->size();
    contentsImageLogicalSize.scale(1 / _textIndicator->contentImageScaleFactor());
    RetainPtr<CGImageRef> contentsImage;
    if (indicatorWantsContentCrossfade(*_textIndicator))
        contentsImage = _textIndicator->contentImageWithHighlight()->nativeImage();
    else
        contentsImage = _textIndicator->contentImage()->nativeImage();

    RetainPtr<NSMutableArray> bounceLayers = adoptNS([[NSMutableArray alloc] init]);

    RetainPtr<CGColorRef> highlightColor = [self NSColorToCGColor:[NSColor colorWithDeviceRed:1 green:1 blue:0 alpha:1]];
    RetainPtr<CGColorRef> rimShadowColor = [self NSColorToCGColor:[NSColor colorWithDeviceWhite:0 alpha:0.35]];
    RetainPtr<CGColorRef> dropShadowColor = [self NSColorToCGColor:[NSColor colorWithDeviceWhite:0 alpha:0.2]];

    RetainPtr<CGColorRef> borderColor = [self NSColorToCGColor:[NSColor colorWithDeviceRed:.96 green:.90 blue:0 alpha:1]];

    Vector<FloatRect> textRectsInBoundingRectCoordinates = _textIndicator->textRectsInBoundingRectCoordinates();

    Vector<Path> paths = PathUtilities::pathsWithShrinkWrappedRects(textRectsInBoundingRectCoordinates, cornerRadius);

    for (const auto& path : paths) {
        FloatRect pathBoundingRect = path.boundingRect();

        Path translatedPath;
        AffineTransform transform;
        transform.translate(-pathBoundingRect.x(), -pathBoundingRect.y());
        translatedPath.addPath(path, transform);

        FloatRect offsetTextRect = pathBoundingRect;
        offsetTextRect.move(offset.x, offset.y);

        FloatRect bounceLayerRect = offsetTextRect;
        bounceLayerRect.move(_margin.width, _margin.height);

        RetainPtr<CALayer> bounceLayer = adoptNS([[CALayer alloc] init]);
        [bounceLayer.get() setDelegate:[WebActionDisablingCALayerDelegate shared]];
        [bounceLayer.get() setFrame:bounceLayerRect];
        [bounceLayer.get() setOpacity:0];
        [bounceLayers.get() addObject:bounceLayer.get()];

        FloatRect yellowHighlightRect(FloatPoint(), bounceLayerRect.size());

        RetainPtr<CALayer> dropShadowLayer = adoptNS([[CALayer alloc] init]);
        [dropShadowLayer.get() setDelegate:[WebActionDisablingCALayerDelegate shared]];
        [dropShadowLayer.get() setShadowColor:dropShadowColor.get()];
        [dropShadowLayer.get() setShadowRadius:dropShadowBlurRadius];
        [dropShadowLayer.get() setShadowOffset:CGSizeMake(dropShadowOffsetX, dropShadowOffsetY)];
#if __MAC_OS_X_VERSION_MIN_REQUIRED >= 1070
        [dropShadowLayer.get() setShadowPath:translatedPath.platformPath()];
#endif
        [dropShadowLayer.get() setShadowOpacity:1];
        [dropShadowLayer.get() setFrame:yellowHighlightRect];
        [bounceLayer.get() addSublayer:dropShadowLayer.get()];
        [bounceLayer.get() setValue:dropShadowLayer.get() forKey:dropShadowLayerKey];

        RetainPtr<CALayer> rimShadowLayer = adoptNS([[CALayer alloc] init]);
        [rimShadowLayer.get() setDelegate:[WebActionDisablingCALayerDelegate shared]];
        [rimShadowLayer.get() setFrame:yellowHighlightRect];
        [rimShadowLayer.get() setShadowColor:rimShadowColor.get()];
        [rimShadowLayer.get() setShadowRadius:rimShadowBlurRadius];
#if __MAC_OS_X_VERSION_MIN_REQUIRED >= 1070
        [rimShadowLayer.get() setShadowPath:translatedPath.platformPath()];
#endif
        [rimShadowLayer.get() setShadowOffset:CGSizeZero];
        [rimShadowLayer.get() setShadowOpacity:1];
        [rimShadowLayer.get() setFrame:yellowHighlightRect];
        [bounceLayer.get() addSublayer:rimShadowLayer.get()];
        [bounceLayer.get() setValue:rimShadowLayer.get() forKey:rimShadowLayerKey];

        RetainPtr<CALayer> textLayer = adoptNS([[CALayer alloc] init]);
        [textLayer.get() setBackgroundColor:highlightColor.get()];
        [textLayer.get() setBorderColor:borderColor.get()];
        [textLayer.get() setBorderWidth:borderWidth];
        [textLayer.get() setDelegate:[WebActionDisablingCALayerDelegate shared]];
        [textLayer.get() setContents:(id)contentsImage.get()];

#if __MAC_OS_X_VERSION_MIN_REQUIRED >= 1060
        RetainPtr<CAShapeLayer> maskLayer = adoptNS([[CAShapeLayer alloc] init]);
        [maskLayer setPath:translatedPath.platformPath()];
        [textLayer setMask:maskLayer.get()];
#endif

        FloatRect imageRect = pathBoundingRect;
        [textLayer.get() setContentsRect:CGRectMake(imageRect.x() / contentsImageLogicalSize.width(), imageRect.y() / contentsImageLogicalSize.height(), imageRect.width() / contentsImageLogicalSize.width(), imageRect.height() / contentsImageLogicalSize.height())];
        [textLayer.get() setContentsGravity:kCAGravityCenter];
#if __MAC_OS_X_VERSION_MIN_REQUIRED >= 1070
        [textLayer.get() setContentsScale:_textIndicator->contentImageScaleFactor()];
#endif
        [textLayer.get() setFrame:yellowHighlightRect];
        [bounceLayer.get() setValue:textLayer.get() forKey:textLayerKey];
        [bounceLayer.get() addSublayer:textLayer.get()];
    }

    self.layer.sublayers = bounceLayers.get();
    _bounceLayers = bounceLayers;

    return self;
}

static RetainPtr<CAKeyframeAnimation> createBounceAnimation(CFTimeInterval duration)
{
    RetainPtr<CAKeyframeAnimation> bounceAnimation = [CAKeyframeAnimation animationWithKeyPath:@"transform"];
    [bounceAnimation.get() setValues:[NSArray arrayWithObjects:
        [NSValue valueWithCATransform3D:CATransform3DIdentity],
        [NSValue valueWithCATransform3D:CATransform3DMakeScale(midBounceScale, midBounceScale, 1)],
        [NSValue valueWithCATransform3D:CATransform3DIdentity],
        nil]];
    [bounceAnimation.get() setDuration:duration];

    return bounceAnimation;
}

static RetainPtr<CABasicAnimation> createContentCrossfadeAnimation(CFTimeInterval duration, TextIndicator& textIndicator)
{
    RetainPtr<CABasicAnimation> crossfadeAnimation = [CABasicAnimation animationWithKeyPath:@"contents"];
    RetainPtr<CGImageRef> contentsImage = textIndicator.contentImage()->nativeImage();
    [crossfadeAnimation.get() setToValue:(id)contentsImage.get()];
    [crossfadeAnimation.get() setFillMode:kCAFillModeForwards];
    [crossfadeAnimation.get() setRemovedOnCompletion:NO];
    [crossfadeAnimation.get() setDuration:duration];

    return crossfadeAnimation;
}

static RetainPtr<CABasicAnimation> createShadowFadeAnimation(CFTimeInterval duration)
{
    RetainPtr<CABasicAnimation> fadeShadowInAnimation = [CABasicAnimation animationWithKeyPath:@"shadowOpacity"];
    [fadeShadowInAnimation.get() setFromValue:[NSNumber numberWithInteger:0]];
    [fadeShadowInAnimation.get() setToValue:[NSNumber numberWithInteger:1]];
    [fadeShadowInAnimation.get() setFillMode:kCAFillModeForwards];
    [fadeShadowInAnimation.get() setRemovedOnCompletion:NO];
    [fadeShadowInAnimation.get() setDuration:duration];

    return fadeShadowInAnimation;
}

static RetainPtr<CABasicAnimation> createFadeInAnimation(CFTimeInterval duration)
{
    RetainPtr<CABasicAnimation> fadeInAnimation = [CABasicAnimation animationWithKeyPath:@"opacity"];
    [fadeInAnimation.get() setFromValue:[NSNumber numberWithInteger:0]];
    [fadeInAnimation.get() setToValue:[NSNumber numberWithInteger:1]];
    [fadeInAnimation.get() setFillMode:kCAFillModeForwards];
    [fadeInAnimation.get() setRemovedOnCompletion:NO];
    [fadeInAnimation.get() setDuration:duration];

    return fadeInAnimation;
}

- (CFTimeInterval)_animationDuration
{
    if (indicatorWantsBounce(*_textIndicator)) {
        if (indicatorWantsContentCrossfade(*_textIndicator))
            return bounceWithCrossfadeAnimationDuration;
        return bounceAnimationDuration;
    }

    return fadeInAnimationDuration;
}

- (BOOL)hasCompletedAnimation
{
    return _hasCompletedAnimation;
}

- (void)present
{
    bool wantsBounce = indicatorWantsBounce(*_textIndicator);
    bool wantsCrossfade = indicatorWantsContentCrossfade(*_textIndicator);
    bool wantsFadeIn = indicatorWantsFadeIn(*_textIndicator);
    CFTimeInterval animationDuration = [self _animationDuration];

    _hasCompletedAnimation = false;

    RetainPtr<CAAnimation> presentationAnimation;
    if (wantsBounce)
        presentationAnimation = createBounceAnimation(animationDuration);
    else if (wantsFadeIn)
        presentationAnimation = createFadeInAnimation(animationDuration);

    RetainPtr<CABasicAnimation> crossfadeAnimation;
    RetainPtr<CABasicAnimation> fadeShadowInAnimation;
    if (wantsCrossfade) {
        crossfadeAnimation = createContentCrossfadeAnimation(animationDuration, *_textIndicator);
        fadeShadowInAnimation = createShadowFadeAnimation(animationDuration);
    }

    [CATransaction begin];
    NSEnumerator *enumerator = [_bounceLayers.get() objectEnumerator];
    CALayer *bounceLayer;
    while ((bounceLayer = [enumerator nextObject])) {
        if (indicatorWantsManualAnimation(*_textIndicator))
            bounceLayer.speed = 0;

        if (!wantsFadeIn)
            bounceLayer.opacity = 1;

        if (presentationAnimation)
            [bounceLayer addAnimation:presentationAnimation.get() forKey:@"presentation"];

        if (wantsCrossfade) {
            [[bounceLayer valueForKey:textLayerKey] addAnimation:crossfadeAnimation.get() forKey:@"contentTransition"];
            [[bounceLayer valueForKey:dropShadowLayerKey] addAnimation:fadeShadowInAnimation.get() forKey:@"fadeShadowIn"];
            [[bounceLayer valueForKey:rimShadowLayerKey] addAnimation:fadeShadowInAnimation.get() forKey:@"fadeShadowIn"];
        }
    }
    [CATransaction commit];
}

#if __MAC_OS_X_VERSION_MIN_REQUIRED >= 1060
- (void)hideWithCompletionHandler:(void(^)(void))completionHandler
#else
- (void)hideWithCompletionHandler:(std::function<void (void)> *)completionHandler
#endif
{
    RetainPtr<CABasicAnimation> fadeAnimation = [CABasicAnimation animationWithKeyPath:@"opacity"];
    [fadeAnimation.get() setFromValue:[NSNumber numberWithInteger:1]];
    [fadeAnimation.get() setToValue:[NSNumber numberWithInteger:0]];
    [fadeAnimation.get() setFillMode:kCAFillModeForwards];
    [fadeAnimation.get() setRemovedOnCompletion:NO];
    [fadeAnimation.get() setDuration:fadeOutAnimationDuration];
#if __MAC_OS_X_VERSION_MIN_REQUIRED == 1050
    [fadeAnimation.get() setDelegate:self];
    [fadeAnimation.get() setValue:[NSValue valueWithPointer:completionHandler] forKey:kAnimationCompletionBlock];
#endif

    [CATransaction begin];
#if __MAC_OS_X_VERSION_MIN_REQUIRED >= 1060
    [CATransaction setCompletionBlock:completionHandler];
#endif
    [self.layer addAnimation:fadeAnimation.get() forKey:@"fadeOut"];
    [CATransaction commit];
}

- (void)setAnimationProgress:(float)progress
{
    if (_hasCompletedAnimation)
        return;

    if (progress == 1) {
        _hasCompletedAnimation = true;

        NSEnumerator *enumerator = [_bounceLayers.get() objectEnumerator];
        CALayer *bounceLayer;
        while ((bounceLayer = [enumerator nextObject])) {
            // Continue the animation from wherever it had manually progressed to.
            CFTimeInterval beginTime = bounceLayer.timeOffset;
            bounceLayer.speed = 1;
            beginTime = [bounceLayer convertTime:CACurrentMediaTime() fromLayer:nil] - beginTime;
            bounceLayer.beginTime = beginTime;
        }
    } else {
        CFTimeInterval animationDuration = [self _animationDuration];
        NSEnumerator *enumerator = [_bounceLayers.get() objectEnumerator];
        CALayer *bounceLayer;
        while ((bounceLayer = [enumerator nextObject]))
            bounceLayer.timeOffset = progress * animationDuration;
    }
}

- (BOOL)isFlipped
{
    return YES;
}

@end

namespace WebCore {

TextIndicatorWindow::TextIndicatorWindow(NSView *targetView)
    : m_targetView(targetView)
    , m_temporaryTextIndicatorTimer(RunLoop::main(), this, &TextIndicatorWindow::startFadeOut)
{
}

TextIndicatorWindow::~TextIndicatorWindow()
{
    clearTextIndicator(TextIndicatorWindowDismissalAnimation::FadeOut);
}

void TextIndicatorWindow::setAnimationProgress(float progress)
{
    if (!m_textIndicator)
        return;

    [m_textIndicatorView.get() setAnimationProgress:progress];
}

void TextIndicatorWindow::clearTextIndicator(TextIndicatorWindowDismissalAnimation animation)
{
    RefPtr<TextIndicator> textIndicator = WTFMove(m_textIndicator);

    if ([m_textIndicatorView.get() isFadingOut])
        return;

    if (textIndicator && indicatorWantsManualAnimation(*textIndicator) && [m_textIndicatorView.get() hasCompletedAnimation] && animation == TextIndicatorWindowDismissalAnimation::FadeOut) {
        startFadeOut();
        return;
    }

    closeWindow();
}

void TextIndicatorWindow::setTextIndicator(Ref<TextIndicator> textIndicator, CGRect textBoundingRectInScreenCoordinates, TextIndicatorWindowLifetime lifetime)
{
    if (m_textIndicator == textIndicator.ptr())
        return;

    closeWindow();

    m_textIndicator = textIndicator.ptr();

    CGFloat horizontalMargin = dropShadowBlurRadius * 2 + TextIndicator::defaultHorizontalMargin;
    CGFloat verticalMargin = dropShadowBlurRadius * 2 + TextIndicator::defaultVerticalMargin;
    
    if (indicatorWantsBounce(*m_textIndicator)) {
        horizontalMargin = std::max(horizontalMargin, textBoundingRectInScreenCoordinates.size.width * (midBounceScale - 1) + horizontalMargin);
        verticalMargin = std::max(verticalMargin, textBoundingRectInScreenCoordinates.size.height * (midBounceScale - 1) + verticalMargin);
    }

    horizontalMargin = CGCeiling(horizontalMargin);
    verticalMargin = CGCeiling(verticalMargin);

    CGRect contentRect = CGRectInset(textBoundingRectInScreenCoordinates, -horizontalMargin, -verticalMargin);
    NSRect windowContentRect = [NSWindow contentRectForFrameRect:NSRectFromCGRect(contentRect) styleMask:NSWindowStyleMaskBorderless];
    NSRect integralWindowContentRect = NSIntegralRect(windowContentRect);
    NSPoint fractionalTextOffset = NSMakePoint(windowContentRect.origin.x - integralWindowContentRect.origin.x, windowContentRect.origin.y - integralWindowContentRect.origin.y);
    m_textIndicatorWindow = adoptNS([[NSWindow alloc] initWithContentRect:integralWindowContentRect styleMask:NSWindowStyleMaskBorderless backing:NSBackingStoreBuffered defer:NO]);
    [m_textIndicatorWindow.get() setBackgroundColor:[NSColor clearColor]];
    [m_textIndicatorWindow.get() setOpaque:NO];
    [m_textIndicatorWindow.get() setIgnoresMouseEvents:YES];

    m_textIndicatorView = adoptNS([[WebTextIndicatorView alloc] initWithFrame:NSMakeRect(0, 0, [m_textIndicatorWindow.get() frame].size.width, [m_textIndicatorWindow.get() frame].size.height)
        textIndicator:*m_textIndicator margin:NSMakeSize(horizontalMargin, verticalMargin) offset:fractionalTextOffset]);
    [m_textIndicatorWindow.get() setContentView:m_textIndicatorView.get()];

    [[m_targetView window] addChildWindow:m_textIndicatorWindow.get() ordered:NSWindowAbove];
    [m_textIndicatorWindow.get() setReleasedWhenClosed:NO];

    if (m_textIndicator->presentationTransition() != TextIndicatorPresentationTransition::None)
        [m_textIndicatorView.get() present];

    if (lifetime == TextIndicatorWindowLifetime::Temporary)
        m_temporaryTextIndicatorTimer.startOneShot(1_s * timeBeforeFadeStarts);
}

void TextIndicatorWindow::closeWindow()
{
    if (!m_textIndicatorWindow)
        return;

    if ([m_textIndicatorView.get() isFadingOut])
        return;

    m_temporaryTextIndicatorTimer.stop();

    [[m_textIndicatorWindow.get() parentWindow] removeChildWindow:m_textIndicatorWindow.get()];
    [m_textIndicatorWindow.get() close];
    m_textIndicatorWindow = nullptr;
}

void TextIndicatorWindow::startFadeOut()
{
    [m_textIndicatorView.get() setFadingOut:YES];
    RetainPtr<NSWindow> indicatorWindow = m_textIndicatorWindow;
    [m_textIndicatorView.get() hideWithCompletionHandler:
#if __MAC_OS_X_VERSION_MIN_REQUIRED >= 1060
      [indicatorWindow] {
#else
      new std::function<void (void)>([=] {
#endif
        [[indicatorWindow.get() parentWindow] removeChildWindow:indicatorWindow.get()];
        [indicatorWindow.get() close];
      }
#if __MAC_OS_X_VERSION_MIN_REQUIRED == 1050
     )
#endif
    ];
}

} // namespace WebCore

#endif // PLATFORM(MAC)
