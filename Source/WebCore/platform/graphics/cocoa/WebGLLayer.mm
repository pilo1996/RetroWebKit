/*
 * Copyright (C) 2009-2017 Apple Inc. All rights reserved.
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
 * THIS SOFTWARE IS PROVIDED BY APPLE INC. ``AS IS'' AND ANY
 * EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 * IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR
 * PURPOSE ARE DISCLAIMED.  IN NO EVENT SHALL APPLE INC. OR
 * CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL,
 * EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO,
 * PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR
 * PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY
 * OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
 * (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
 * OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE. 
 */

#include "config.h"

#if ENABLE(WEBGL)
#import "WebGLLayer.h"

#import "GraphicsContext3D.h"
#import "GraphicsContextCG.h"
#import "GraphicsLayer.h"
#import "GraphicsLayerCA.h"
#import "PlatformCALayer.h"
#import "QuartzCoreSPI.h"
#import <wtf/FastMalloc.h>
#import <wtf/RetainPtr.h>

#if PLATFORM(MAC)
#import <OpenGL/OpenGL.h>
#import <OpenGL/gl.h>
#endif

using namespace WebCore;

@implementation WebGLLayer

-(GraphicsContext3D*)context
{
    return _context;
}

-(void)setContext:(GraphicsContext3D*)context
{
    _context = context;
}

-(id)initWithGraphicsContext3D:(GraphicsContext3D*)context
{
    _context = context;
    self = [super init];
    _devicePixelRatio = context->getContextAttributes().devicePixelRatio;
#if PLATFORM(MAC) && USE(IOSURFACE)
    if (!context->getContextAttributes().alpha)
        self.opaque = YES;
    self.transform = CATransform3DIdentity;
    self.contentsScale = _devicePixelRatio;
#endif
    return self;
}

#if PLATFORM(MAC)
#if USE(IOSURFACE)
// On Mac, we need to flip the layer to take into account
// that the IOSurface provides content in Y-up. This
// means that any incoming transform (unlikely, since this
// is a contents layer) and anchor point must add a
// Y scale of -1 and make sure the transform happens from
// the top.

- (void)setTransform:(CATransform3D)t
{
    [super setTransform:CATransform3DScale(t, 1, -1, 1)];
}

- (void)setAnchorPoint:(CGPoint)p
{
    [super setAnchorPoint:CGPointMake(p.x, 1.0 - p.y)];
}

#else
-(CGLPixelFormatObj)copyCGLPixelFormatForDisplayMask:(uint32_t)mask
{
    // We're basically copying the pixel format object from the existing
    // WebGL context, so we don't need to use the display mask.
    UNUSED_PARAM(mask);

    CGLPixelFormatObj webglPixelFormat = CGLGetPixelFormat(_context->platformGraphicsContext3D());

    Vector<CGLPixelFormatAttribute> attribs;
    GLint value;

    CGLDescribePixelFormat(webglPixelFormat, 0, kCGLPFAColorSize, &value);
    attribs.append(kCGLPFAColorSize);
    attribs.append(static_cast<CGLPixelFormatAttribute>(value));

    // We don't need to specify a depth size since we're only
    // using this context as a 2d blit destination for the WebGL FBO.
    attribs.append(kCGLPFADepthSize);
    attribs.append(static_cast<CGLPixelFormatAttribute>(0));

    CGLDescribePixelFormat(webglPixelFormat, 0, kCGLPFAAllowOfflineRenderers, &value);
    if (value)
        attribs.append(kCGLPFAAllowOfflineRenderers);

    CGLDescribePixelFormat(webglPixelFormat, 0, kCGLPFAAccelerated, &value);
    if (value)
        attribs.append(kCGLPFAAccelerated);

    attribs.append(static_cast<CGLPixelFormatAttribute>(0));

    CGLPixelFormatObj pixelFormat;
    GLint numPixelFormats = 0;
    CGLChoosePixelFormat(attribs.data(), &pixelFormat, &numPixelFormats);

    ASSERT(pixelFormat);
    ASSERT(numPixelFormats);

    return pixelFormat;
}

-(CGLContextObj)copyCGLContextForPixelFormat:(CGLPixelFormatObj)pixelFormat
{
    CGLContextObj contextObj;
    CGLCreateContext(pixelFormat, _context->platformGraphicsContext3D(), &contextObj);
    return contextObj;
}

-(void)drawInCGLContext:(CGLContextObj)glContext pixelFormat:(CGLPixelFormatObj)pixelFormat forLayerTime:(CFTimeInterval)timeInterval displayTime:(const CVTimeStamp *)timeStamp
{
    if (!_context)
        return;

    _context->prepareTexture();

    CGLSetCurrentContext(glContext);

    CGRect frame = [self frame];
    frame.size.width *= _devicePixelRatio;
    frame.size.height *= _devicePixelRatio;

    // draw the FBO into the layer
    glViewport(0, 0, frame.size.width, frame.size.height);
    glMatrixMode(GL_PROJECTION);
    glLoadIdentity();
    glOrtho(-1, 1, -1, 1, -1, 1);
    glMatrixMode(GL_MODELVIEW);
    glLoadIdentity();

    glEnable(GL_TEXTURE_2D);
    glBindTexture(GL_TEXTURE_2D, _context->platformTexture());

    glBegin(GL_TRIANGLE_FAN);
        glTexCoord2f(0, 0);
        glVertex2f(-1, -1);
        glTexCoord2f(1, 0);
        glVertex2f(1, -1);
        glTexCoord2f(1, 1);
        glVertex2f(1, 1);
        glTexCoord2f(0, 1);
        glVertex2f(-1, 1);
    glEnd();

    glBindTexture(GL_TEXTURE_2D, 0);
    glDisable(GL_TEXTURE_2D);

    // Call super to finalize the drawing. By default all it does is call glFlush().
    [super drawInCGLContext:glContext pixelFormat:pixelFormat forLayerTime:timeInterval displayTime:timeStamp];
}
#endif

static void freeData(void *, const void *data, size_t /* size */)
{
    fastFree(const_cast<void *>(data));
}
#endif

-(CGImageRef)copyImageSnapshotWithColorSpace:(CGColorSpaceRef)colorSpace
{
    if (!_context)
        return nullptr;

#if PLATFORM(IOS)
    UNUSED_PARAM(colorSpace);
    return nullptr;
#else
    CGLSetCurrentContext(_context->platformGraphicsContext3D());

    RetainPtr<CGColorSpaceRef> imageColorSpace = colorSpace;
    if (!imageColorSpace)
        imageColorSpace = sRGBColorSpaceRef();

    CGRect layerBounds = CGRectIntegral([self bounds]);

    size_t width = layerBounds.size.width * _devicePixelRatio;
    size_t height = layerBounds.size.height * _devicePixelRatio;

    size_t rowBytes = (width * 4 + 15) & ~15;
    size_t dataSize = rowBytes * height;
    void* data = fastMalloc(dataSize);
    if (!data)
        return nullptr;

    glPixelStorei(GL_PACK_ROW_LENGTH, rowBytes / 4);
    glReadPixels(0, 0, width, height, GL_BGRA, GL_UNSIGNED_INT_8_8_8_8_REV, data);

    CGDataProviderRef provider = CGDataProviderCreateWithData(0, data, dataSize, freeData);
    CGImageRef image = CGImageCreate(width, height, 8, 32, rowBytes, imageColorSpace.get(),
        kCGImageAlphaPremultipliedFirst | kCGBitmapByteOrder32Host, provider, 0, true, kCGRenderingIntentDefault);
    CGDataProviderRelease(provider);
    return image;
#endif
}

- (void)display
{
    if (!_context)
        return;

#if PLATFORM(MAC)
#if USE(IOSURFACE)
    _context->prepareTexture();
    if (_drawingBuffer) {
        std::swap(_contentsBuffer, _drawingBuffer);
        self.contents = _contentsBuffer->asLayerContents();
        [self reloadValueForKeyPath:@"contents"];
        [self bindFramebufferToNextAvailableSurface];
    }
#else
    [super display];
#endif
#else
    _context->presentRenderbuffer();
#endif

    _context->markLayerComposited();
    PlatformCALayer* layer = PlatformCALayer::platformCALayer(self);
    if (layer && layer->owner())
        layer->owner()->platformCALayerLayerDidDisplay(layer);
}

#if PLATFORM(MAC) && USE(IOSURFACE)
- (void)allocateIOSurfaceBackingStoreWithSize:(IntSize)size usingAlpha:(BOOL)usingAlpha
{
    _bufferSize = size;
    _usingAlpha = usingAlpha;
    _contentsBuffer = WebCore::IOSurface::create(size, sRGBColorSpaceRef());
    _drawingBuffer = WebCore::IOSurface::create(size, sRGBColorSpaceRef());
    _spareBuffer = WebCore::IOSurface::create(size, sRGBColorSpaceRef());
    ASSERT(_contentsBuffer);
    ASSERT(_drawingBuffer);
    ASSERT(_spareBuffer);
}

- (void)bindFramebufferToNextAvailableSurface
{
    GC3Denum texture = _context->platformTexture();
    glBindTexture(GL_TEXTURE_RECTANGLE_ARB, texture);

    if (_drawingBuffer && _drawingBuffer->isInUse())
        std::swap(_drawingBuffer, _spareBuffer);

    IOSurfaceRef ioSurface = _drawingBuffer->surface();
    GC3Denum internalFormat = _usingAlpha ? GL_RGBA : GL_RGB;

    // Link the IOSurface to the texture.
    CGLError error = CGLTexImageIOSurface2D(_context->platformGraphicsContext3D(), GL_TEXTURE_RECTANGLE_ARB, internalFormat, _bufferSize.width(), _bufferSize.height(), GL_BGRA, GL_UNSIGNED_INT_8_8_8_8_REV, ioSurface, 0);
    ASSERT_UNUSED(error, error == kCGLNoError);
}
#endif

@end

#endif // ENABLE(WEBGL)
