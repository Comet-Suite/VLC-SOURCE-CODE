/*****************************************************************************
 * VLCInterfacePreferencesController.h: Interface preferences
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

@interface VLCInterfacePreferencesController : NSObject <NSTextFieldDelegate>

// intf pane - general box
@property (readwrite, strong) IBOutlet NSView *view;

@property (readwrite, weak) IBOutlet NSBox *generalSettingsBox;
@property (readwrite, weak) IBOutlet NSPopUpButton *languagePopup;
@property (readwrite, weak) IBOutlet NSTextField *languageLabel;
@property (readwrite, weak) IBOutlet NSButton *statusIconCheckbox;
@property (readwrite, weak) IBOutlet NSButton *displayTrackNumberPlayQueueCheckBox;

// intf pane - control box
@property (readwrite, weak) IBOutlet NSBox *playbackControlBox;
@property (readwrite, weak) IBOutlet NSTextField *continueplaybackLabel;
@property (readwrite, weak) IBOutlet NSPopUpButton *continueplaybackPopup;
@property (readwrite, weak) IBOutlet NSButton *displayEndOfPlaybackViewCheckBox;

// intf pane - behaviour box
@property (readwrite, weak) IBOutlet NSBox *playbackBehaviourBox;
@property (readwrite, weak) IBOutlet NSButton *enableNotificationsCheckbox;
@property (readwrite, weak) IBOutlet NSTextField *pauseitunesLabel;
@property (readwrite, weak) IBOutlet NSPopUpButton *pauseitunesPopup;

// intf pane - network box
@property (readwrite, weak) IBOutlet NSBox *networkBox;
@property (readwrite, weak) IBOutlet NSButton *artCheckbox;
@property (readwrite, weak) IBOutlet NSButton *updateCheckbox;
@property (readwrite, weak) IBOutlet NSTextField *lastUpdateLabel;

// intf pane - http interface box
@property (readwrite, weak) IBOutlet NSBox *luahttpBox;
@property (readwrite, weak) IBOutlet NSButton *enableluahttpCheckbox;
@property (readwrite, weak) IBOutlet NSTextField *luahttppwdLabel;
@property (readwrite, weak) IBOutlet NSTextField *luahttppwdTextField;

- (IBAction)interfaceSettingChanged:(id)sender;
- (void)setupControls;
- (void)resetControls;
- (void)saveChangedSettings;
+ (BOOL)updateRightToLeftSettings;

@end
