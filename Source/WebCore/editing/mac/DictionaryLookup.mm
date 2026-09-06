/*
 * Copyright (C) 2014 Apple Inc. All rights reserved.
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
#import "DictionaryLookup.h"

#if PLATFORM(MAC)

#import "Document.h"
#import "Editing.h"
#import "FocusController.h"
#import "Frame.h"
#import "FrameSelection.h"
#import "HTMLConverter.h"
#import "HitTestResult.h"
#import "LookupSPI.h"
#import "NSImmediateActionGestureRecognizerSPI.h"
#import "Page.h"
#import "Range.h"
#import "RenderObject.h"
#import "TextIterator.h"
#import "VisiblePosition.h"
#import "VisibleSelection.h"
#import "VisibleUnits.h"
#import "WebCoreSystemInterface.h"
#import <PDFKit/PDFKit.h>
#import <wtf/BlockObjCExceptions.h>
#import <wtf/RefPtr.h>

#if __MAC_OS_X_VERSION_MIN_REQUIRED >= 1070
SOFT_LINK_CONSTANT_MAY_FAIL(Lookup, LUTermOptionDisableSearchTermIndicator, NSString *)
#endif

namespace WebCore {

static bool selectionContainsPosition(const VisiblePosition& position, const VisibleSelection& selection)
{
    if (!selection.isRange())
        return false;

    RefPtr<Range> selectedRange = selection.toNormalizedRange();
    if (!selectedRange)
        return false;

    return selectedRange->contains(position);
}

RefPtr<Range> DictionaryLookup::rangeForSelection(const VisibleSelection& selection, NSDictionary **options)
{
    RefPtr<Range> selectedRange = selection.toNormalizedRange();
    if (!selectedRange)
        return nullptr;

#if __MAC_OS_X_VERSION_MIN_REQUIRED >= 1070
    VisiblePosition selectionStart = selection.visibleStart();
    VisiblePosition selectionEnd = selection.visibleEnd();

    // As context, we are going to use the surrounding paragraphs of text.
    VisiblePosition paragraphStart = startOfParagraph(selectionStart);
    VisiblePosition paragraphEnd = endOfParagraph(selectionEnd);

    int lengthToSelectionStart = TextIterator::rangeLength(makeRange(paragraphStart, selectionStart).get());
    int lengthToSelectionEnd = TextIterator::rangeLength(makeRange(paragraphStart, selectionEnd).get());
    NSRange rangeToPass = NSMakeRange(lengthToSelectionStart, lengthToSelectionEnd - lengthToSelectionStart);

    String fullPlainTextString = plainText(makeRange(paragraphStart, paragraphEnd).get());

    BEGIN_BLOCK_OBJC_EXCEPTIONS;
    // Since we already have the range we want, we just need to grab the returned options.
    if (Class luLookupDefinitionModule = getLULookupDefinitionModuleClass())
        [luLookupDefinitionModule tokenRangeForString:fullPlainTextString range:rangeToPass options:options];
    END_BLOCK_OBJC_EXCEPTIONS;
#else
    UNUSED_PARAM(options);
#endif

    return selectedRange;
}

RefPtr<Range> DictionaryLookup::rangeAtHitTestResult(const HitTestResult& hitTestResult, NSDictionary **options)
{
    Node* node = hitTestResult.innerNonSharedNode();
    if (!node)
        return nullptr;

    auto renderer = node->renderer();
    if (!renderer)
        return nullptr;

    Frame* frame = node->document().frame();
    if (!frame)
        return nullptr;

    // Don't do anything if there is no character at the point.
    IntPoint framePoint = hitTestResult.roundedPointInInnerNodeFrame();
    if (!frame->rangeForPoint(framePoint))
        return nullptr;

    VisiblePosition position = frame->visiblePositionForPoint(framePoint);
    if (position.isNull())
        position = firstPositionInOrBeforeNode(node);

    // If we hit the selection, use that instead of letting Lookup decide the range.
    VisibleSelection selection = frame->page()->focusController().focusedOrMainFrame().selection().selection();
    if (selectionContainsPosition(position, selection))
        return DictionaryLookup::rangeForSelection(selection, options);

#if __MAC_OS_X_VERSION_MIN_REQUIRED >= 1070
    VisibleSelection selectionAccountingForLineRules = VisibleSelection(position);
    selectionAccountingForLineRules.expandUsingGranularity(WordGranularity);
    position = selectionAccountingForLineRules.start();

    // As context, we are going to use 250 characters of text before and after the point.
    RefPtr<Range> fullCharacterRange = rangeExpandedAroundPositionByCharacters(position, 250);
    if (!fullCharacterRange)
        return nullptr;

    BEGIN_BLOCK_OBJC_EXCEPTIONS;

    NSRange rangeToPass = NSMakeRange(TextIterator::rangeLength(makeRange(fullCharacterRange->startPosition(), position).get()), 0);

    String fullPlainTextString = plainText(fullCharacterRange.get());

    NSRange extractedRange = NSMakeRange(rangeToPass.location, 0);
    if (Class luLookupDefinitionModule = getLULookupDefinitionModuleClass())
        extractedRange = [luLookupDefinitionModule tokenRangeForString:fullPlainTextString range:rangeToPass options:options];

    // This function sometimes returns {NSNotFound, 0} if it was unable to determine a good string.
    // FIXME (159063): We shouldn't need to check for zero length here.
    if (extractedRange.location == NSNotFound || extractedRange.length == 0)
        return nullptr;

    return TextIterator::subrange(*fullCharacterRange, extractedRange.location, extractedRange.length);

    END_BLOCK_OBJC_EXCEPTIONS;
#endif
    return nullptr;
}

#if __MAC_OS_X_VERSION_MIN_REQUIRED >= 1070
static void expandSelectionByCharacters(PDFSelection *selection, NSInteger numberOfCharactersToExpand, NSInteger& charactersAddedBeforeStart, NSInteger& charactersAddedAfterEnd)
{
    BEGIN_BLOCK_OBJC_EXCEPTIONS;

    size_t originalLength = selection.string.length;
    [selection extendSelectionAtStart:numberOfCharactersToExpand];
    
    charactersAddedBeforeStart = selection.string.length - originalLength;
    
    [selection extendSelectionAtEnd:numberOfCharactersToExpand];
    charactersAddedAfterEnd = selection.string.length - originalLength - charactersAddedBeforeStart;

    END_BLOCK_OBJC_EXCEPTIONS;
}
#endif

NSString *DictionaryLookup::stringForPDFSelection(PDFSelection *selection, NSDictionary **options)
{
    BEGIN_BLOCK_OBJC_EXCEPTIONS;

    // Don't do anything if there is no character at the point.
    if (!selection || !selection.string.length)
        return @"";
    
#if __MAC_OS_X_VERSION_MIN_REQUIRED >= 1070
    RetainPtr<PDFSelection> selectionForLookup = adoptNS([selection copy]);
    
    // As context, we are going to use 250 characters of text before and after the point.
    NSInteger originalLength = [selectionForLookup.get() string].length;
    NSInteger charactersAddedBeforeStart = 0;
    NSInteger charactersAddedAfterEnd = 0;
    expandSelectionByCharacters(selectionForLookup.get(), 250, charactersAddedBeforeStart, charactersAddedAfterEnd);
    
    NSString *fullPlainTextString = [selectionForLookup.get() string];
    NSRange rangeToPass = NSMakeRange(charactersAddedBeforeStart, 0);
    
    NSRange extractedRange = NSMakeRange(rangeToPass.location, 0);
    if (Class luLookupDefinitionModule = getLULookupDefinitionModuleClass())
        extractedRange = [luLookupDefinitionModule tokenRangeForString:fullPlainTextString range:rangeToPass options:options];
    
    // This function sometimes returns {NSNotFound, 0} if it was unable to determine a good string.
    if (extractedRange.location == NSNotFound)
        return selection.string;
    
    NSInteger lookupAddedBefore = rangeToPass.location - extractedRange.location;
    NSInteger lookupAddedAfter = (extractedRange.location + extractedRange.length) - (rangeToPass.location + originalLength);
    
    [selection extendSelectionAtStart:lookupAddedBefore];
    [selection extendSelectionAtEnd:lookupAddedAfter];
    
    ASSERT([selection.string isEqualToString:[fullPlainTextString substringWithRange:extractedRange]]);
#else
    UNUSED_PARAM(options);
#endif
    return selection.string;

    END_BLOCK_OBJC_EXCEPTIONS;
    return nil;
}

#if __MAC_OS_X_VERSION_MIN_REQUIRED == 1050
static CGPoint coreGraphicsScreenPointForAppKitScreenPoint(NSPoint point)
{
    NSArray *screens = [NSScreen screens];

    if ([screens count] == 0) {
        // You could theoretically get here if running with no monitor, in which case it doesn't matter
        // much where the "on-screen" point is.
        return CGPointMake(point.x, point.y);
    }

    // Flip the y coordinate from the top of the menu bar screen -- see 4636390
    return CGPointMake(point.x, NSMaxY([(NSScreen *)[screens objectAtIndex:0] frame]) - point.y);
}
#endif

#if __MAC_OS_X_VERSION_MIN_REQUIRED >= 1070
static PlatformAnimationController showPopupOrCreateAnimationController(bool createAnimationController, const DictionaryPopupInfo& dictionaryPopupInfo, NSView *view, const WTF::Function<void(TextIndicator&)>& textIndicatorInstallationCallback, const WTF::Function<FloatRect(FloatRect)>& rootViewToViewConversionCallback)
{
    BEGIN_BLOCK_OBJC_EXCEPTIONS;

    if (!getLULookupDefinitionModuleClass())
        return nil;

    RetainPtr<NSMutableDictionary> mutableOptions = adoptNS([(NSDictionary *)dictionaryPopupInfo.options.get() mutableCopy]);

    auto textIndicator = TextIndicator::create(dictionaryPopupInfo.textIndicator);

    if (canLoadLUTermOptionDisableSearchTermIndicator() && textIndicator.get().contentImage()) {
        textIndicatorInstallationCallback(textIndicator.get());
        [mutableOptions setObject:@YES forKey:getLUTermOptionDisableSearchTermIndicator()];

        FloatRect firstTextRectInViewCoordinates = textIndicator.get().textRectsInBoundingRectCoordinates()[0];
        FloatRect textBoundingRectInViewCoordinates = textIndicator.get().textBoundingRectInRootViewCoordinates();
        if (rootViewToViewConversionCallback)
            textBoundingRectInViewCoordinates = rootViewToViewConversionCallback(textBoundingRectInViewCoordinates);
        firstTextRectInViewCoordinates.moveBy(textBoundingRectInViewCoordinates.location());
        if (createAnimationController)
            return [getLULookupDefinitionModuleClass() lookupAnimationControllerForTerm:dictionaryPopupInfo.attributedString.get() relativeToRect:firstTextRectInViewCoordinates ofView:view options:mutableOptions.get()];

        [getLULookupDefinitionModuleClass() showDefinitionForTerm:dictionaryPopupInfo.attributedString.get() relativeToRect:firstTextRectInViewCoordinates ofView:view options:mutableOptions.get()];
        return nil;
    }

    NSPoint textBaselineOrigin = dictionaryPopupInfo.origin;

    // Convert to screen coordinates.
    textBaselineOrigin = [view convertPoint:textBaselineOrigin toView:nil];
    textBaselineOrigin = [view.window convertRectToScreen:NSMakeRect(textBaselineOrigin.x, textBaselineOrigin.y, 0, 0)].origin;

    if (createAnimationController)
        return [getLULookupDefinitionModuleClass() lookupAnimationControllerForTerm:dictionaryPopupInfo.attributedString.get() atLocation:textBaselineOrigin options:mutableOptions.get()];

    [getLULookupDefinitionModuleClass() showDefinitionForTerm:dictionaryPopupInfo.attributedString.get() atLocation:textBaselineOrigin options:mutableOptions.get()];
    return nil;

    END_BLOCK_OBJC_EXCEPTIONS;
    return nil;
}
#endif

void DictionaryLookup::showPopup(const DictionaryPopupInfo& dictionaryPopupInfo, NSView *view, const WTF::Function<void(TextIndicator&)>& textIndicatorInstallationCallback, const WTF::Function<FloatRect(FloatRect)>& rootViewToViewConversionCallback)
{
#if __MAC_OS_X_VERSION_MIN_REQUIRED >= 1070
    showPopupOrCreateAnimationController(false, dictionaryPopupInfo, view, textIndicatorInstallationCallback, rootViewToViewConversionCallback);
#elif __MAC_OS_X_VERSION_MIN_REQUIRED >= 1060
    UNUSED_PARAM(textIndicatorInstallationCallback);
    UNUSED_PARAM(rootViewToViewConversionCallback);
    [view showDefinitionForAttributedString:dictionaryPopupInfo.attributedString.get() atPoint:dictionaryPopupInfo.origin];
#else
    UNUSED_PARAM(textIndicatorInstallationCallback);
    UNUSED_PARAM(rootViewToViewConversionCallback);
    // We soft link to get the function that displays the dictionary (either pop-up window or app) to avoid the performance
    // penalty of linking to another framework. This function changed signature as well as framework between Tiger and Leopard,
    // so the two cases are handled separately.

    typedef void (*ServiceWindowShowFunction)(id unusedDictionaryRef, id inWordString, CFRange selectionRange, id unusedFont, CGPoint textOrigin, Boolean verticalText, id unusedTransform);
    const char *frameworkPath = "/System/Library/Frameworks/Carbon.framework/Frameworks/HIToolbox.framework/HIToolbox";
    const char *functionName = "HIDictionaryWindowShow";
 
    static bool lookedForFunction = false;
    static ServiceWindowShowFunction dictionaryServiceWindowShow = NULL;
 
    if (!lookedForFunction) {
        void* langAnalysisFramework = dlopen(frameworkPath, RTLD_LAZY);
        ASSERT(langAnalysisFramework);
        if (langAnalysisFramework)
            dictionaryServiceWindowShow = (ServiceWindowShowFunction)dlsym(langAnalysisFramework, functionName);
        lookedForFunction = true;
    }

    ASSERT(dictionaryServiceWindowShow);
    if (!dictionaryServiceWindowShow) {
#pragma GCC diagnostic push
#pragma GCC diagnostic ignored "-Wformat-nonliteral"
        NSLog(@"Couldn't find the %s function in %s", functionName, frameworkPath);
#pragma GCC diagnostic pop
        return;
    }

    // The HIDictionaryWindowShow function requires the origin, in CG screen coordinates, of the first character of text in the selection.
    // FIXME 4945808: We approximate this in a way that works well when a single word is selected, and less well in some other cases
    // (but no worse than we did in Tiger)
    NSPoint windowPoint = [view convertPoint:dictionaryPopupInfo.origin toView:nil];
    NSPoint screenPoint = [[view window] convertBaseToScreen:windowPoint];

    dictionaryServiceWindowShow(nil, dictionaryPopupInfo.attributedString.get(), CFRangeMake(0, [dictionaryPopupInfo.attributedString.get() length]), nil,
                                coreGraphicsScreenPointForAppKitScreenPoint(screenPoint), false, nil);
#endif
}

void DictionaryLookup::hidePopup()
{
#if __MAC_OS_X_VERSION_MIN_REQUIRED >= 1070
    BEGIN_BLOCK_OBJC_EXCEPTIONS;

    if (!getLULookupDefinitionModuleClass())
        return;
    [getLULookupDefinitionModuleClass() hideDefinition];

    END_BLOCK_OBJC_EXCEPTIONS;
#endif
}

#if __MAC_OS_X_VERSION_MIN_REQUIRED >= 1070
PlatformAnimationController DictionaryLookup::animationControllerForPopup(const DictionaryPopupInfo& dictionaryPopupInfo, NSView *view, const WTF::Function<void(TextIndicator&)>& textIndicatorInstallationCallback, const WTF::Function<FloatRect(FloatRect)>& rootViewToViewConversionCallback)
{
    return showPopupOrCreateAnimationController(true, dictionaryPopupInfo, view, textIndicatorInstallationCallback, rootViewToViewConversionCallback);
}
#endif

} // namespace WebCore

#endif // PLATFORM(MAC)

