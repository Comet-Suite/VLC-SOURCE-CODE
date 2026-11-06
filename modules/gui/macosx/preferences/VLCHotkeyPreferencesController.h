/*****************************************************************************
 * VLCHotkeyPreferencesController.h: Hotkey preferences
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
#import "VLCSimplePreferencesPane.h"
#import "VLCHotkeyChangeWindow.h"

@interface VLCHotkeyPreferencesController : NSObject <VLCSimplePreferencesPane, NSTableViewDataSource, VLCHotkeyChangeWindowDelegate>

@property (readwrite, strong) IBOutlet NSView *view;
@property (readwrite, strong) IBOutlet VLCHotkeyChangeWindow *changeWindow;
@property (readwrite, weak) IBOutlet NSTextField *changeLabel;
@property (readwrite, weak) IBOutlet NSTextField *changeKeysLabel;
@property (readwrite, weak) IBOutlet NSTextField *changeTakenLabel;
@property (readwrite, weak) IBOutlet NSTextField *descriptionLabel;
@property (readwrite, weak) IBOutlet NSButton *changeCancelButton;
@property (readwrite, weak) IBOutlet NSButton *changeOKButton;
@property (readwrite, weak) IBOutlet NSButton *changeClearButton;
@property (readwrite, weak) IBOutlet NSTableView *listbox;
@property (readwrite, weak) IBOutlet NSButton *mediaKeysCheckbox;


@end
