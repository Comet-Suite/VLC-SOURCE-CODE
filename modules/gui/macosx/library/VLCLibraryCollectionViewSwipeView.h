/*****************************************************************************
 * VLCLibraryCollectionViewSwipeView.h: MacOS X interface module
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

#import <Cocoa/Cocoa.h>

NS_ASSUME_NONNULL_BEGIN

@interface VLCLibraryCollectionViewSwipeView : NSView

- (instancetype)initWithContentView:(NSView *)contentView;

@property (readonly, strong, nonatomic) NSView *contentView;
@property (readonly, copy, nonatomic) NSArray<NSButton *> *leadingButtons;
@property (readonly, copy, nonatomic) NSArray<NSButton *> *trailingButtons;
@property (readwrite, weak, nonatomic, nullable) NSCollectionView *collectionView;
@property (readwrite, copy, nonatomic, nullable) dispatch_block_t willRevealActions;
@property (readonly, nonatomic) BOOL actionsVisible;

// The button arrays follow the interface's layout direction.
- (void)setLeadingButtons:(NSArray<NSButton *> *)leadingButtons
          trailingButtons:(NSArray<NSButton *> *)trailingButtons;
- (void)closeActionsAnimated:(BOOL)animated;
+ (BOOL)closeActionsInCollectionView:(nullable NSCollectionView *)collectionView;

@end

NS_ASSUME_NONNULL_END
