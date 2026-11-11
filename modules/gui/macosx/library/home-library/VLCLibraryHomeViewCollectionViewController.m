/*****************************************************************************
 * VLCLibraryHomeViewCollectionViewController.m: MacOS X interface module
 *****************************************************************************
 * Copyright (C) 2026 VLC authors and VideoLAN
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
 *****************************************************************************/

#import "VLCLibraryHomeViewCollectionViewController.h"

#import "extensions/NSView+VLCAdditions.h"
#import "extensions/NSString+Helpers.h"

#import "library/VLCLibraryCollectionView.h"
#import "library/VLCLibraryCollectionViewDataSource.h"
#import "library/VLCLibraryCollectionViewDelegate.h"
#import "library/VLCLibraryCollectionViewFlowLayout.h"
#import "library/VLCLibraryCollectionViewItem.h"
#import "library/VLCLibraryCollectionViewMediaItemSupplementaryDetailView.h"
#import "library/VLCLibraryCollectionViewSupplementaryElementView.h"
#import "library/VLCLibraryController.h"
#import "library/VLCLibraryDataTypes.h"
#import "library/VLCLibraryHeroView.h"
#import "library/VLCLibraryModel.h"
#import "library/VLCLibraryRepresentedItem.h"

#import "library/home-library/VLCLibraryHomeViewStackViewController.h"
#import "library/home-library/VLCLibraryHomeViewSectionHeaderView.h"
#import "library/VLCLibraryWindow.h"
#import "library/VLCLibraryWindowSplitViewController.h"
#import "library/VLCLibraryWindowNavigationSidebarViewController.h"
#import "library/VLCLibrarySegment.h"


#import "main/VLCMain.h"

#import "views/VLCUIUnits.h"

static NSUserInterfaceItemIdentifier const VLCLibraryHomeSectionsItemIdentifier = @"VLCLibraryHomeSectionsItem";

@class VLCLibraryHomeViewCollectionViewController;

@interface VLCLibraryHomeSectionsItem : NSCollectionViewItem
- (void)setContentView:(NSView *)contentView;
@end

@interface VLCLibraryHomeViewCollectionDataSource : NSObject <VLCLibraryCollectionViewDataSource>
@property (nonatomic, weak) VLCLibraryHomeViewCollectionViewController *owner;
@property (nonatomic) NSArray<VLCMediaLibraryMediaItem *> *items;
@property (nonatomic) BOOL connected;
@property (nonatomic) NSUInteger reloadGeneration;
@property (nonatomic) BOOL reloadPending;
- (void)reloadData;
- (void)reloadDataForMediaItem:(VLCMediaLibraryMediaItem *)mediaItem;
- (void)deleteDataForMediaItem:(VLCMediaLibraryMediaItem *)mediaItem;
@end

@interface VLCLibraryHomeViewCollectionDelegate : VLCLibraryCollectionViewDelegate
@property (nonatomic, weak) VLCLibraryHomeViewCollectionViewController *owner;
@end

@interface VLCLibraryHomeViewCollectionViewController ()
@property (readwrite) VLCLibraryCollectionView *collectionView;
@property (readonly) VLCLibraryHomeViewCollectionDataSource *dataSource;
@property (readonly) VLCLibraryHomeViewCollectionDelegate *delegate;
@property (readonly) VLCLibraryModel *libraryModel;
@property (readonly) NSStackView *homeSectionsStackView;
@property (readonly) NSLayoutConstraint *homeSectionsWidthConstraint;
@property (readonly) VLCLibraryHomeViewStackViewController *homeSectionsController;
@end

@implementation VLCLibraryHomeViewCollectionViewController

- (instancetype)initWithScrollView:(NSScrollView *)scrollView
{
    self = [super init];
    if (self) {
        _libraryModel = VLCMain.sharedInstance.libraryController.libraryModel;
        _homeSectionsStackView = [NSStackView stackViewWithViews:@[]];
        _homeSectionsStackView.translatesAutoresizingMaskIntoConstraints = NO;
        _homeSectionsWidthConstraint = [_homeSectionsStackView.widthAnchor constraintEqualToConstant:1];
        _homeSectionsWidthConstraint.priority = NSLayoutPriorityDefaultHigh;
        _homeSectionsWidthConstraint.active = YES;
        _homeSectionsController = [[VLCLibraryHomeViewStackViewController alloc] init];
        _homeSectionsController.collectionsStackView = _homeSectionsStackView;

        VLCLibraryCollectionViewFlowLayout *layout = VLCLibraryCollectionViewFlowLayout.standardLayout;
        layout.headerReferenceSize = VLCLibraryCollectionViewSupplementaryElementView.defaultHeaderSize;
        _collectionView = [[VLCLibraryCollectionView alloc] initWithFrame:NSZeroRect];
        _collectionView.collectionViewLayout = layout;
        _collectionView.selectable = YES;
        _collectionView.allowsEmptySelection = YES;
        _collectionView.allowsMultipleSelection = YES;

        _delegate = [[VLCLibraryHomeViewCollectionDelegate alloc] init];
        _delegate.owner = self;
        _collectionView.delegate = _delegate;

        _dataSource = [[VLCLibraryHomeViewCollectionDataSource alloc] init];
        _dataSource.owner = self;
        _collectionView.dataSource = _dataSource;

        [_collectionView registerClass:VLCLibraryHomeSectionsItem.class
                forItemWithIdentifier:VLCLibraryHomeSectionsItemIdentifier];
        [_collectionView registerClass:VLCLibraryCollectionViewItem.class
                forItemWithIdentifier:VLCLibraryCollectionViewItemIdentifier];
        [_collectionView registerClass:VLCLibraryHomeViewSectionHeaderView.class
     forSupplementaryViewOfKind:NSCollectionElementKindSectionHeader
                   withIdentifier:VLCLibrarySupplementaryElementViewIdentifier];
        NSNib *detailViewNib = [[NSNib alloc] initWithNibNamed:@"VLCLibraryCollectionViewMediaItemSupplementaryDetailView" bundle:nil];
        [_collectionView registerNib:detailViewNib
          forSupplementaryViewOfKind:VLCLibraryCollectionViewMediaItemSupplementaryDetailViewKind
                    withIdentifier:VLCLibraryCollectionViewMediaItemSupplementaryDetailViewIdentifier];

        // The collection view, not an inner grid scroll view, is the document view.
        scrollView.documentView = _collectionView;
        [self connect];
    }
    return self;
}

- (void)dealloc
{
    [self disconnect];
}

- (void)connect
{
    if (self.dataSource.connected) {
        return;
    }
    self.dataSource.connected = YES;
    NSNotificationCenter *center = NSNotificationCenter.defaultCenter;
    for (NSString *name in @[VLCLibraryModelVideoMediaListReset,
                             VLCLibraryModelAllCachesDropped]) {
        [center addObserver:self selector:@selector(libraryContentsChanged:) name:name object:nil];
    }
    for (NSString *name in @[VLCLibraryModelRecentsMediaListReset,
                             VLCLibraryModelRecentAudioMediaListReset,
                             VLCLibraryModelRecentsMediaItemDeleted,
                             VLCLibraryModelRecentAudioMediaItemDeleted,
                             VLCLibraryBookmarkedLocationsChanged,
                             NSUserDefaultsDidChangeNotification]) {
        [center addObserver:self selector:@selector(leadingContentsChanged:) name:name object:nil];
    }
    [center addObserver:self selector:@selector(libraryItemUpdated:)
                   name:VLCLibraryModelVideoMediaItemUpdated object:nil];
    [center addObserver:self selector:@selector(libraryItemDeleted:)
                   name:VLCLibraryModelVideoMediaItemDeleted object:nil];
    [self reloadData];
    [self.homeSectionsController connectContainers];
}

- (void)disconnect
{
    if (!self.dataSource.connected) {
        return;
    }
    self.dataSource.connected = NO;
    [NSNotificationCenter.defaultCenter removeObserver:self];
    self.dataSource.reloadGeneration++;
    self.dataSource.reloadPending = NO;
    [self.homeSectionsController disconnectContainers];
}

- (void)openVideoLibrary:(id)sender
{
    [VLCMain.sharedInstance.libraryWindow.splitViewController.navSidebarViewController
        selectSegment:VLCLibraryVideoSegmentType];
}

- (void)libraryContentsChanged:(NSNotification *)notification
{
    if (!NSThread.isMainThread) {
        dispatch_async(dispatch_get_main_queue(), ^{ [self libraryContentsChanged:notification]; });
        return;
    }
    [self.homeSectionsController reloadData];
    [self reloadData];
}

- (void)leadingContentsChanged:(NSNotification *)notification
{
    // Let the existing Home containers process the notification before
    // measuring their new fitting size.
    dispatch_async(dispatch_get_main_queue(), ^{
        if (!self.dataSource.connected) {
            return;
        }
        [self.collectionView.collectionViewLayout invalidateLayout];
    });
}

- (void)libraryItemUpdated:(NSNotification *)notification
{
    if (!NSThread.isMainThread) {
        dispatch_async(dispatch_get_main_queue(), ^{ [self libraryItemUpdated:notification]; });
        return;
    }
    BOOL reloadPending = self.dataSource.reloadPending;
    self.dataSource.reloadGeneration++;
    [self.dataSource reloadDataForMediaItem:notification.object];
    if (reloadPending) {
        [self.dataSource reloadData];
    }
}

- (void)libraryItemDeleted:(NSNotification *)notification
{
    if (!NSThread.isMainThread) {
        dispatch_async(dispatch_get_main_queue(), ^{ [self libraryItemDeleted:notification]; });
        return;
    }
    BOOL reloadPending = self.dataSource.reloadPending;
    self.dataSource.reloadGeneration++;
    [self.dataSource deleteDataForMediaItem:notification.object];
    if (reloadPending) {
        [self.dataSource reloadData];
    }
}

- (void)reloadData
{
    [self.dataSource reloadData];
    [self.collectionView.collectionViewLayout invalidateLayout];
}

- (void)presentLibraryItem:(id<VLCMediaLibraryItemProtocol>)libraryItem
{
    if (libraryItem == nil) {
        return;
    }
    const NSUInteger index = [self.dataSource.items indexOfObjectPassingTest:^BOOL(VLCMediaLibraryMediaItem *item, NSUInteger __unused idx, BOOL *__unused stop) {
        return item.libraryID == libraryItem.libraryID;
    }];
    if (index != NSNotFound) {
        NSIndexPath *indexPath = [NSIndexPath indexPathForItem:index inSection:1];
        [self.collectionView selectItemsAtIndexPaths:[NSSet setWithObject:indexPath]
                                     scrollPosition:NSCollectionViewScrollPositionCenteredVertically];
        [(VLCLibraryCollectionViewFlowLayout *)self.collectionView.collectionViewLayout expandDetailSectionAtIndex:indexPath];
    }
}

@end

@implementation VLCLibraryHomeViewCollectionDataSource

- (void)reloadData
{
    if (!self.connected) {
        return;
    }
    const NSUInteger generation = ++self.reloadGeneration;
    self.reloadPending = YES;
    __weak typeof(self) weakSelf = self;
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        NSArray<VLCMediaLibraryMediaItem *> *items = VLCMain.sharedInstance.libraryController.libraryModel.listOfVideoMedia ?: @[];
        dispatch_async(dispatch_get_main_queue(), ^{
            if (!weakSelf.connected || weakSelf.reloadGeneration != generation) {
                return;
            }
            weakSelf.reloadPending = NO;
            weakSelf.items = items;
            [weakSelf.owner.collectionView.collectionViewLayout invalidateLayout];
            [weakSelf.owner.collectionView reloadData];
        });
    });
}

- (void)reloadDataForMediaItem:(VLCMediaLibraryMediaItem *)mediaItem
{
    if (mediaItem == nil) {
        return;
    }
    const NSUInteger index = [self.items indexOfObjectPassingTest:^BOOL(VLCMediaLibraryMediaItem *item, NSUInteger __unused idx, BOOL *__unused stop) {
        return item.libraryID == mediaItem.libraryID;
    }];
    if (index == NSNotFound) {
        return;
    }
    NSMutableArray *items = self.items.mutableCopy;
    items[index] = mediaItem;
    self.items = items;
    [self.owner.collectionView reloadItemsAtIndexPaths:[NSSet setWithObject:[NSIndexPath indexPathForItem:index inSection:1]]];
}

- (void)deleteDataForMediaItem:(VLCMediaLibraryMediaItem *)mediaItem
{
    if (mediaItem == nil) {
        return;
    }
    const NSUInteger index = [self.items indexOfObjectPassingTest:^BOOL(VLCMediaLibraryMediaItem *item, NSUInteger __unused idx, BOOL *__unused stop) {
        return item.libraryID == mediaItem.libraryID;
    }];
    if (index == NSNotFound) {
        return;
    }
    NSMutableArray *items = self.items.mutableCopy;
    [items removeObjectAtIndex:index];
    self.items = items;
    [self.owner.collectionView deleteItemsAtIndexPaths:[NSSet setWithObject:[NSIndexPath indexPathForItem:index inSection:1]]];
    for (NSIndexPath *headerPath in [self.owner.collectionView indexPathsForVisibleSupplementaryElementsOfKind:NSCollectionElementKindSectionHeader]) {
        if (headerPath.section == 1) {
            VLCLibraryHomeViewSectionHeaderView *header = (id)[self.owner.collectionView supplementaryViewForElementKind:NSCollectionElementKindSectionHeader atIndexPath:headerPath];
            header.itemCount = self.items.count;
        }
    }
}

- (NSInteger)numberOfSectionsInCollectionView:(NSCollectionView *)collectionView
{
    return 2;
}

- (NSInteger)collectionView:(NSCollectionView *)collectionView numberOfItemsInSection:(NSInteger)section
{
    return section == 0 ? 1 : self.items.count;
}

- (NSCollectionViewItem *)collectionView:(NSCollectionView *)collectionView itemForRepresentedObjectAtIndexPath:(NSIndexPath *)indexPath
{
    if (indexPath.section == 0) {
        VLCLibraryHomeSectionsItem *item = [collectionView makeItemWithIdentifier:VLCLibraryHomeSectionsItemIdentifier forIndexPath:indexPath];
        [item setContentView:self.owner.homeSectionsStackView];
        return item;
    }

    VLCLibraryCollectionViewItem *item = [collectionView makeItemWithIdentifier:VLCLibraryCollectionViewItemIdentifier forIndexPath:indexPath];
    VLCMediaLibraryMediaItem *mediaItem = self.items[indexPath.item];
    item.representedItem = [[VLCLibraryRepresentedItem alloc] initWithItem:mediaItem parentType:VLCMediaLibraryParentGroupTypeVideoLibrary];
    return item;
}

- (NSView *)collectionView:(NSCollectionView *)collectionView viewForSupplementaryElementOfKind:(NSCollectionViewSupplementaryElementKind)kind atIndexPath:(NSIndexPath *)indexPath
{
    if (indexPath.section != 1 || ![kind isEqualToString:NSCollectionElementKindSectionHeader]) {
        if (indexPath.section != 1 || ![kind isEqualToString:VLCLibraryCollectionViewMediaItemSupplementaryDetailViewKind]) {
            return nil;
        }
        VLCLibraryCollectionViewMediaItemSupplementaryDetailView *detailView =
            [collectionView makeSupplementaryViewOfKind:kind
                                         withIdentifier:VLCLibraryCollectionViewMediaItemSupplementaryDetailViewIdentifier
                                           forIndexPath:indexPath];
        VLCMediaLibraryMediaItem *mediaItem = self.items[indexPath.item];
        detailView.representedItem = [[VLCLibraryRepresentedItem alloc] initWithItem:mediaItem parentType:VLCMediaLibraryParentGroupTypeVideoLibrary];
        detailView.selectedItem = [collectionView itemAtIndexPath:indexPath];
        detailView.layoutScrollDirection = ((VLCLibraryCollectionViewFlowLayout *)collectionView.collectionViewLayout).scrollDirection;
        return detailView;
    }
    VLCLibraryHomeViewSectionHeaderView *header = [collectionView makeSupplementaryViewOfKind:kind withIdentifier:VLCLibrarySupplementaryElementViewIdentifier forIndexPath:indexPath];
    header.title = _NS("Library");
    header.itemCount = self.items.count;
    header.libraryButton.target = self.owner;
    header.libraryButton.action = @selector(openVideoLibrary:);
    return header;
}

- (id<VLCMediaLibraryItemProtocol>)libraryItemAtIndexPath:(NSIndexPath *)indexPath forCollectionView:(NSCollectionView *)collectionView
{
    return indexPath.section == 1 && indexPath.item >= 0 && (NSUInteger)indexPath.item < self.items.count ? self.items[indexPath.item] : nil;
}

- (NSIndexPath *)indexPathForLibraryItem:(id<VLCMediaLibraryItemProtocol>)libraryItem
{
    const NSUInteger index = [self.items indexOfObjectPassingTest:^BOOL(VLCMediaLibraryMediaItem *item, NSUInteger __unused idx, BOOL *__unused stop) {
        return item.libraryID == libraryItem.libraryID;
    }];
    return index == NSNotFound ? nil : [NSIndexPath indexPathForItem:index inSection:1];
}

- (NSArray<VLCLibraryRepresentedItem *> *)representedItemsAtIndexPaths:(NSSet<NSIndexPath *> *)indexPaths forCollectionView:(NSCollectionView *)collectionView
{
    NSMutableArray *representedItems = [NSMutableArray arrayWithCapacity:indexPaths.count];
    for (NSIndexPath *indexPath in indexPaths) {
        id<VLCMediaLibraryItemProtocol> item = [self libraryItemAtIndexPath:indexPath forCollectionView:collectionView];
        if (item != nil) {
            [representedItems addObject:[[VLCLibraryRepresentedItem alloc] initWithItem:item parentType:VLCMediaLibraryParentGroupTypeVideoLibrary]];
        }
    }
    return representedItems;
}

- (NSString *)supplementaryDetailViewKind
{
    return VLCLibraryCollectionViewMediaItemSupplementaryDetailViewKind;
}

@end

@implementation VLCLibraryHomeViewCollectionDelegate

- (NSSize)collectionView:(NSCollectionView *)collectionView layout:(NSCollectionViewLayout *)layout sizeForItemAtIndexPath:(NSIndexPath *)indexPath
{
    const CGFloat width = MAX(collectionView.bounds.size.width - VLCUIUnits.collectionViewSectionInsets.left - VLCUIUnits.collectionViewSectionInsets.right, 1);
    if (indexPath.section == 0) {
        self.owner.homeSectionsWidthConstraint.constant = width;
        [self.owner.homeSectionsStackView layoutSubtreeIfNeeded];
        return NSMakeSize(width, MAX(self.owner.homeSectionsStackView.fittingSize.height, 1));
    }
    return [VLCUIUnits adjustedCollectionViewItemSizeForCollectionView:collectionView
                                                            withLayout:(VLCLibraryCollectionViewFlowLayout *)layout
                                                  withItemsAspectRatio:VLCLibraryCollectionViewItemAspectRatioVideoItem];
}

- (NSSize)collectionView:(NSCollectionView *)collectionView layout:(NSCollectionViewLayout *)layout referenceSizeForHeaderInSection:(NSInteger)section
{
    return section == 1 ? VLCLibraryCollectionViewSupplementaryElementView.defaultHeaderSize : NSZeroSize;
}

- (NSSet<NSIndexPath *> *)collectionView:(NSCollectionView *)collectionView shouldSelectItemsAtIndexPaths:(NSSet<NSIndexPath *> *)indexPaths
{
    NSMutableSet *selectable = [indexPaths mutableCopy];
    [selectable minusSet:[indexPaths filteredSetUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(NSIndexPath *path, NSDictionary *__unused bindings) {
        return path.section == 0;
    }]]];
    return selectable;
}

@end

@implementation VLCLibraryHomeSectionsItem

- (void)loadView
{
    self.view = [[NSView alloc] initWithFrame:NSZeroRect];
}

- (void)setContentView:(NSView *)contentView
{
    if (contentView.superview == self.view) {
        return;
    }
    [contentView removeFromSuperview];
    [self.view addSubview:contentView];
    [contentView applyConstraintsToFillSuperview];
}

@end
