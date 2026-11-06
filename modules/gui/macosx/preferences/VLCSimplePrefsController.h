/*****************************************************************************
 * VLCSimplePrefsController.h: Simple Preferences for Mac OS X
 *****************************************************************************
 * Copyright (C) 2008-2019 VLC authors and VideoLAN
 *
 * Authors: Felix Paul Kühne <fkuehne # videolan dot org>
 *          David Fuhrmann <dfuhrmann # videolan dot org>
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

#import <vlc_common.h>

#import "main/VLCMain.h"

@interface VLCSimplePrefsController : NSWindowController

// Overall window
@property (readwrite, weak) IBOutlet NSButton *showAllButton;
@property (readwrite, weak) IBOutlet NSButton *cancelButton;
@property (readwrite, weak) IBOutlet NSScrollView *scrollView;
@property (readwrite, weak) IBOutlet NSView *contentView;
@property (readwrite, weak) IBOutlet NSButton *resetButton;
@property (readwrite, weak) IBOutlet NSButton *saveButton;

// URL handler popup window
@property (readwrite, strong) IBOutlet NSWindow *urlhandler_win;

@property (readwrite, weak) IBOutlet NSTextField *urlhandler_titleLabel;
@property (readwrite, weak) IBOutlet NSTextField *urlhandler_subtitleLabel;
@property (readwrite, weak) IBOutlet NSButton *urlhandler_saveButton;
@property (readwrite, weak) IBOutlet NSButton *urlhandler_cancelButton;
@property (readwrite, weak) IBOutlet NSPopUpButton *urlhandler_ftpPopup;
@property (readwrite, weak) IBOutlet NSPopUpButton *urlhandler_mmsPopup;
@property (readwrite, weak) IBOutlet NSPopUpButton *urlhandler_rtmpPopup;
@property (readwrite, weak) IBOutlet NSPopUpButton *urlhandler_rtpPopup;
@property (readwrite, weak) IBOutlet NSPopUpButton *urlhandler_rtspPopup;
@property (readwrite, weak) IBOutlet NSPopUpButton *urlhandler_sftpPopup;
@property (readwrite, weak) IBOutlet NSPopUpButton *urlhandler_smbPopup;
@property (readwrite, weak) IBOutlet NSPopUpButton *urlhandler_udpPopup;

/* toolbar */
- (NSToolbarItem *)toolbar:(NSToolbar *)o_toolbar
     itemForItemIdentifier:(NSString *)o_itemIdent
 willBeInsertedIntoToolbar:(BOOL)b_willBeInserted;
- (NSArray *)toolbarDefaultItemIdentifiers:(NSToolbar *)toolbar;
- (NSArray *)toolbarAllowedItemIdentifiers:(NSToolbar *)toolbar;

- (void)showSimplePrefs;
- (void)showSimplePrefsWithLevel:(NSInteger)i_window_level;

- (IBAction)buttonAction:(id)sender;
- (IBAction)resetPreferences:(id)sender;

/* input & codecs */
- (IBAction)urlHandlerAction:(id)sender;

/* hotkeys */

/**
 * Updates right to left UI setting according to currently set language code
 * \return true if specific language was selected and RTL UI settings were updated
 */
+ (BOOL)updateRightToLeftSettings;

@end
