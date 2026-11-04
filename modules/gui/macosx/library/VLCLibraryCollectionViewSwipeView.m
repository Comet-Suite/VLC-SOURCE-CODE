/*****************************************************************************
 * VLCLibraryCollectionViewSwipeView.m: MacOS X interface module
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
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston MA 02110-1301, USA.
 *****************************************************************************/

#import "VLCLibraryCollectionViewSwipeView.h"

#import <QuartzCore/QuartzCore.h>

static const CGFloat VLCCollectionSwipeButtonWidth = 68.;
static const CGFloat VLCCollectionSwipeDrawerWidthLimitFraction = 0.8;
static const CGFloat VLCCollectionSwipeOffsetTolerance = 0.5;

static const CGFloat VLCCollectionSwipeIntentDistance = 4.;
static const CGFloat VLCCollectionSwipeMinimumHorizontalRatio = 1.5;
static const NSUInteger VLCCollectionSwipePendingEventLimit = 8;
static const CGFloat VLCCollectionSwipeSettleProgressThreshold = 0.5;
static const NSTimeInterval VLCCollectionSwipeSettleDuration = 0.18;

typedef NS_ENUM(NSUInteger, VLCCollectionScrollState) {
    VLCCollectionScrollUndecided,
    VLCCollectionScrollForwarding,
    VLCCollectionScrollSwiping,
    VLCCollectionScrollConsumed,
};

static NSMapTable<NSCollectionView *, VLCLibraryCollectionViewSwipeView *> *openSwipeViews(void)
{
    static NSMapTable *views;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ views = [NSMapTable weakToWeakObjectsMapTable]; });
    return views;
}

@interface VLCLibraryCollectionViewSwipeView ()
{
    NSLayoutConstraint *_contentLeadingConstraint;
    NSView *_leftClipView;
    NSView *_rightClipView;
    NSView *_leadingButtonsView;
    NSView *_trailingButtonsView;
    __weak NSClipView *_observedClipView;
    __weak NSWindow *_previousWindow;
    NSSize _lastLayoutSize;
    NSObject *_offsetAnimation;
    VLCCollectionScrollState _scrollState;
    NSMutableArray<NSEvent *> *_pendingScrollEvents;
    NSPoint _pendingScrollDelta;
    CGFloat _swipeOpenOffset;
    CGFloat _swipeRestOffset;
    BOOL _refreshingActions;
    BOOL _hasBeenInWindow;
}
@end

@implementation VLCLibraryCollectionViewSwipeView

- (instancetype)initWithContentView:(NSView *)contentView
{
    NSParameterAssert(contentView != nil);
    self = [super initWithFrame:contentView.frame];
    if (self) {
        _contentView = contentView;
        _leadingButtons = @[];
        _trailingButtons = @[];
        _pendingScrollEvents = NSMutableArray.array;
        _lastLayoutSize = self.bounds.size;
        self.autoresizingMask = contentView.autoresizingMask;
        self.wantsLayer = YES;
        self.layer.masksToBounds = YES;

        _leftClipView = [[NSView alloc] initWithFrame:NSZeroRect];
        _rightClipView = [[NSView alloc] initWithFrame:NSZeroRect];
        _leadingButtonsView = [[NSView alloc] initWithFrame:NSZeroRect];
        _trailingButtonsView = [[NSView alloc] initWithFrame:NSZeroRect];
        for (NSView *clipView in @[_leftClipView, _rightClipView]) {
            clipView.wantsLayer = YES;
            clipView.layer.masksToBounds = YES;
            [self addSubview:clipView];
        }
        [_leftClipView addSubview:_leadingButtonsView];
        [_rightClipView addSubview:_trailingButtonsView];

        contentView.translatesAutoresizingMaskIntoConstraints = NO;
        [self addSubview:contentView];
        contentView.nextResponder = self;
        _contentLeadingConstraint = [contentView.leftAnchor constraintEqualToAnchor:self.leftAnchor];
        [NSLayoutConstraint activateConstraints:@[
            _contentLeadingConstraint,
            [contentView.topAnchor constraintEqualToAnchor:self.topAnchor],
            [contentView.widthAnchor constraintEqualToAnchor:self.widthAnchor],
            [contentView.heightAnchor constraintEqualToAnchor:self.heightAnchor],
        ]];
    }
    return self;
}

- (void)dealloc
{
    [NSNotificationCenter.defaultCenter removeObserver:self];
}

- (BOOL)actionsVisible
{
    return fabs(_contentLeadingConstraint.constant) > VLCCollectionSwipeOffsetTolerance;
}

- (void)setCollectionView:(NSCollectionView *)collectionView
{
    if (_collectionView == collectionView) {
        return;
    }
    [self closeActionsAnimated:NO];
    _collectionView = collectionView;
}

- (void)installButtons:(NSArray<NSButton *> *)buttons inView:(NSView *)view
{
    for (NSView *button in view.subviews.copy) {
        [button removeFromSuperview];
    }
    for (NSButton *button in buttons) {
        button.translatesAutoresizingMaskIntoConstraints = YES;
        button.hidden = YES;
        button.accessibilityHidden = YES;
        button.refusesFirstResponder = YES;
        [view addSubview:button];
    }
}

- (void)setLeadingButtons:(NSArray<NSButton *> *)leadingButtons
          trailingButtons:(NSArray<NSButton *> *)trailingButtons
{
    [self closeActionsAnimated:NO];
    if ([self.leadingButtons isEqualToArray:leadingButtons] &&
        [self.trailingButtons isEqualToArray:trailingButtons]) {
        return;
    }
    _leadingButtons = leadingButtons.copy;
    _trailingButtons = trailingButtons.copy;
    [self installButtons:_leadingButtons inView:_leadingButtonsView];
    [self installButtons:_trailingButtons inView:_trailingButtonsView];
    self.needsLayout = YES;
}

- (NSArray<NSButton *> *)buttonsForEdge:(NSRectEdge)edge
{
    const BOOL rightToLeft = self.userInterfaceLayoutDirection == NSUserInterfaceLayoutDirectionRightToLeft;
    return (edge == NSMinXEdge) != rightToLeft ? self.leadingButtons : self.trailingButtons;
}

- (CGFloat)actionWidthForEdge:(NSRectEdge)edge
{
    const CGFloat preferredWidth = [self buttonsForEdge:edge].count * VLCCollectionSwipeButtonWidth;
    const CGFloat maximumWidth = NSWidth(self.bounds) * VLCCollectionSwipeDrawerWidthLimitFraction;
    return MIN(preferredWidth, MAX(0., maximumWidth));
}

- (void)layoutButtonsForEdge:(NSRectEdge)edge inView:(NSView *)view reveal:(CGFloat)reveal
{
    NSArray<NSButton *> * const buttons = [self buttonsForEdge:edge];
    if (buttons.count == 0) {
        return;
    }

    const CGFloat actionWidth = [self actionWidthForEdge:edge];
    const CGFloat buttonWidth = actionWidth / buttons.count;
    const CGFloat height = NSHeight(self.bounds);
    const CGFloat viewX = edge == NSMinXEdge ? 0. : reveal - actionWidth;
    view.frame = NSMakeRect(viewX, 0., actionWidth, height);
    const NSRect exposedRect = NSMakeRect(-viewX, 0., reveal, height);

    const BOOL rightToLeft = self.userInterfaceLayoutDirection == NSUserInterfaceLayoutDirectionRightToLeft;
    [buttons enumerateObjectsUsingBlock:^(NSButton *button, NSUInteger index, BOOL * __unused stop) {
        const NSUInteger physicalIndex = rightToLeft ? buttons.count - index - 1 : index;
        button.frame = NSMakeRect(physicalIndex * buttonWidth, 0., buttonWidth, height);
        const BOOL exposed = NSIntersectsRect(button.frame, exposedRect);
        button.accessibilityHidden = !exposed;
        button.refusesFirstResponder = !exposed;
        NSWindow * const window = self.window;
        if (!exposed && window.firstResponder == button && ![window makeFirstResponder:self.collectionView]) {
            [window makeFirstResponder:nil];
        }
        // Keep the outgoing buttons drawn until the slide animation completes.
        if (exposed || self->_offsetAnimation == nil) {
            button.hidden = !exposed;
        }
    }];
}

- (void)layoutActionViews
{
    const BOOL rightToLeft = self.userInterfaceLayoutDirection == NSUserInterfaceLayoutDirectionRightToLeft;
    NSView * const leftButtonsView = rightToLeft ? _trailingButtonsView : _leadingButtonsView;
    NSView * const rightButtonsView = rightToLeft ? _leadingButtonsView : _trailingButtonsView;
    if (leftButtonsView.superview != _leftClipView) {
        [_leftClipView addSubview:leftButtonsView];
        [_rightClipView addSubview:rightButtonsView];
    }

    const CGFloat offset = _contentLeadingConstraint.constant;
    const CGFloat leftReveal = MAX(offset, 0.);
    const CGFloat rightReveal = MAX(-offset, 0.);
    _leftClipView.frame = NSMakeRect(0., 0., leftReveal, NSHeight(self.bounds));
    _rightClipView.frame = NSMakeRect(NSWidth(self.bounds) - rightReveal, 0., rightReveal, NSHeight(self.bounds));
    [self layoutButtonsForEdge:NSMinXEdge inView:leftButtonsView reveal:leftReveal];
    [self layoutButtonsForEdge:NSMaxXEdge inView:rightButtonsView reveal:rightReveal];
}

- (void)layout
{
    if (!NSEqualSizes(_lastLayoutSize, self.bounds.size)) {
        _lastLayoutSize = self.bounds.size;
        [self cancelSwipeForReset];
        [self removeOffsetAnimations];
        _contentLeadingConstraint.constant = 0.;
        [self unregisterOpenActions];
    }
    self.contentView.nextResponder = self;
    [super layout];
    [self layoutActionViews];
}

- (void)setContentOffset:(CGFloat)offset animated:(BOOL)animated
{
    if (animated && self.window != nil && !NSWorkspace.sharedWorkspace.accessibilityDisplayShouldReduceMotion) {
        NSObject * const animation = NSObject.new;
        _offsetAnimation = animation;
        __weak typeof(self) weakSelf = self;
        [NSAnimationContext runAnimationGroup:^(NSAnimationContext *context) {
            context.duration = VLCCollectionSwipeSettleDuration;
            context.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseOut];
            context.allowsImplicitAnimation = YES;
            self->_contentLeadingConstraint.constant = offset;
            self.needsLayout = YES;
            [self layoutSubtreeIfNeeded];
        } completionHandler:^{
            __strong typeof(weakSelf) strongSelf = weakSelf;
            if (strongSelf != nil && strongSelf->_offsetAnimation == animation) {
                strongSelf->_offsetAnimation = nil;
                strongSelf.needsLayout = YES;
                [strongSelf layoutSubtreeIfNeeded];
            }
        }];
    } else {
        [self removeOffsetAnimations];
        _contentLeadingConstraint.constant = offset;
        self.needsLayout = YES;
        [self layoutSubtreeIfNeeded];
    }
}

- (void)removeOffsetAnimations
{
    _offsetAnimation = nil;
    [_contentView.layer removeAllAnimations];
    [_leftClipView.layer removeAllAnimations];
    [_rightClipView.layer removeAllAnimations];
    [_leadingButtonsView.layer removeAllAnimations];
    [_trailingButtonsView.layer removeAllAnimations];
    for (NSButton *button in self.leadingButtons) {
        [button.layer removeAllAnimations];
    }
    for (NSButton *button in self.trailingButtons) {
        [button.layer removeAllAnimations];
    }
}

- (void)clearPendingScrollEvents
{
    [_pendingScrollEvents removeAllObjects];
    _pendingScrollDelta = NSZeroPoint;
}

- (NSArray<NSEvent *> *)takePendingScrollEvents
{
    NSArray<NSEvent *> * const events = _pendingScrollEvents.copy;
    [self clearPendingScrollEvents];
    return events;
}

- (void)forwardScrollEvents:(NSArray<NSEvent *> *)events
{
    for (NSEvent *event in events) {
        [super scrollWheel:event];
    }
}

- (void)cancelSwipeForReset
{
    if (_scrollState == VLCCollectionScrollSwiping) {
        _scrollState = VLCCollectionScrollConsumed;
    } else if (_scrollState == VLCCollectionScrollUndecided && _pendingScrollEvents.count > 0) {
        // Keep the pending samples for the scroll view, but don't claim this gesture for a new item.
        _scrollState = VLCCollectionScrollForwarding;
    }
}

- (void)refreshActionsBeforeReveal
{
    if (!_refreshingActions && self.willRevealActions != nil) {
        _refreshingActions = YES;
        self.willRevealActions();
        _refreshingActions = NO;
    }
}

- (void)registerOpenActions
{
    if (self.collectionView != nil) {
        VLCLibraryCollectionViewSwipeView * const previous = [openSwipeViews() objectForKey:self.collectionView];
        if (previous != nil && previous != self) {
            [previous closeActionsAnimated:YES];
        }
        [openSwipeViews() setObject:self forKey:self.collectionView];
    }
    [self updateClipViewObserver];
}

- (void)unregisterOpenActions
{
    if (self.collectionView != nil && [openSwipeViews() objectForKey:self.collectionView] == self) {
        [openSwipeViews() removeObjectForKey:self.collectionView];
    }
    [self stopObservingClipView];
}

- (void)closeActionsAnimated:(BOOL)animated
{
    [self cancelSwipeForReset];
    [self unregisterOpenActions];
    if (_contentLeadingConstraint.constant != 0. || (!animated && _offsetAnimation != nil)) {
        [self setContentOffset:0. animated:animated];
    }
}

+ (BOOL)closeActionsInCollectionView:(NSCollectionView *)collectionView
{
    if (collectionView == nil) {
        return NO;
    }
    VLCLibraryCollectionViewSwipeView * const view = [openSwipeViews() objectForKey:collectionView];
    if (view == nil) {
        return NO;
    }
    const BOOL wasOpen = view.actionsVisible || view->_scrollState == VLCCollectionScrollSwiping;
    [view closeActionsAnimated:YES];
    return wasOpen;
}

- (void)updateClipViewObserver
{
    NSClipView * const clipView = self.actionsVisible || _scrollState == VLCCollectionScrollSwiping ?
        (self.enclosingScrollView.contentView ?: self.collectionView.enclosingScrollView.contentView) : nil;
    if (clipView == _observedClipView) {
        return;
    }
    [self stopObservingClipView];
    _observedClipView = clipView;
    if (clipView != nil) {
        clipView.postsBoundsChangedNotifications = YES;
        [NSNotificationCenter.defaultCenter addObserver:self
                                               selector:@selector(clipViewBoundsChanged:)
                                                   name:NSViewBoundsDidChangeNotification
                                                 object:clipView];
    }
}

- (void)stopObservingClipView
{
    if (_observedClipView != nil) {
        [NSNotificationCenter.defaultCenter removeObserver:self name:NSViewBoundsDidChangeNotification object:_observedClipView];
        _observedClipView = nil;
    }
}

- (void)clipViewBoundsChanged:(NSNotification *)notification
{
    if (self.actionsVisible || _scrollState == VLCCollectionScrollSwiping) {
        [self closeActionsAnimated:NO];
    }
}

- (void)viewDidMoveToSuperview
{
    [super viewDidMoveToSuperview];
    self.contentView.nextResponder = self;
    [self updateClipViewObserver];
}

- (void)viewDidMoveToWindow
{
    [super viewDidMoveToWindow];
    self.contentView.nextResponder = self;
    if (_hasBeenInWindow && (_previousWindow != self.window || self.window == nil)) {
        [self closeActionsAnimated:NO];
    }
    _hasBeenInWindow |= self.window != nil;
    _previousWindow = self.window;
    [self updateClipViewObserver];
}

- (BOOL)wantsForwardedScrollEventsForAxis:(NSEventGestureAxis)axis
{
    return axis == NSEventGestureAxisHorizontal &&
        (self.leadingButtons.count > 0 || self.trailingButtons.count > 0 || self.willRevealActions != nil);
}

- (BOOL)beginSwipeWithDelta:(CGFloat)delta
{
    const CGFloat offset = _contentLeadingConstraint.constant;
    const BOOL hasReveal = fabs(offset) > VLCCollectionSwipeOffsetTolerance;
    if (!hasReveal) {
        [self refreshActionsBeforeReveal];
    }
    const BOOL revealsLeftEdge = (hasReveal ? offset : delta) > 0.;
    const NSRectEdge edge = revealsLeftEdge ? NSMinXEdge : NSMaxXEdge;
    const CGFloat width = [self actionWidthForEdge:edge];
    if (width == 0.) {
        return NO;
    }
    _swipeOpenOffset = revealsLeftEdge ? width : -width;
    const CGFloat restingProgress = offset / _swipeOpenOffset;
    _swipeRestOffset = restingProgress >= VLCCollectionSwipeSettleProgressThreshold ? _swipeOpenOffset : 0.;
    _scrollState = VLCCollectionScrollSwiping;
    [self registerOpenActions];
    [self moveSwipeFromOffset:offset byDelta:delta];
    return YES;
}

- (void)moveSwipeFromOffset:(CGFloat)offset byDelta:(CGFloat)delta
{
    const CGFloat minimum = MIN(0., _swipeOpenOffset);
    const CGFloat maximum = MAX(0., _swipeOpenOffset);
    [self setContentOffset:MIN(maximum, MAX(minimum, offset + delta)) animated:NO];
}

- (void)finishSwipeCancelled:(BOOL)cancelled
{
    _scrollState = VLCCollectionScrollConsumed;
    const CGFloat offset = _contentLeadingConstraint.constant;
    const CGFloat openOffset = _swipeOpenOffset;
    const CGFloat progress = offset / openOffset;
    const CGFloat nearestOffset = progress >= VLCCollectionSwipeSettleProgressThreshold ? openOffset : 0.;
    const CGFloat finalOffset = cancelled ? _swipeRestOffset : nearestOffset;
    if (finalOffset == 0.) {
        [self closeActionsAnimated:YES];
    } else {
        [self setContentOffset:finalOffset animated:YES];
    }
}

- (void)scrollWheel:(NSEvent *)event
{
    const NSEventPhase phase = event.phase;
    const BOOL momentum = event.momentumPhase != NSEventPhaseNone;
    if (!event.hasPreciseScrollingDeltas || (phase == NSEventPhaseNone && !momentum) ||
        !NSEvent.swipeTrackingFromScrollEventsEnabled) {
        [super scrollWheel:event];
        return;
    }
    if (phase == NSEventPhaseBegan || phase == NSEventPhaseMayBegin) {
        _scrollState = VLCCollectionScrollUndecided;
        [self clearPendingScrollEvents];
    }
    if (_scrollState != VLCCollectionScrollForwarding && _scrollState != VLCCollectionScrollConsumed &&
        !momentum && phase != NSEventPhaseMayBegin) {
        [self layoutSubtreeIfNeeded];
    }
    if (_scrollState == VLCCollectionScrollConsumed ||
        (momentum && _scrollState == VLCCollectionScrollSwiping)) {
        return;
    }
    if (_scrollState == VLCCollectionScrollForwarding || momentum || phase == NSEventPhaseMayBegin) {
        if (_pendingScrollEvents.count > 0) {
            [self forwardScrollEvents:[self takePendingScrollEvents]];
        }
        [super scrollWheel:event];
        return;
    }

    const BOOL cancelled = (phase & NSEventPhaseCancelled) != 0;
    const BOOL ending = cancelled || (phase & NSEventPhaseEnded) != 0;
    if (_scrollState == VLCCollectionScrollSwiping) {
        if (!cancelled && event.scrollingDeltaX != 0.) {
            [self moveSwipeFromOffset:_contentLeadingConstraint.constant byDelta:event.scrollingDeltaX];
        }
        if (ending) {
            [self finishSwipeCancelled:cancelled];
        }
        return;
    }

    // Let the first few points establish intent before forwarding them to the scroll view.
    [_pendingScrollEvents addObject:event];
    _pendingScrollDelta.x += event.scrollingDeltaX;
    _pendingScrollDelta.y += event.scrollingDeltaY;
    const CGFloat horizontal = fabs(_pendingScrollDelta.x);
    const CGFloat vertical = fabs(_pendingScrollDelta.y);
    const BOOL hasIntent = MAX(horizontal, vertical) >= VLCCollectionSwipeIntentDistance;
    if (!ending && !hasIntent && _pendingScrollEvents.count < VLCCollectionSwipePendingEventLimit) {
        return;
    }
    const CGFloat delta = _pendingScrollDelta.x;
    NSArray<NSEvent *> * const pendingEvents = [self takePendingScrollEvents];
    if (!ending && hasIntent && horizontal > VLCCollectionSwipeMinimumHorizontalRatio * vertical &&
        [self beginSwipeWithDelta:delta]) {
        return;
    }
    _scrollState = VLCCollectionScrollForwarding;
    if (!cancelled && vertical > horizontal) {
        [self closeActionsAnimated:YES];
    }
    [self forwardScrollEvents:pendingEvents];
}

- (void)cancelOperation:(id)sender
{
    if (self.actionsVisible || _scrollState == VLCCollectionScrollSwiping) {
        [self closeActionsAnimated:YES];
    } else {
        [self.nextResponder tryToPerform:_cmd with:sender];
    }
}

@end
