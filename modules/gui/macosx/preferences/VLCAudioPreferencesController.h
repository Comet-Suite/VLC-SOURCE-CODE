/*****************************************************************************
 * VLCAudioPreferencesController.h: Audio preferences
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

@interface VLCAudioPreferencesController : NSObject <VLCSimplePreferencesPane, NSTextFieldDelegate>

@property (readwrite, strong) IBOutlet NSView *view;

@property (readwrite, weak) IBOutlet NSBox *effectsBox;
@property (readwrite, weak) IBOutlet NSButton *enableCheckbox;
@property (readwrite, weak) IBOutlet NSBox *generalBox;
@property (readwrite, weak) IBOutlet NSTextField *langTextField;
@property (readwrite, weak) IBOutlet NSTextField *langLabel;
@property (readwrite, weak) IBOutlet NSBox *lastBox;
@property (readwrite, weak) IBOutlet NSButton *lastCheckbox;
@property (readwrite, weak) IBOutlet NSSecureTextField *lastpwdSecureTextField;
@property (readwrite, weak) IBOutlet NSTextField *lastpwdLabel;
@property (readwrite, weak) IBOutlet NSTextField *lastuserTextField;
@property (readwrite, weak) IBOutlet NSTextField *lastuserLabel;
@property (readwrite, weak) IBOutlet NSPopUpButton *visualPopup;
@property (readwrite, weak) IBOutlet NSTextField *visualLabel;
@property (readwrite, weak) IBOutlet NSTextField *volTextField;
@property (readwrite, weak) IBOutlet NSSlider *volSlider;
@property (readwrite, weak) IBOutlet NSMatrix *autosavevolMatrix;
@property (readwrite, weak) IBOutlet NSButtonCell *autosavevolYesButtonCell;
@property (readwrite, weak) IBOutlet NSButtonCell *autosavevolNoButtonCell;

- (IBAction)audioSettingChanged:(id)sender;

@end
