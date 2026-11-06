/*****************************************************************************
 * VLCVideoPreferencesController.h: Video preferences
 *****************************************************************************
 * Copyright (C) 2008-2019 VLC authors and VideoLAN
 *
 * Authors: Felix Paul Kühne <fkuehne # videolan dot org>
 *          David Fuhrmann <dfuhrmann # videolan dot org>
 *          Serhii Bykov <esphynox@gmail.com>
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

@interface VLCVideoPreferencesController : NSObject <NSTextFieldDelegate>

@property (readwrite, strong) IBOutlet NSView *view;

@property (readwrite, weak) IBOutlet NSButton *enableCheckbox;
// video pane - display box
@property (readwrite, weak) IBOutlet NSBox *displayBox;
@property (readwrite, weak) IBOutlet NSButton *embeddedCheckbox;
@property (readwrite, weak) IBOutlet NSButton *pauseWhenMinimizedCheckbox;
@property (readwrite, weak) IBOutlet NSButton *onTopCheckbox;
@property (readwrite, weak) IBOutlet NSButton *videodecoCheckbox;
@property (readwrite, weak) IBOutlet NSButton *resizeToNativeSizeCheckbox;
@property (readwrite, weak) IBOutlet NSButton *useClassicLayoutCheckbox;

// video pane - fullscreen box
@property (readwrite, weak) IBOutlet NSBox *fullscreenBox;
@property (readwrite, weak) IBOutlet NSButton *startInFullscreenCheckbox;
@property (readwrite, weak) IBOutlet NSButton *blackScreenCheckbox;
@property (readwrite, weak) IBOutlet NSButton *nativeFullscreenCheckbox;
@property (readwrite, weak) IBOutlet NSTextField *deviceLabel;
@property (readwrite, weak) IBOutlet NSPopUpButton *devicePopup;

// video pane - video box
@property (readwrite, weak) IBOutlet NSBox *videoBox;
@property (readwrite, weak) IBOutlet NSTextField *deinterlaceLabel;
@property (readwrite, weak) IBOutlet NSPopUpButton *deinterlacePopup;
@property (readwrite, weak) IBOutlet NSTextField *deinterlaceModeLabel;
@property (readwrite, weak) IBOutlet NSPopUpButton *deinterlaceModePopup;

// video pane - snapshot box
@property (readwrite, weak) IBOutlet NSBox *snapBox;
@property (readwrite, weak) IBOutlet NSButton *snapFolderButton;
@property (readwrite, weak) IBOutlet NSTextField *snapFolderTextField;
@property (readwrite, weak) IBOutlet NSTextField *snapFolderLabel;
@property (readwrite, weak) IBOutlet NSPopUpButton *snapFormatPopup;
@property (readwrite, weak) IBOutlet NSTextField *snapFormatLabel;
@property (readwrite, weak) IBOutlet NSTextField *snapPrefixTextField;
@property (readwrite, weak) IBOutlet NSTextField *snapPrefixLabel;
@property (readwrite, weak) IBOutlet NSButton *snapSeqnumCheckbox;

- (IBAction)videoSettingChanged:(id)sender;
- (void)setupControls;
- (void)resetControls;
- (void)saveChangedSettings;

@end
