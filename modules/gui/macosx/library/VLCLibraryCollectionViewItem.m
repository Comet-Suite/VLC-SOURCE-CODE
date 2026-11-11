/*****************************************************************************
 * VLCLibraryCollectionViewItem.m: MacOS X interface module
 *****************************************************************************
 * Copyright (C) 2026 VLC authors and VideoLAN
 *
 * Authors: Felix Paul Kühne <fkuehne # videolan -dot- org>
 *          Claudio Cambra <developer@claudiocambra.com>
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

#import "VLCLibraryCollectionViewItem.h"

#import <QuartzCore/QuartzCore.h>

#import "extensions/NSColor+VLCAdditions.h"
#import "extensions/NSString+Helpers.h"

#import "library/VLCLibraryCollectionViewDataSource.h"
#import "library/VLCLibraryCollectionViewFlowLayout.h"
#import "library/VLCLibraryCollectionViewSwipeView.h"
#import "library/VLCLibraryDataTypes.h"
#import "library/VLCLibraryImageCache.h"
#import "library/VLCLibraryMenuController.h"
#import "library/VLCLibraryModel.h"
#import "library/VLCLibraryRepresentedItem.h"

#import "views/VLCImageView.h"
#import "views/VLCLinearProgressIndicator.h"
#import "views/VLCMediaItemCollectionViewItem.h"
#import "views/VLCTrackingView.h"

NSString *VLCLibraryCollectionViewItemIdentifier = @"VLCLibraryCollectionViewItemIdentifier";

@interface VLCLibraryCollectionViewItem ()
{
    VLCLibraryMenuController *_menuController;
    NSLayoutConstraint *_videoImageViewAspectRatioConstraint;
    VLCLibraryCollectionViewSwipeView *_swipeView;
}
@end

@implementation VLCLibraryCollectionViewItem

@synthesize representedItem = _representedItem;

- (instancetype)initWithNibName:(NSNibName)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        NSNotificationCenter * const nc = NSNotificationCenter.defaultCenter;
        [nc addObserver:self
               selector:@selector(mediaItemThumbnailGenerated:)
                   name:VLCLibraryModelMediaItemThumbnailGenerated
                 object:nil];
    }
    return self;
}

- (void)dealloc
{
    [NSNotificationCenter.defaultCenter removeObserver:self];
}

- (void)awakeFromNib
{
    self.deselectWhenClickedIfSelected = YES;
    _videoImageViewAspectRatioConstraint = [NSLayoutConstraint constraintWithItem:self.mediaImageView
                                                                        attribute:NSLayoutAttributeHeight
                                                                        relatedBy:NSLayoutRelationEqual
                                                                        toItem:self.mediaImageView
                                                                        attribute:NSLayoutAttributeWidth
                                                                       multiplier:VLCUIUnits.videoItemCollectionViewImageViewAspectRatioMultiplier
                                                                        constant:1];
    _videoImageViewAspectRatioConstraint.priority = NSLayoutPriorityRequired;
    _videoImageViewAspectRatioConstraint.active = NO;

    [super awakeFromNib];

    NSView * const contentView = self.view;
    // Detach the controller's responder chain before reparenting its original view.
    self.view = [[NSView alloc] initWithFrame:contentView.frame];
    _swipeView = [[VLCLibraryCollectionViewSwipeView alloc] initWithContentView:contentView];
    self.view = _swipeView;
    __weak typeof(self) weakSelf = self;
    _swipeView.willRevealActions = ^{
        [weakSelf updateSwipeActions];
    };

    self.secondaryInfoTextField.textColor = NSColor.VLClibrarySubtitleColor;
    self.unplayedIndicatorTextField.stringValue = _NS("NEW");
    self.unplayedIndicatorTextField.font = [NSFont systemFontOfSize:NSFont.systemFontSize weight:NSFontWeightBold];
    self.unplayedIndicatorTextField.textColor = NSColor.VLCAccentColor;
}

- (void)prepareForReuse
{
    [super prepareForReuse];
    _representedItem = nil;
    [self resetSwipeActions];
    self.secondaryInfoTextField.stringValue = [NSString stringWithTime:0];
    self.progressIndicator.hidden = YES;
    [self setUnplayedIndicatorHidden:YES];
}

- (void)setRepresentedItem:(VLCLibraryRepresentedItem *)representedItem
{
    if (_representedItem == representedItem) {
        return;
    }
    [self resetSwipeActions];
    _representedItem = representedItem;
    [self updateRepresentation];
}

- (void)resetSwipeActions
{
    [_swipeView setLeadingButtons:@[] trailingButtons:@[]];
}

- (void)setSelected:(BOOL)selected
{
    if (self.selected != selected) {
        [_swipeView closeActionsAnimated:NO];
    }
    [super setSelected:selected];
}

- (NSButton *)swipeButtonWithTitle:(NSString *)title
                            action:(SEL)action
                              item:(id)item
                             color:(NSColor *)color
{
    NSButton * const button = [[NSButton alloc] init];
    [button setButtonType:NSButtonTypeMomentaryPushIn];
    button.bezelStyle = NSBezelStyleSmallSquare;
    button.bordered = YES;
    button.showsBorderOnlyWhileMouseInside = YES;
    button.wantsLayer = YES;
    button.layer.backgroundColor = color.CGColor;
    button.font = [NSFont systemFontOfSize:NSFont.smallSystemFontSize];
    button.title = title;
    button.toolTip = title;
    button.accessibilityLabel = title;
    button.imagePosition = NSNoImage;
    button.cell.wraps = YES;
    button.cell.lineBreakMode = NSLineBreakByWordWrapping;
    NSMutableParagraphStyle * const paragraph = [[NSMutableParagraphStyle alloc] init];
    paragraph.alignment = NSTextAlignmentCenter;
    paragraph.lineBreakMode = NSLineBreakByWordWrapping;
    button.attributedTitle = [[NSAttributedString alloc] initWithString:title attributes:@{
        NSFontAttributeName:button.font,
        NSForegroundColorAttributeName:NSColor.whiteColor,
        NSParagraphStyleAttributeName:paragraph,
    }];
    button.cell.representedObject = item;
    button.target = self;
    button.action = action;
    return button;
}

- (void)updateSwipeActions
{
    if (_swipeView == nil) {
        return;
    }
    _swipeView.collectionView = self.collectionView;
    id<VLCMediaLibraryItemProtocol> actionItem = self.representedItem.item;
    if ([actionItem isKindOfClass:VLCMediaLibraryMediaItem.class]) {
        actionItem = [VLCMediaLibraryMediaItem mediaItemForLibraryID:actionItem.libraryID];
    } else if ([actionItem isKindOfClass:VLCMediaLibraryGroup.class]) {
        actionItem = [VLCMediaLibraryGroup groupWithID:actionItem.libraryID];
    }
    if (actionItem == nil) {
        [self resetSwipeActions];
        return;
    }
    NSButton * const queueButton = [self swipeButtonWithTitle:_NS("Append to Play Queue")
                                                       action:@selector(queueFromSwipe:)
                                                         item:self.representedItem
                                                        color:NSColor.VLCAccentColor];

    const BOOL favorited = actionItem.favorited;
    NSString * const favoriteTitle = favorited ? _NS("Remove from Favorites") : _NS("Add to Favorites");
    const SEL favoriteAction = favorited ? @selector(removeFavoriteFromSwipe:) : @selector(addFavoriteFromSwipe:);
    NSButton * const favoriteButton = [self swipeButtonWithTitle:favoriteTitle
                                                          action:favoriteAction
                                                            item:actionItem
                                                           color:favorited ? NSColor.systemRedColor : NSColor.systemBlueColor];
    [_swipeView setLeadingButtons:@[queueButton] trailingButtons:@[favoriteButton]];
}

- (void)mediaItemThumbnailGenerated:(NSNotification *)aNotification
{
    VLCMediaLibraryMediaItem * const updatedMediaItem = aNotification.object;
    VLCLibraryRepresentedItem * const representedItem = self.representedItem;
    if (updatedMediaItem == nil || representedItem == nil ||
        ![representedItem.item isKindOfClass:VLCMediaLibraryMediaItem.class]) {
        return;
    }
    VLCMediaLibraryMediaItem * const mediaItem = (VLCMediaLibraryMediaItem *)representedItem.item;
    if (updatedMediaItem.libraryID == mediaItem.libraryID) {
        [self updateRepresentation];
    }
}

- (void)updateRepresentation
{
    VLCLibraryRepresentedItem * const libraryItem = self.representedItem;
    if (libraryItem == nil) {
        return;
    }
    id<VLCMediaLibraryItemProtocol> const actualItem = libraryItem.item;

    self.mediaTitleTextField.stringValue = actualItem.displayString ?: @"";
    self.secondaryInfoTextField.stringValue = actualItem.primaryDetailString ?: @"";
    self.secondaryInfoTextField.hidden = NO;

    __weak typeof(self) weakSelf = self;
    [VLCLibraryImageCache thumbnailForLibraryItem:actualItem
                                   withCompletion:^(NSImage * const thumbnail) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf || strongSelf.representedItem != libraryItem) {
            return;
        }
        strongSelf.mediaImageView.image = thumbnail;
    }];

    if ([actualItem isKindOfClass:VLCMediaLibraryMediaItem.class]) {
        VLCMediaLibraryMediaItem * const mediaItem = (VLCMediaLibraryMediaItem *)actualItem;

        if (mediaItem.mediaType == VLC_ML_MEDIA_TYPE_VIDEO ||
            mediaItem.mediaType == VLC_ML_MEDIA_TYPE_UNKNOWN) {
            VLCMediaLibraryTrack * const videoTrack = mediaItem.firstVideoTrack;
            NSString * const resolutionLabel = videoTrack.resolutionLabel;
            if (resolutionLabel) {
                self.annotationTextField.stringValue = resolutionLabel;
                self.annotationTextField.hidden = NO;
            }
            if (!_videoImageViewAspectRatioConstraint.active) {
                self.imageViewAspectRatioConstraint.active = NO;
                _videoImageViewAspectRatioConstraint.active = YES;
            }
        } else {
            if (_videoImageViewAspectRatioConstraint.active) {
                _videoImageViewAspectRatioConstraint.active = NO;
                self.imageViewAspectRatioConstraint.active = YES;
            }
        }

        const CGFloat position = mediaItem.progress;
        if (position > VLCMediaItemCollectionViewItemMinimalDisplayedProgress &&
            position < VLCMediaItemCollectionViewItemMaximumDisplayedProgress) {
            self.progressIndicator.progress = position;
            self.progressIndicator.hidden = NO;
        }

        if (mediaItem.playCount == 0) {
            [self setUnplayedIndicatorHidden:NO];
        }
    } else {
        self.progressIndicator.hidden = YES;
        if (_videoImageViewAspectRatioConstraint.active) {
            _videoImageViewAspectRatioConstraint.active = NO;
            self.imageViewAspectRatioConstraint.active = YES;
        }
    }
}

- (void)setUnplayedIndicatorHidden:(BOOL)indicatorHidden
{
    if (self.unplayedIndicatorTextField.hidden == indicatorHidden) {
        return;
    }
    self.unplayedIndicatorTextField.hidden = indicatorHidden;
    self.trailingSecondaryTextToLeadingUnplayedIndicatorConstraint.active = !indicatorHidden;
    self.trailingSecondaryTextToTrailingSuperviewConstraint.active = indicatorHidden;
}

#pragma mark - actions

- (void)queueFromSwipe:(NSButton *)sender
{
    VLCLibraryRepresentedItem * const item = sender.cell.representedObject;
    [item queue];
    [_swipeView closeActionsAnimated:YES];
}

- (void)setFavorite:(BOOL)favorite fromSwipeButton:(NSButton *)sender
{
    id<VLCMediaLibraryItemProtocol> const item = sender.cell.representedObject;
    if ([item setFavorite:favorite] == VLC_SUCCESS) {
        [_swipeView closeActionsAnimated:YES];
    }
}

- (void)addFavoriteFromSwipe:(NSButton *)sender
{
    [self setFavorite:YES fromSwipeButton:sender];
}

- (void)removeFavoriteFromSwipe:(NSButton *)sender
{
    [self setFavorite:NO fromSwipeButton:sender];
}

- (IBAction)playInstantly:(id)sender
{
    [self.representedItem play];
}

- (IBAction)addToPlayQueue:(id)sender
{
    [self.representedItem queue];
}

- (void)openContextMenu:(NSEvent *)event
{
    [VLCLibraryCollectionViewSwipeView closeActionsInCollectionView:self.collectionView];
    if (!_menuController) {
        _menuController = [[VLCLibraryMenuController alloc] init];
    }
    NSCollectionView * const collectionView = self.collectionView;
    id const dataSource = collectionView.dataSource;
    Protocol * const vlcDataSourceProtocol = @protocol(VLCLibraryCollectionViewDataSource);
    if (![dataSource conformsToProtocol:vlcDataSourceProtocol]) {
        return;
    }
    NSObject<VLCLibraryCollectionViewDataSource> * const libraryDataSource =
        (NSObject<VLCLibraryCollectionViewDataSource> *)dataSource;
    NSSet<NSIndexPath *> * const indexPaths = collectionView.selectionIndexPaths;
    NSArray<VLCLibraryRepresentedItem *> * const selectedItems =
        [libraryDataSource representedItemsAtIndexPaths:indexPaths
                                      forCollectionView:collectionView];
    const NSInteger representedItemIndex = [selectedItems indexOfObjectPassingTest:^BOOL(
        VLCLibraryRepresentedItem * const repItem, const NSUInteger __unused idx, BOOL * const __unused stop
    ) {
        return [repItem isEqual:self.representedItem];
    }];
    NSArray<VLCLibraryRepresentedItem *> *items = nil;
    if (representedItemIndex == NSNotFound) {
        items = @[self.representedItem];
    } else {
        items = selectedItems;
    }
    _menuController.representedItems = items;
    [_menuController popupMenuWithEvent:event forView:self.view];
}

- (void)mouseDown:(NSEvent *)event
{
    [VLCLibraryCollectionViewSwipeView closeActionsInCollectionView:self.collectionView];
    if (event.modifierFlags & NSEventModifierFlagControl) {
        [self openContextMenu:event];
        return;
    }
    if (self.deselectWhenClickedIfSelected &&
        self.selected &&
        [self.collectionView.dataSource conformsToProtocol:@protocol(VLCLibraryCollectionViewDataSource)]) {
        NSObject<VLCLibraryCollectionViewDataSource> * const libraryDataSource =
            (NSObject<VLCLibraryCollectionViewDataSource> *)self.collectionView.dataSource;
        NSIndexPath * const indexPath = [libraryDataSource indexPathForLibraryItem:self.representedItem.item];
        if (indexPath == nil) {
            NSLog(@"Received nil indexPath for item %@!", self.representedItem.item.displayString);
            [super mouseDown:event];
            return;
        }
        NSSet<NSIndexPath *> * const indexPathSet = [NSSet setWithObject:indexPath];
        [self.collectionView deselectItemsAtIndexPaths:indexPathSet];
        if ([self.collectionView.collectionViewLayout isKindOfClass:[VLCLibraryCollectionViewFlowLayout class]]) {
            VLCLibraryCollectionViewFlowLayout * const flowLayout =
                (VLCLibraryCollectionViewFlowLayout *)self.collectionView.collectionViewLayout;
            [flowLayout collapseDetailSectionAtIndex:indexPath];
        }
    }
    [super mouseDown:event];
}

@end
