/*****************************************************************************
 * VLCLibraryCollectionSwipeIntegrationTest.m: native collection card swipes
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

#import <Cocoa/Cocoa.h>
#import <QuartzCore/QuartzCore.h>
#import <dlfcn.h>
#import <objc/runtime.h>

#import "library/VLCLibraryCollectionViewItem.h"
#import "library/VLCLibraryCollectionViewSwipeView.h"
#import "library/VLCLibraryDataTypes.h"
#import "library/VLCLibraryRepresentedItem.h"

#include <vlc_common.h>

static NSString * const CardIdentifier = @"SwipeIntegrationCard";
static const CGFloat CardWidth = 240.;
static const CGFloat CardHeight = 220.;
static const CGFloat PositionTolerance = 0.5;
static const NSTimeInterval PresentationTimeout = 3.;

static void Require(BOOL condition, NSString *message)
{
    if (!condition) {
        fprintf(stderr, "%s\n", message.UTF8String);
        exit(EXIT_FAILURE);
    }
}

static void MockMethod(Class cls, SEL selector, id implementation)
{
    Method const method = class_getInstanceMethod(cls, selector);
    Require(method != NULL, [NSString stringWithFormat:@"Missing method %s on %@", sel_getName(selector), cls]);
    class_replaceMethod(cls, selector, imp_implementationWithBlock(implementation), method_getTypeEncoding(method));
}

@interface VLCSwipeIntegrationDataSource : NSObject <NSCollectionViewDataSource>
@property (nonatomic, strong) VLCLibraryRepresentedItem *representedItem;
@end

@implementation VLCSwipeIntegrationDataSource
- (NSInteger)collectionView:(NSCollectionView * __unused)collectionView numberOfItemsInSection:(NSInteger __unused)section
{
    return 1;
}

- (NSCollectionViewItem *)collectionView:(NSCollectionView *)collectionView
     itemForRepresentedObjectAtIndexPath:(NSIndexPath *)indexPath
{
    VLCLibraryCollectionViewItem * const card =
        [collectionView makeItemWithIdentifier:CardIdentifier forIndexPath:indexPath];
    card.representedItem = self.representedItem;
    return card;
}
@end

// Inject real pixel scroll events through AppKit's window dispatch without moving
// the system pointer or depending on the machine's trackpad preferences.
static void SendSwipe(NSWindow *window, NSPoint location, CGScrollPhase phase, int32_t delta)
{
    CGEventRef const scroll = CGEventCreateScrollWheelEvent(NULL, kCGScrollEventUnitPixel, 2, 0, delta);
    Require(scroll != NULL, @"Could not create a pixel scroll event");
    CGEventSetIntegerValueField(scroll, kCGScrollWheelEventIsContinuous, 1);
    CGEventSetIntegerValueField(scroll, kCGScrollWheelEventScrollPhase, phase);
    CGEventSetLocation(scroll, CGPointMake(location.x, NSMaxY(NSScreen.screens.firstObject.frame) - location.y));
    NSEvent * const event = [NSEvent eventWithCGEvent:scroll];
    CFRelease(scroll);
    Require(event.hasPreciseScrollingDeltas && NSEqualPoints(event.locationInWindow, location),
            @"Injected scroll event lost its pixel deltas or location");
    [window sendEvent:event];
}

static CGFloat Offset(VLCLibraryCollectionViewSwipeView *view)
{
    return NSMinX(view.contentView.frame) - NSMinX(view.bounds);
}

static CGFloat PresentedOffset(VLCLibraryCollectionViewSwipeView *view)
{
    CALayer * const presented = view.contentView.layer.presentationLayer;
    return presented != nil ? NSMinX(presented.frame) - NSMinX(view.bounds) : NAN;
}

static void WaitForPresentation(VLCLibraryCollectionViewSwipeView *view, CGFloat offset)
{
    NSDate * const deadline = [NSDate dateWithTimeIntervalSinceNow:PresentationTimeout];
    while (!(fabs(PresentedOffset(view) - offset) < PositionTolerance) && deadline.timeIntervalSinceNow > 0.) {
        [NSApp updateWindows];
        [CATransaction flush];
        [NSRunLoop.currentRunLoop runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.01]];
    }
    Require(fabs(PresentedOffset(view) - offset) < PositionTolerance,
            [NSString stringWithFormat:@"Expected presented offset %f, got %f", offset, PresentedOffset(view)]);
}

// Stop the layer clock so the assertions do not depend on how long the runner
// takes to sample the transition after an event.
static void PauseLayerClock(CALayer *layer)
{
    const CFTimeInterval now = [layer convertTime:CACurrentMediaTime() fromLayer:nil];
    layer.speed = 0.f;
    layer.timeOffset = now;
}

static void ResumeLayerClock(CALayer *layer)
{
    const CFTimeInterval pausedTime = layer.timeOffset;
    layer.speed = 1.f;
    layer.timeOffset = 0.;
    layer.beginTime = 0.;
    layer.beginTime = [layer convertTime:CACurrentMediaTime() fromLayer:nil] - pausedTime;
}

static NSButton *ActionButton(VLCLibraryCollectionViewSwipeView *view, NSRectEdge edge)
{
    const CGFloat x = edge == NSMinXEdge ? NSMinX(view.bounds) + 16. : NSMaxX(view.bounds) - 16.;
    const NSPoint position = NSMakePoint(x, NSMidY(view.bounds));
    NSView * const hit = [view hitTest:[view convertPoint:position toView:view.superview]];
    Require([hit isKindOfClass:NSButton.class], @"The drawer did not expose a hittable action button");
    return (NSButton *)hit;
}

int main(void)
{
    @autoreleasepool {
        [NSApplication sharedApplication];
        [NSApp finishLaunching];
        if (dlopen(VLC_SWIPE_TEST_PLUGIN, RTLD_NOW | RTLD_LOCAL) == NULL) {
            fprintf(stderr, "Could not load the macOS plugin: %s\n", dlerror());
            return EXIT_FAILURE;
        }

        // Load the same nib as the production class without installing a VLC.app.
        NSURL * const nibURL = [NSURL fileURLWithPath:@VLC_SWIPE_TEST_CARD_NIB];
        NSData * const nibData = [NSData dataWithContentsOfURL:nibURL];
        Require(nibData != nil, @"Could not read the compiled collection card nib");
        NSNib * const nib = [[NSNib alloc] initWithNibData:nibData bundle:nil];
        Require(nib != nil, @"Could not load the compiled collection card nib");
        for (NSString * const iconName in @[@"libraryPlay", @"ellipsis"]) {
            [[[NSImage alloc] initWithSize:NSMakeSize(1., 1.)] setName:iconName];
        }
        const SEL loadNib = @selector(loadNibNamed:owner:topLevelObjects:);
        IMP const originalLoad = class_getMethodImplementation(NSBundle.class, loadNib);
        MockMethod(NSBundle.class, loadNib, ^BOOL(NSBundle *bundle, NSNibName name, id owner, NSArray **objects) {
            if ([name isEqualToString:@"VLCMediaItemCollectionViewItem"]) {
                return [nib instantiateWithOwner:owner topLevelObjects:objects];
            }
            return ((BOOL (*)(id, SEL, NSNibName, id, NSArray **))originalLoad)(bundle, loadNib, name, owner, objects);
        });
        MockMethod(object_getClass(NSEvent.class), @selector(isSwipeTrackingFromScrollEventsEnabled),
                   ^BOOL(id __unused cls) { return YES; });
        MockMethod(NSWorkspace.class, @selector(accessibilityDisplayShouldReduceMotion),
                   ^BOOL(id __unused workspace) { return NO; });
        MockMethod(object_getClass(NSClassFromString(@"VLCLibraryImageCache")),
                   NSSelectorFromString(@"thumbnailForLibraryItem:withCompletion:"),
                   ^(id __unused cls, id __unused item, void (^completion)(NSImage *)) { completion(nil); });

        // Mock the backing data while keeping card binding, gesture handling and
        // action selector dispatch in the production plugin.
        Class const mediaClass = NSClassFromString(@"VLCMediaLibraryMediaItem");
        Class const groupClass = NSClassFromString(@"VLCMediaLibraryGroup");
        Class const representedClass = NSClassFromString(@"VLCLibraryRepresentedItem");
        Class const cardClass = NSClassFromString(@"VLCLibraryCollectionViewItem");
        Class const swipeClass = NSClassFromString(@"VLCLibraryCollectionViewSwipeView");
        Require(mediaClass && groupClass && representedClass && cardClass && swipeClass,
                @"The plugin did not register the card classes");
        NSMutableDictionary<NSNumber *, VLCMediaLibraryMediaItem *> * const media = NSMutableDictionary.dictionary;
        for (NSNumber * const identifier in @[@1, @2]) {
            VLCMediaLibraryMediaItem * const item = [mediaClass new];
            [item setValue:identifier forKey:@"libraryID"];
            [item setValue:@(VLC_ML_MEDIA_TYPE_AUDIO) forKey:@"mediaType"];
            [item setValue:@"Fixture" forKey:@"title"];
            media[identifier] = item;
        }
        MockMethod(object_getClass(mediaClass), @selector(mediaItemForLibraryID:),
                   ^id(id __unused cls, int64_t identifier) { return media[@(identifier)]; });
        MockMethod(mediaClass, @selector(primaryDetailString),
                   ^NSString *(id __unused item) { return @""; });
        NSMutableArray<NSNumber *> * const favoriteWrites = NSMutableArray.array;
        MockMethod(mediaClass, @selector(setFavorite:), ^int(VLCMediaLibraryMediaItem *item, BOOL favorite) {
            [favoriteWrites addObject:@(favorite)];
            [item setValue:@(favorite) forKey:@"_favorited"];
            return VLC_SUCCESS;
        });
        NSMutableArray<NSNumber *> * const queuedItems = NSMutableArray.array;
        MockMethod(representedClass, @selector(queue), ^(VLCLibraryRepresentedItem *item) {
            [queuedItems addObject:@(item.item.libraryID)];
        });

        NSCollectionView * const collection = [[NSCollectionView alloc] initWithFrame:NSMakeRect(0., 0., 300., 260.)];
        collection.userInterfaceLayoutDirection = NSUserInterfaceLayoutDirectionLeftToRight;
        NSCollectionViewFlowLayout * const layout = NSCollectionViewFlowLayout.new;
        layout.itemSize = NSMakeSize(CardWidth, CardHeight);
        collection.collectionViewLayout = layout;
        [collection registerClass:cardClass forItemWithIdentifier:CardIdentifier];
        VLCSwipeIntegrationDataSource * const source = VLCSwipeIntegrationDataSource.new;
        source.representedItem = [[representedClass alloc] initWithItem:media[@1]
                                                             parentType:VLCMediaLibraryParentGroupTypeUnknown];
        collection.dataSource = source;
        NSScrollView * const scrollView = [[NSScrollView alloc] initWithFrame:collection.frame];
        scrollView.documentView = collection;

        NSWindow * const window = [[NSWindow alloc] initWithContentRect:collection.frame
                                                              styleMask:NSWindowStyleMaskBorderless
                                                                backing:NSBackingStoreBuffered
                                                                  defer:NO];
        window.releasedWhenClosed = NO;
        window.contentView = scrollView;
        [window orderBack:nil];
        [collection reloadData];
        [window.contentView layoutSubtreeIfNeeded];

        VLCLibraryCollectionViewItem * const card =
            (VLCLibraryCollectionViewItem *)[collection itemAtIndexPath:[NSIndexPath indexPathForItem:0 inSection:0]];
        Require([card.view isKindOfClass:swipeClass], @"The nib card did not install its swipe view");
        VLCLibraryCollectionViewSwipeView * const view = (VLCLibraryCollectionViewSwipeView *)card.view;
        WaitForPresentation(view, 0.);
        const NSPoint artworkPoint = [view convertPoint:NSMakePoint(NSMidX(view.bounds), NSMidY(view.bounds)) toView:nil];

        SendSwipe(window, artworkPoint, kCGScrollPhaseBegan, -50);
        SendSwipe(window, artworkPoint, kCGScrollPhaseEnded, 0);
        const CGFloat openOffset = Offset(view);
        Require(openOffset < 0., @"A trailing swipe dispatched over the card did not reveal Favorite");
        WaitForPresentation(view, openOffset);
        const NSPoint favoritePoint = [view convertPoint:NSMakePoint(NSMaxX(view.bounds) - 16., NSMidY(view.bounds))
                                                  toView:nil];
        SendSwipe(window, favoritePoint, kCGScrollPhaseBegan, 48);
        const CGFloat closingOffset = Offset(view);
        Require(closingOffset > openOffset && closingOffset < 0., @"Reverse swipe did not move the card toward closed");
        WaitForPresentation(view, closingOffset);
        PauseLayerClock(view.layer);
        SendSwipe(window, favoritePoint, kCGScrollPhaseEnded, 0);
        [CATransaction flush];
        Require(fabs(Offset(view)) < PositionTolerance && PresentedOffset(view) < -PositionTolerance &&
                PresentedOffset(view) > openOffset + PositionTolerance &&
                view.contentView.layer.animationKeys.count > 0 && favoriteWrites.count == 0,
                @"Reverse release did not animate from a partial offset without firing Favorite");
        ResumeLayerClock(view.layer);
        WaitForPresentation(view, 0.);

        SendSwipe(window, artworkPoint, kCGScrollPhaseBegan, -50);
        SendSwipe(window, artworkPoint, kCGScrollPhaseEnded, 0);
        WaitForPresentation(view, openOffset);
        PauseLayerClock(view.layer);
        [ActionButton(view, NSMaxXEdge) performClick:nil];
        [CATransaction flush];
        Require([favoriteWrites isEqualToArray:@[@YES]], @"The exposed Add button did not favorite the card");
        const CGFloat interruptedOffset = PresentedOffset(view);
        const int32_t takeoverDelta = 8;
        Require(interruptedOffset + takeoverDelta < -PositionTolerance && fabs(Offset(view)) < PositionTolerance &&
                view.contentView.layer.animationKeys.count > 0,
                @"Favorite did not start closing from the exposed drawer");
        SendSwipe(window, artworkPoint, kCGScrollPhaseBegan, takeoverDelta);
        Require(fabs(Offset(view) - interruptedOffset - takeoverDelta) < PositionTolerance,
                @"The new swipe did not take over from the displayed offset");
        SendSwipe(window, artworkPoint, kCGScrollPhaseChanged, -48);
        ResumeLayerClock(view.layer);
        SendSwipe(window, artworkPoint, kCGScrollPhaseEnded, 0);
        WaitForPresentation(view, openOffset);
        NSButton * const remove = ActionButton(view, NSMaxXEdge);
        NSString * const removeTitle = [NSString stringWithUTF8String:vlc_gettext("Remove from Favorites")];
        Require([remove.title isEqualToString:removeTitle],
                @"Interrupting the Favorite close reused the old Add label");
        [remove performClick:nil];
        Require([favoriteWrites isEqualToArray:(@[@YES, @NO])], @"The reopened Remove button did not remove the favorite");
        WaitForPresentation(view, 0.);

        SendSwipe(window, artworkPoint, kCGScrollPhaseBegan, 50);
        Require(Offset(view) > 0. && queuedItems.count == 0, @"The leading swipe did not begin revealing Queue");
        [card prepareForReuse];
        card.representedItem = [[representedClass alloc] initWithItem:media[@2]
                                                           parentType:VLCMediaLibraryParentGroupTypeUnknown];
        SendSwipe(window, artworkPoint, kCGScrollPhaseChanged, 65);
        SendSwipe(window, artworkPoint, kCGScrollPhaseEnded, 0);
        Require(queuedItems.count == 0 && fabs(Offset(view)) < PositionTolerance,
                @"Stale swipe events were applied after the card was rebound");
        SendSwipe(window, artworkPoint, kCGScrollPhaseBegan, 50);
        SendSwipe(window, artworkPoint, kCGScrollPhaseEnded, 0);
        WaitForPresentation(view, Offset(view));
        [ActionButton(view, NSMinXEdge) performClick:nil];
        Require([queuedItems isEqualToArray:@[@2]], @"The rebound card's Queue button dispatched the wrong action");

        const int64_t groupID = 3;
        VLCMediaLibraryMediaItem * const freshMember = [mediaClass new];
        [freshMember setValue:@1 forKey:@"libraryID"];
        [freshMember setValue:@YES forKey:@"_favorited"];
        VLCMediaLibraryGroup * const staleGroup = [groupClass new];
        VLCMediaLibraryGroup * const freshGroup = [groupClass new];
        for (VLCMediaLibraryGroup * const group in @[staleGroup, freshGroup]) {
            [group setValue:@(groupID) forKey:@"libraryID"];
            [group setValue:@1 forKey:@"numberOfTotalItems"];
            [group setValue:@[group == staleGroup ? media[@1] : freshMember] forKey:@"groupMediaItems"];
        }
        MockMethod(object_getClass(groupClass), @selector(groupWithID:), ^id(id __unused cls, int64_t identifier) {
            return identifier == groupID ? freshGroup : nil;
        });
        card.representedItem = [[representedClass alloc] initWithItem:staleGroup
                                                           parentType:VLCMediaLibraryParentGroupTypeUnknown];
        SendSwipe(window, artworkPoint, kCGScrollPhaseBegan, -50);
        SendSwipe(window, artworkPoint, kCGScrollPhaseEnded, 0);
        WaitForPresentation(view, openOffset);
        NSButton * const groupRemove = ActionButton(view, NSMaxXEdge);
        Require([groupRemove.title isEqualToString:removeTitle], @"The group action used stale member favorites");
        [groupRemove performClick:nil];
        Require([favoriteWrites isEqualToArray:(@[@YES, @NO, @NO])] && !freshMember.favorited,
                @"The group action did not update the current member");
        [window orderOut:nil];
    }
    return EXIT_SUCCESS;
}
