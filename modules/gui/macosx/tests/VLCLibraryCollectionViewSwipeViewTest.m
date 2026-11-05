/*****************************************************************************
 * VLCLibraryCollectionViewSwipeViewTest.m: Collection card swipe tests
 *****************************************************************************
 * Copyright (C) 2026 VLC authors and VideoLAN
 *
 * Authors: Claudio Cambra <developer@claudiocambra.com>
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston MA 02110-1301, USA.
 *****************************************************************************/

#import "VLCAppKitMockingTestCase.h"

#import "library/VLCLibraryCollectionViewSwipeView.h"

@interface VLCSwipeTestEvent : NSEvent
@property BOOL precise;
@property CGFloat horizontal;
@property CGFloat vertical;
@property NSEventPhase scrollPhase;
@property NSEventPhase momentum;
@end

@implementation VLCSwipeTestEvent
- (NSEventType)type { return NSEventTypeScrollWheel; }
- (BOOL)hasPreciseScrollingDeltas { return self.precise; }
- (CGFloat)scrollingDeltaX { return self.horizontal; }
- (CGFloat)scrollingDeltaY { return self.vertical; }
- (NSEventPhase)phase { return self.scrollPhase; }
- (NSEventPhase)momentumPhase { return self.momentum; }
@end

@interface VLCSwipeScrollRecorder : NSResponder
@property (strong) NSMutableArray<NSEvent *> *events;
@end

@implementation VLCSwipeScrollRecorder
- (void)scrollWheel:(NSEvent *)event
{
    [self.events addObject:event];
}
@end

@interface VLCSwipeFocusableButton : NSButton
@end

@implementation VLCSwipeFocusableButton
- (BOOL)acceptsFirstResponder { return !self.refusesFirstResponder; }
@end

@interface VLCLibraryCollectionViewSwipeViewTest : VLCAppKitMockingTestCase
@property NSWindow *window;
@property NSUInteger actionCount;
@property (weak) NSButton *lastActionSender;
@property (weak) VLCLibraryCollectionViewSwipeView *swipeViewToCloseOnAction;
@end

@implementation VLCLibraryCollectionViewSwipeViewTest

- (void)setUp
{
    [super setUp];

    [self replaceClassMethod:@selector(isSwipeTrackingFromScrollEventsEnabled)
                     onClass:NSEvent.class
                   withBlock:^BOOL(id __unused cls) { return YES; }];
}

- (void)tearDown
{
    [self.window close];
    self.window = nil;
    [super tearDown];
}

- (VLCLibraryCollectionViewSwipeView *)swipeViewWithSize:(NSSize)size
{
    NSView * const content = [[NSView alloc] initWithFrame:(NSRect){ NSZeroPoint, size }];
    VLCLibraryCollectionViewSwipeView * const view =
        [[VLCLibraryCollectionViewSwipeView alloc] initWithContentView:content];
    view.frame = (NSRect){ NSZeroPoint, size };
    view.userInterfaceLayoutDirection = NSUserInterfaceLayoutDirectionLeftToRight;
    [view layoutSubtreeIfNeeded];
    return view;
}

- (NSButton *)buttonWithTitle:(NSString *)title
{
    return [NSButton buttonWithTitle:title target:self action:@selector(recordAction:)];
}

- (void)recordAction:(NSButton *)sender
{
    self.actionCount++;
    self.lastActionSender = sender;
    [self.swipeViewToCloseOnAction closeActionsAnimated:NO];
}

- (void)hostView:(NSView *)view
{
    self.window = [[NSWindow alloc] initWithContentRect:NSMakeRect(0., 0., 480., 300.)
                                              styleMask:NSWindowStyleMaskBorderless
                                                backing:NSBackingStoreBuffered
                                                  defer:NO];
    self.window.releasedWhenClosed = NO;
    self.window.contentView = view;
    [view layoutSubtreeIfNeeded];
}

- (VLCSwipeTestEvent *)eventWithHorizontal:(CGFloat)horizontal
                                  vertical:(CGFloat)vertical
                                     phase:(NSEventPhase)phase
{
    VLCSwipeTestEvent * const event = VLCSwipeTestEvent.new;
    event.precise = YES;
    event.horizontal = horizontal;
    event.vertical = vertical;
    event.scrollPhase = phase;
    return event;
}

- (void)scrollHorizontally:(CGFloat)delta
                     phase:(NSEventPhase)phase
                    inView:(VLCLibraryCollectionViewSwipeView *)view
{
    [view scrollWheel:[self eventWithHorizontal:delta vertical:0. phase:phase]];
}

- (void)openActionsOnEdge:(NSRectEdge)edge inView:(VLCLibraryCollectionViewSwipeView *)view
{
    const CGFloat direction = edge == NSMinXEdge ? 1. : -1.;
    [self scrollHorizontally:direction * 8. phase:NSEventPhaseBegan inView:view];
    [self scrollHorizontally:direction * 72. phase:NSEventPhaseChanged inView:view];
    [self scrollHorizontally:0. phase:NSEventPhaseEnded inView:view];
}

- (void)assertButton:(NSButton *)button
         isExposedIn:(VLCLibraryCollectionViewSwipeView *)view
{
    NSRect const frame = [button convertRect:button.bounds toView:view];
    XCTAssertTrue(NSContainsRect(view.bounds, frame));
    XCTAssertFalse(button.hiddenOrHasHiddenAncestor);
    NSPoint const center = NSMakePoint(NSMidX(frame), NSMidY(frame));
    NSView * const hit = [view hitTest:center];
    XCTAssertTrue(hit == button || [hit isDescendantOf:button]);
}

- (void)testLeadingAndTrailingRevealPreserveCardSizeAndRestoreItsLayout
{
    VLCLibraryCollectionViewSwipeView * const view = [self swipeViewWithSize:NSMakeSize(240., 160.)];
    NSView * const originalContent = view.contentView;
    NSRect const originalFrame = originalContent.frame;
    NSTextField * const title = [NSTextField labelWithString:@"Card title"];
    title.translatesAutoresizingMaskIntoConstraints = NO;
    [originalContent addSubview:title];
    [NSLayoutConstraint activateConstraints:@[
        [title.centerXAnchor constraintEqualToAnchor:originalContent.centerXAnchor],
        [title.centerYAnchor constraintEqualToAnchor:originalContent.centerYAnchor],
    ]];
    NSButton * const queue = [self buttonWithTitle:@"Queue"];
    NSButton * const favorite = [self buttonWithTitle:@"Favorite"];
    NSButton * const secondaryAction = [self buttonWithTitle:@"Add to Playlist"];
    [view setLeadingButtons:@[queue] trailingButtons:@[favorite, secondaryAction]];

    [self openActionsOnEdge:NSMinXEdge inView:view];
    [view layoutSubtreeIfNeeded];
    XCTAssertTrue(view.actionsVisible);
    XCTAssertEqual(view.contentView, originalContent);
    XCTAssertTrue(NSEqualSizes(originalContent.frame.size, originalFrame.size));
    XCTAssertGreaterThan(NSMinX(originalContent.frame), NSMinX(view.bounds));
    [self assertButton:queue isExposedIn:view];
    XCTAssertEqualWithAccuracy(NSMidX(title.frame), NSMidX(originalContent.bounds), .5);

    [view closeActionsAnimated:NO];
    [self openActionsOnEdge:NSMaxXEdge inView:view];
    [view layoutSubtreeIfNeeded];
    XCTAssertTrue(view.actionsVisible);
    XCTAssertTrue(NSEqualSizes(originalContent.frame.size, originalFrame.size));
    XCTAssertLessThan(NSMinX(originalContent.frame), NSMinX(view.bounds));
    [self assertButton:favorite isExposedIn:view];
    [self assertButton:secondaryAction isExposedIn:view];

    [view closeActionsAnimated:NO];
    [view layoutSubtreeIfNeeded];
    XCTAssertFalse(view.actionsVisible);
    XCTAssertTrue(NSEqualRects(originalContent.frame, originalFrame));
    XCTAssertEqual(self.actionCount, (NSUInteger)0);
}

- (void)testMissingActionsCannotOpenThatEdge
{
    VLCLibraryCollectionViewSwipeView * const view = [self swipeViewWithSize:NSMakeSize(240., 160.)];
    [self openActionsOnEdge:NSMaxXEdge inView:view];
    XCTAssertFalse(view.actionsVisible);
    [view setLeadingButtons:@[[self buttonWithTitle:@"Queue"]] trailingButtons:@[]];
    [self openActionsOnEdge:NSMaxXEdge inView:view];
    XCTAssertFalse(view.actionsVisible);
    XCTAssertTrue(NSEqualRects(view.contentView.frame, view.bounds));
    [self openActionsOnEdge:NSMinXEdge inView:view];
    XCTAssertTrue(view.actionsVisible);
}

- (void)testOnlyOneCardCanStayOpenInEachCollection
{
    NSCollectionView * const firstCollection = NSCollectionView.new;
    NSCollectionView * const secondCollection = NSCollectionView.new;
    VLCLibraryCollectionViewSwipeView * const first = [self swipeViewWithSize:NSMakeSize(240., 160.)];
    VLCLibraryCollectionViewSwipeView * const sibling = [self swipeViewWithSize:NSMakeSize(240., 160.)];
    VLCLibraryCollectionViewSwipeView * const separate = [self swipeViewWithSize:NSMakeSize(240., 160.)];
    first.collectionView = firstCollection;
    sibling.collectionView = firstCollection;
    separate.collectionView = secondCollection;
    for (VLCLibraryCollectionViewSwipeView *view in @[first, sibling, separate]) {
        [view setLeadingButtons:@[] trailingButtons:@[[self buttonWithTitle:@"Favorite"]]];
    }

    [self openActionsOnEdge:NSMaxXEdge inView:first];
    [self openActionsOnEdge:NSMaxXEdge inView:separate];
    XCTAssertTrue(first.actionsVisible);
    XCTAssertTrue(separate.actionsVisible);
    [self openActionsOnEdge:NSMaxXEdge inView:sibling];
    XCTAssertFalse(first.actionsVisible);
    XCTAssertTrue(sibling.actionsVisible);
    XCTAssertTrue(separate.actionsVisible);

    XCTAssertTrue([VLCLibraryCollectionViewSwipeView closeActionsInCollectionView:firstCollection]);
    XCTAssertFalse(sibling.actionsVisible);
    XCTAssertTrue(separate.actionsVisible);
}

- (void)testClosingAnEmptyCollectionOrNilIsANoOp
{
    XCTAssertFalse([VLCLibraryCollectionViewSwipeView closeActionsInCollectionView:nil]);
    XCTAssertFalse([VLCLibraryCollectionViewSwipeView closeActionsInCollectionView:NSCollectionView.new]);
}

- (void)testRightToLeftLayoutMapsLogicalActionsToTheirPhysicalEdges
{
    VLCLibraryCollectionViewSwipeView * const view = [self swipeViewWithSize:NSMakeSize(240., 160.)];
    view.userInterfaceLayoutDirection = NSUserInterfaceLayoutDirectionRightToLeft;
    NSButton * const queue = [self buttonWithTitle:@"Queue"];
    NSButton * const favorite = [self buttonWithTitle:@"Favorite"];
    [view setLeadingButtons:@[queue] trailingButtons:@[favorite]];

    [self openActionsOnEdge:NSMinXEdge inView:view];
    [view layoutSubtreeIfNeeded];
    XCTAssertGreaterThan(NSMinX(view.contentView.frame), NSMinX(view.bounds));
    [self assertButton:favorite isExposedIn:view];
    [view closeActionsAnimated:NO];
    [self openActionsOnEdge:NSMaxXEdge inView:view];
    [view layoutSubtreeIfNeeded];
    XCTAssertLessThan(NSMinX(view.contentView.frame), NSMinX(view.bounds));
    [self assertButton:queue isExposedIn:view];
}

- (void)testActionsAreRefreshedBeforeEachReveal
{
    VLCLibraryCollectionViewSwipeView * const view = [self swipeViewWithSize:NSMakeSize(240., 160.)];
    NSButton * const button = [self buttonWithTitle:@"Add to Playlist"];
    __block NSUInteger refreshCount = 0;
    __weak VLCLibraryCollectionViewSwipeView * const weakView = view;
    view.willRevealActions = ^{
        NSArray<NSButton *> * const buttons = ++refreshCount == 1 ? @[button] : @[];
        [weakView setLeadingButtons:@[] trailingButtons:buttons];
    };

    [self openActionsOnEdge:NSMaxXEdge inView:view];
    XCTAssertTrue(view.actionsVisible);
    XCTAssertEqual(refreshCount, (NSUInteger)1);
    [view closeActionsAnimated:NO];
    [self openActionsOnEdge:NSMaxXEdge inView:view];
    XCTAssertFalse(view.actionsVisible);
    XCTAssertEqual(refreshCount, (NSUInteger)2);
    XCTAssertEqual(self.actionCount, (NSUInteger)0);
}

- (void)testChangingActionsOrCollectionClosesThePreviousPresentation
{
    VLCLibraryCollectionViewSwipeView * const view = [self swipeViewWithSize:NSMakeSize(240., 160.)];
    NSCollectionView * const firstCollection = NSCollectionView.new;
    NSCollectionView * const secondCollection = NSCollectionView.new;
    view.collectionView = firstCollection;
    [view setLeadingButtons:@[] trailingButtons:@[[self buttonWithTitle:@"Favorite"]]];
    [self openActionsOnEdge:NSMaxXEdge inView:view];
    XCTAssertTrue(view.actionsVisible);

    [view setLeadingButtons:@[] trailingButtons:@[[self buttonWithTitle:@"Show Information"]]];
    [view layoutSubtreeIfNeeded];
    XCTAssertFalse(view.actionsVisible);
    XCTAssertTrue(NSEqualRects(view.contentView.frame, view.bounds));
    [self openActionsOnEdge:NSMaxXEdge inView:view];
    view.collectionView = secondCollection;
    XCTAssertFalse(view.actionsVisible);

    [self openActionsOnEdge:NSMaxXEdge inView:view];
    [VLCLibraryCollectionViewSwipeView closeActionsInCollectionView:firstCollection];
    XCTAssertTrue(view.actionsVisible);
    [VLCLibraryCollectionViewSwipeView closeActionsInCollectionView:secondCollection];
    XCTAssertFalse(view.actionsVisible);
}

- (void)testRevealAndCloseDoNotExecuteActionsButAnExposedButtonDoes
{
    VLCLibraryCollectionViewSwipeView * const view = [self swipeViewWithSize:NSMakeSize(240., 160.)];
    NSButton * const button = [self buttonWithTitle:@"Add to Playlist"];
    [view setLeadingButtons:@[] trailingButtons:@[button]];
    [self openActionsOnEdge:NSMaxXEdge inView:view];
    [view layoutSubtreeIfNeeded];
    [self assertButton:button isExposedIn:view];
    XCTAssertEqual(self.actionCount, (NSUInteger)0);
    [button performClick:nil];
    XCTAssertEqual(self.actionCount, (NSUInteger)1);
    XCTAssertEqual(self.lastActionSender, button);
    [view closeActionsAnimated:NO];
    XCTAssertEqual(self.actionCount, (NSUInteger)1);
}

- (void)testClosedAndOccludedActionsAreUnavailableToAccessibilityAndKeyboard
{
    NSView * const host = [[NSView alloc] initWithFrame:NSMakeRect(0., 0., 480., 300.)];
    [self hostView:host];
    self.window.styleMask |= NSWindowStyleMaskTitled;
    VLCLibraryCollectionViewSwipeView * const view = [self swipeViewWithSize:NSMakeSize(240., 160.)];
    [host addSubview:view];
    NSButton * const inner = [VLCSwipeFocusableButton buttonWithTitle:@"Favorite"
                                                               target:self
                                                               action:@selector(recordAction:)];
    NSButton * const outer = [VLCSwipeFocusableButton buttonWithTitle:@"Add to Playlist"
                                                               target:self
                                                               action:@selector(recordAction:)];
    [view setLeadingButtons:@[] trailingButtons:@[inner, outer]];

    [self openActionsOnEdge:NSMaxXEdge inView:view];
    [self assertButton:inner isExposedIn:view];
    [self assertButton:outer isExposedIn:view];
    XCTAssertEqual(view.accessibilityChildren.count, (NSUInteger)2);
    XCTAssertTrue(inner.canBecomeKeyView);
    XCTAssertTrue(outer.canBecomeKeyView);

    [view closeActionsAnimated:NO];
    XCTAssertEqual(view.accessibilityChildren.count, (NSUInteger)0);
    XCTAssertTrue(inner.hiddenOrHasHiddenAncestor);
    XCTAssertTrue(outer.hiddenOrHasHiddenAncestor);
    XCTAssertFalse(inner.canBecomeKeyView);
    XCTAssertFalse(outer.canBecomeKeyView);

    [self scrollHorizontally:-12. phase:NSEventPhaseBegan inView:view];
    XCTAssertEqual(view.accessibilityChildren.count, (NSUInteger)1);
    XCTAssertTrue(inner.hiddenOrHasHiddenAncestor);
    XCTAssertFalse(inner.canBecomeKeyView);
    XCTAssertFalse(outer.hiddenOrHasHiddenAncestor);
    XCTAssertTrue(outer.canBecomeKeyView);
    [self scrollHorizontally:0. phase:NSEventPhaseCancelled inView:view];
    [view closeActionsAnimated:NO];
    XCTAssertEqual(view.accessibilityChildren.count, (NSUInteger)0);
    XCTAssertEqual(self.actionCount, (NSUInteger)0);
}

- (void)testResizingClosesActionsAndResizesContentToTheNewCardBounds
{
    VLCLibraryCollectionViewSwipeView * const view = [self swipeViewWithSize:NSMakeSize(240., 160.)];
    [view setLeadingButtons:@[] trailingButtons:@[[self buttonWithTitle:@"Favorite"]]];
    [self openActionsOnEdge:NSMaxXEdge inView:view];
    XCTAssertTrue(view.actionsVisible);
    view.frame = NSMakeRect(0., 0., 180., 120.);
    [view layoutSubtreeIfNeeded];
    XCTAssertFalse(view.actionsVisible);
    XCTAssertTrue(NSEqualRects(view.contentView.frame, view.bounds));
}

- (void)testDetachingTheCardFromItsWindowClosesActions
{
    NSView * const host = [[NSView alloc] initWithFrame:NSMakeRect(0., 0., 480., 300.)];
    [self hostView:host];
    VLCLibraryCollectionViewSwipeView * const view = [self swipeViewWithSize:NSMakeSize(240., 160.)];
    [host addSubview:view];
    [view setLeadingButtons:@[] trailingButtons:@[[self buttonWithTitle:@"Favorite"]]];
    [self openActionsOnEdge:NSMaxXEdge inView:view];
    XCTAssertNotNil(view.window);
    XCTAssertTrue(view.actionsVisible);
    [view removeFromSuperview];
    XCTAssertNil(view.window);
    XCTAssertFalse(view.actionsVisible);
}

- (void)testScrollingTheEnclosingClipViewClosesActions
{
    NSScrollView * const scrollView = [[NSScrollView alloc] initWithFrame:NSMakeRect(0., 0., 480., 300.)];
    NSView * const document = [[NSView alloc] initWithFrame:NSMakeRect(0., 0., 480., 900.)];
    scrollView.documentView = document;
    VLCLibraryCollectionViewSwipeView * const view = [self swipeViewWithSize:NSMakeSize(240., 160.)];
    [document addSubview:view];
    [self hostView:scrollView];
    [view setLeadingButtons:@[] trailingButtons:@[[self buttonWithTitle:@"Favorite"]]];
    [self openActionsOnEdge:NSMaxXEdge inView:view];
    XCTAssertTrue(view.actionsVisible);
    [scrollView.contentView scrollToPoint:NSMakePoint(0., 60.)];
    [scrollView reflectScrolledClipView:scrollView.contentView];
    XCTAssertFalse(view.actionsVisible);
}

- (void)testHorizontalGestureCompletesItsRevealAndCancellationRestoresTheCard
{
    VLCLibraryCollectionViewSwipeView * const view = [self swipeViewWithSize:NSMakeSize(240., 160.)];
    [view setLeadingButtons:@[[self buttonWithTitle:@"Queue"]] trailingButtons:@[[self buttonWithTitle:@"Favorite"]]];
    [self scrollHorizontally:8. phase:NSEventPhaseBegan inView:view];
    [self scrollHorizontally:32. phase:NSEventPhaseChanged inView:view];
    XCTAssertEqualWithAccuracy(NSMinX(view.contentView.frame), 40., .5);
    [self scrollHorizontally:0. phase:NSEventPhaseEnded inView:view];
    XCTAssertTrue(view.actionsVisible);
    CGFloat const openOffset = NSMinX(view.contentView.frame);
    XCTAssertGreaterThan(openOffset, 40.);

    [self scrollHorizontally:12. phase:NSEventPhaseBegan inView:view];
    XCTAssertEqualWithAccuracy(NSMinX(view.contentView.frame), openOffset + 12., .5);
    [self scrollHorizontally:-9. phase:NSEventPhaseChanged inView:view];
    XCTAssertEqualWithAccuracy(NSMinX(view.contentView.frame), openOffset + 3., .5);
    [self scrollHorizontally:0. phase:NSEventPhaseCancelled inView:view];
    XCTAssertEqualWithAccuracy(NSMinX(view.contentView.frame), openOffset, .5);

    [view closeActionsAnimated:NO];
    [self scrollHorizontally:-18. phase:NSEventPhaseBegan inView:view];
    XCTAssertEqualWithAccuracy(NSMinX(view.contentView.frame), -18., .5);
    [self scrollHorizontally:0. phase:NSEventPhaseCancelled inView:view];
    XCTAssertFalse(view.actionsVisible);
    XCTAssertTrue(NSEqualRects(view.contentView.frame, view.bounds));
    XCTAssertEqual(self.actionCount, (NSUInteger)0);
}

- (void)testReverseSwipeTracksDistanceAndSettlesOnBothSides
{
    VLCLibraryCollectionViewSwipeView * const view = [self swipeViewWithSize:NSMakeSize(240., 160.)];
    [view setLeadingButtons:@[[self buttonWithTitle:@"Queue"]] trailingButtons:@[[self buttonWithTitle:@"Favorite"]]];

    for (NSNumber * const edge in @[@(NSMinXEdge), @(NSMaxXEdge)]) {
        [self openActionsOnEdge:edge.unsignedIntegerValue inView:view];
        CGFloat const openOffset = NSMinX(view.contentView.frame);
        CGFloat const direction = openOffset > 0. ? -1. : 1.;
        XCTAssertTrue(view.actionsVisible);

        [self scrollHorizontally:direction * 3. phase:NSEventPhaseBegan inView:view];
        XCTAssertEqualWithAccuracy(NSMinX(view.contentView.frame), openOffset, .5);
        [self scrollHorizontally:direction * 5. phase:NSEventPhaseChanged inView:view];
        XCTAssertEqualWithAccuracy(NSMinX(view.contentView.frame), openOffset + direction * 8., .5);
        [self scrollHorizontally:direction * 7. phase:NSEventPhaseChanged inView:view];
        XCTAssertEqualWithAccuracy(NSMinX(view.contentView.frame), openOffset + direction * 15., .5);
        [self scrollHorizontally:0. phase:NSEventPhaseEnded inView:view];
        XCTAssertEqualWithAccuracy(NSMinX(view.contentView.frame), openOffset, .5);

        [self scrollHorizontally:0. phase:NSEventPhaseBegan inView:view];
        [self scrollHorizontally:-openOffset * .75 phase:NSEventPhaseChanged inView:view];
        XCTAssertTrue(view.actionsVisible);
        XCTAssertEqualWithAccuracy(NSMinX(view.contentView.frame), openOffset * .25, .5);
        [self scrollHorizontally:0. phase:NSEventPhaseEnded inView:view];
        XCTAssertFalse(view.actionsVisible);
        XCTAssertTrue(NSEqualRects(view.contentView.frame, view.bounds));
    }
    XCTAssertEqual(self.actionCount, (NSUInteger)0);
}

- (void)testFullSwipeExpandsAndActivatesTheOutermostButtonOnceOnEachEdge
{
    NSArray<NSNumber *> * const directions = @[@(NSUserInterfaceLayoutDirectionLeftToRight),
                                               @(NSUserInterfaceLayoutDirectionRightToLeft)];
    for (NSNumber * const direction in directions) {
        VLCLibraryCollectionViewSwipeView * const view = [self swipeViewWithSize:NSMakeSize(240., 160.)];
        view.userInterfaceLayoutDirection = (NSUserInterfaceLayoutDirection)direction.integerValue;
        NSArray<NSButton *> * const leading = @[[self buttonWithTitle:@"Queue"], [self buttonWithTitle:@"Play"]];
        NSArray<NSButton *> * const trailing = @[[self buttonWithTitle:@"Favorite"], [self buttonWithTitle:@"Add to Playlist"]];
        [view setLeadingButtons:leading trailingButtons:trailing];
        CGFloat const cardWidth = NSWidth(view.bounds);
        CGFloat const centerY = NSMidY(view.bounds);

        for (NSNumber * const edgeValue in @[@(NSMinXEdge), @(NSMaxXEdge)]) {
            const NSRectEdge edge = edgeValue.unsignedIntegerValue;
            const BOOL leftEdge = edge == NSMinXEdge;
            const CGFloat sign = leftEdge ? 1. : -1.;
            [view closeActionsAnimated:NO];
            [self openActionsOnEdge:edge inView:view];
            CGFloat const normalWidth = fabs(NSMinX(view.contentView.frame));
            CGFloat const outerX = leftEdge ? 8. : cardWidth - 8.;
            CGFloat const innerX = leftEdge ? normalWidth - 8. : cardWidth - normalWidth + 8.;
            NSView * const outer = [view hitTest:NSMakePoint(outerX, centerY)];
            NSView * const inner = [view hitTest:NSMakePoint(innerX, centerY)];
            XCTAssertTrue([outer isKindOfClass:NSButton.class]);
            XCTAssertTrue([inner isKindOfClass:NSButton.class]);
            XCTAssertNotEqual(outer, inner);
            CGFloat const normalButtonWidth = NSWidth(outer.frame);
            CGFloat const threshold = (normalWidth + cardWidth) / 2.;
            NSUInteger const previousCount = self.actionCount;
            [view closeActionsAnimated:NO];

            [self scrollHorizontally:sign * (threshold - 2.) phase:NSEventPhaseBegan inView:view];
            XCTAssertGreaterThan(NSWidth(outer.frame), normalButtonWidth);
            XCTAssertGreaterThan(NSWidth(inner.frame), 0.);
            [self scrollHorizontally:sign * 2. phase:NSEventPhaseChanged inView:view];
            XCTAssertEqualWithAccuracy(NSWidth(outer.frame), threshold, .5);
            XCTAssertEqualWithAccuracy(NSWidth(inner.frame), 0., .5);
            XCTAssertTrue(inner.hiddenOrHasHiddenAncestor);
            XCTAssertEqual(self.actionCount, previousCount);
            [self scrollHorizontally:0. phase:NSEventPhaseEnded inView:view];
            XCTAssertEqual(self.actionCount, previousCount + 1);
            XCTAssertEqual(self.lastActionSender, (NSButton *)outer);
            XCTAssertEqualWithAccuracy(NSMinX(view.contentView.frame), sign * normalWidth, .5);

            [self scrollHorizontally:0. phase:NSEventPhaseEnded inView:view];
            VLCSwipeTestEvent * const momentum = [self eventWithHorizontal:sign * cardWidth
                                                                  vertical:0.
                                                                     phase:NSEventPhaseNone];
            momentum.momentum = NSEventPhaseChanged;
            [view scrollWheel:momentum];
            XCTAssertEqual(self.actionCount, previousCount + 1);
        }
    }
}

- (void)testFullSwipeDoesNotActivateAfterRetreatCancellationReverseOrMomentum
{
    VLCLibraryCollectionViewSwipeView * const view = [self swipeViewWithSize:NSMakeSize(240., 160.)];
    [view setLeadingButtons:@[] trailingButtons:@[[self buttonWithTitle:@"Add to Playlist"]]];
    [self openActionsOnEdge:NSMaxXEdge inView:view];
    CGFloat const normalOffset = NSMinX(view.contentView.frame);
    CGFloat const cardWidth = NSWidth(view.bounds);
    CGFloat const threshold = (fabs(normalOffset) + cardWidth) / 2.;
    [view closeActionsAnimated:NO];

    [self scrollHorizontally:-(threshold + 2.) phase:NSEventPhaseBegan inView:view];
    [self scrollHorizontally:4. phase:NSEventPhaseChanged inView:view];
    [self scrollHorizontally:0. phase:NSEventPhaseEnded inView:view];
    XCTAssertEqual(self.actionCount, (NSUInteger)0);
    XCTAssertEqualWithAccuracy(NSMinX(view.contentView.frame), normalOffset, .5);

    [view closeActionsAnimated:NO];
    [self scrollHorizontally:-cardWidth phase:NSEventPhaseBegan inView:view];
    [self scrollHorizontally:0. phase:NSEventPhaseCancelled inView:view];
    XCTAssertEqual(self.actionCount, (NSUInteger)0);
    XCTAssertFalse(view.actionsVisible);

    [self openActionsOnEdge:NSMaxXEdge inView:view];
    [self scrollHorizontally:cardWidth phase:NSEventPhaseBegan inView:view];
    [self scrollHorizontally:-cardWidth phase:NSEventPhaseChanged inView:view];
    [self scrollHorizontally:0. phase:NSEventPhaseEnded inView:view];
    XCTAssertEqual(self.actionCount, (NSUInteger)0);
    XCTAssertEqualWithAccuracy(NSMinX(view.contentView.frame), normalOffset, .5);

    [self scrollHorizontally:cardWidth phase:NSEventPhaseBegan inView:view];
    [self scrollHorizontally:0. phase:NSEventPhaseEnded inView:view];
    XCTAssertFalse(view.actionsVisible);

    [self scrollHorizontally:-(threshold - 2.) phase:NSEventPhaseBegan inView:view];
    VLCSwipeTestEvent * const momentum = [self eventWithHorizontal:-cardWidth
                                                          vertical:0.
                                                             phase:NSEventPhaseNone];
    momentum.momentum = NSEventPhaseChanged;
    [view scrollWheel:momentum];
    XCTAssertEqualWithAccuracy(NSMinX(view.contentView.frame), -(threshold - 2.), .5);
    [self scrollHorizontally:0. phase:NSEventPhaseEnded inView:view];
    XCTAssertEqual(self.actionCount, (NSUInteger)0);
    XCTAssertEqualWithAccuracy(NSMinX(view.contentView.frame), normalOffset, .5);
}

- (void)testFullSwipeHonorsDisabledActionsAndHandlersThatCloseTheDrawer
{
    VLCLibraryCollectionViewSwipeView * const view = [self swipeViewWithSize:NSMakeSize(240., 160.)];
    NSButton * const favorite = [self buttonWithTitle:@"Favorite"];
    NSButton * const secondaryAction = [self buttonWithTitle:@"Add to Playlist"];
    [view setLeadingButtons:@[] trailingButtons:@[favorite, secondaryAction]];
    CGFloat const cardWidth = NSWidth(view.bounds);

    secondaryAction.enabled = NO;
    [self scrollHorizontally:-cardWidth phase:NSEventPhaseBegan inView:view];
    [self scrollHorizontally:0. phase:NSEventPhaseEnded inView:view];
    XCTAssertEqual(self.actionCount, (NSUInteger)0);
    [view closeActionsAnimated:NO];

    secondaryAction.enabled = YES;
    [self scrollHorizontally:-cardWidth phase:NSEventPhaseBegan inView:view];
    secondaryAction.enabled = NO;
    [self scrollHorizontally:0. phase:NSEventPhaseEnded inView:view];
    XCTAssertEqual(self.actionCount, (NSUInteger)0);
    [view closeActionsAnimated:NO];

    secondaryAction.enabled = YES;
    self.swipeViewToCloseOnAction = view;
    [self scrollHorizontally:-cardWidth phase:NSEventPhaseBegan inView:view];
    [self scrollHorizontally:0. phase:NSEventPhaseEnded inView:view];
    XCTAssertEqual(self.actionCount, (NSUInteger)1);
    XCTAssertEqual(self.lastActionSender, secondaryAction);
    XCTAssertFalse(view.actionsVisible);
    XCTAssertTrue(NSEqualRects(view.contentView.frame, view.bounds));
}

- (void)testRebindingAndResizeIgnoreTheRemainingEventsOfAGesture
{
    VLCLibraryCollectionViewSwipeView * const view = [self swipeViewWithSize:NSMakeSize(240., 160.)];
    [view setLeadingButtons:@[] trailingButtons:@[[self buttonWithTitle:@"Favorite"]]];
    [self scrollHorizontally:-12. phase:NSEventPhaseBegan inView:view];
    XCTAssertTrue(view.actionsVisible);
    [view setLeadingButtons:@[] trailingButtons:@[[self buttonWithTitle:@"Add to Playlist"]]];
    XCTAssertFalse(view.actionsVisible);

    [self scrollHorizontally:-18. phase:NSEventPhaseChanged inView:view];
    XCTAssertFalse(view.actionsVisible);
    [self scrollHorizontally:-12. phase:NSEventPhaseBegan inView:view];
    XCTAssertTrue(view.actionsVisible);

    view.frame = NSMakeRect(0., 0., 180., 120.);
    [self scrollHorizontally:-18. phase:NSEventPhaseChanged inView:view];
    [view layoutSubtreeIfNeeded];
    XCTAssertFalse(view.actionsVisible);
    [self scrollHorizontally:-18. phase:NSEventPhaseChanged inView:view];
    XCTAssertFalse(view.actionsVisible);
    XCTAssertTrue(NSEqualRects(view.contentView.frame, view.bounds));
    [self scrollHorizontally:-12. phase:NSEventPhaseBegan inView:view];
    XCTAssertEqualWithAccuracy(NSMinX(view.contentView.frame), -12., .5);
    [self scrollHorizontally:0. phase:NSEventPhaseCancelled inView:view];
    XCTAssertFalse(view.actionsVisible);
    XCTAssertEqual(self.actionCount, (NSUInteger)0);
}

- (void)testUndecidedScrollForwardsAfterAtMostEightBufferedSamples
{
    VLCLibraryCollectionViewSwipeView * const view = [self swipeViewWithSize:NSMakeSize(240., 160.)];
    [view setLeadingButtons:@[] trailingButtons:@[[self buttonWithTitle:@"Favorite"]]];
    VLCSwipeScrollRecorder * const recorder = VLCSwipeScrollRecorder.new;
    recorder.events = NSMutableArray.array;
    view.nextResponder = recorder;

    const NSUInteger maximumBufferedSamples = 8;
    NSMutableArray<NSEvent *> * const samples = NSMutableArray.array;
    for (NSUInteger i = 0; i <= maximumBufferedSamples; i++) {
        const NSEventPhase phase = i == 0 ? NSEventPhaseBegan : NSEventPhaseChanged;
        NSEvent * const sample = [self eventWithHorizontal:-.25 vertical:(i + 1) * .02 phase:phase];
        [samples addObject:sample];
        [view scrollWheel:sample];
    }
    XCTAssertEqualObjects(recorder.events, samples);

    NSEvent * const horizontal = [self eventWithHorizontal:-240. vertical:0. phase:NSEventPhaseChanged];
    NSEvent * const ended = [self eventWithHorizontal:0. vertical:0. phase:NSEventPhaseEnded];
    [view scrollWheel:horizontal];
    [view scrollWheel:ended];
    [samples addObjectsFromArray:@[horizontal, ended]];
    XCTAssertEqualObjects(recorder.events, samples);
    XCTAssertFalse(view.actionsVisible);
    XCTAssertEqual(self.actionCount, (NSUInteger)0);
}

- (void)testRebindingBeforeSwipeOwnershipPreservesVerticalScroll
{
    VLCLibraryCollectionViewSwipeView * const view = [self swipeViewWithSize:NSMakeSize(240., 160.)];
    [view setLeadingButtons:@[] trailingButtons:@[[self buttonWithTitle:@"Favorite"]]];
    VLCSwipeScrollRecorder * const recorder = VLCSwipeScrollRecorder.new;
    recorder.events = NSMutableArray.array;
    view.nextResponder = recorder;

    NSEvent * const began = [self eventWithHorizontal:-1. vertical:1. phase:NSEventPhaseBegan];
    [view scrollWheel:began];
    XCTAssertEqual(recorder.events.count, (NSUInteger)0);
    [view setLeadingButtons:@[] trailingButtons:@[[self buttonWithTitle:@"Add to Playlist"]]];

    NSEvent * const changed = [self eventWithHorizontal:0. vertical:8. phase:NSEventPhaseChanged];
    NSEvent * const ended = [self eventWithHorizontal:0. vertical:0. phase:NSEventPhaseEnded];
    VLCSwipeTestEvent * const momentum = [self eventWithHorizontal:0. vertical:3. phase:NSEventPhaseNone];
    momentum.momentum = NSEventPhaseChanged;
    [view scrollWheel:changed];
    [view scrollWheel:ended];
    [view scrollWheel:momentum];
    NSArray<NSEvent *> * const expected = @[began, changed, ended, momentum];
    XCTAssertEqualObjects(recorder.events, expected);
    XCTAssertFalse(view.actionsVisible);
    XCTAssertEqual(self.actionCount, (NSUInteger)0);
}

- (void)testVerticalMouseWheelAndMomentumEventsAreForwardedUnchanged
{
    VLCLibraryCollectionViewSwipeView * const view = [self swipeViewWithSize:NSMakeSize(240., 160.)];
    [view setLeadingButtons:@[] trailingButtons:@[[self buttonWithTitle:@"Favorite"]]];
    VLCSwipeScrollRecorder * const recorder = VLCSwipeScrollRecorder.new;
    recorder.events = NSMutableArray.array;
    view.nextResponder = recorder;
    [self openActionsOnEdge:NSMaxXEdge inView:view];
    VLCSwipeTestEvent * const vertical = [self eventWithHorizontal:0. vertical:6. phase:NSEventPhaseBegan];
    [view scrollWheel:vertical];
    XCTAssertFalse(view.actionsVisible);
    VLCSwipeTestEvent * const wheel = [self eventWithHorizontal:-6. vertical:0. phase:NSEventPhaseNone];
    wheel.precise = NO;
    [view scrollWheel:wheel];
    VLCSwipeTestEvent * const momentum = [self eventWithHorizontal:-6. vertical:0. phase:NSEventPhaseNone];
    momentum.momentum = NSEventPhaseChanged;
    [view scrollWheel:momentum];
    XCTAssertEqual(recorder.events.count, (NSUInteger)3);
    XCTAssertEqual(recorder.events[0], vertical);
    XCTAssertEqual(recorder.events[1], wheel);
    XCTAssertEqual(recorder.events[2], momentum);
    XCTAssertFalse(view.actionsVisible);
}

@end
