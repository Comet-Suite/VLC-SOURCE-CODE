/*****************************************************************************
 * VLCInputPreferencesController.h: Input and codecs preferences
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

@interface VLCInputPreferencesController : NSObject <VLCSimplePreferencesPane, NSTextFieldDelegate>

@property (readwrite, strong) IBOutlet NSView *view;

@property (readwrite, weak) IBOutlet NSBox *recordBox;
@property (readwrite, weak) IBOutlet NSTextField *recordTextField;
@property (readwrite, weak) IBOutlet NSButton *recordButton;
@property (readwrite, weak) IBOutlet NSPopUpButton *aviPopup;
@property (readwrite, weak) IBOutlet NSTextField *aviLabel;
@property (readwrite, weak) IBOutlet NSPopUpButton *cachelevelPopup;
@property (readwrite, weak) IBOutlet NSTextField *cachelevelLabel;
@property (readwrite, weak) IBOutlet NSTextField *cachelevelCustomLabel;
@property (readwrite, weak) IBOutlet NSBox *cachingBox;
@property (readwrite, weak) IBOutlet NSBox *muxBox;
@property (readwrite, weak) IBOutlet NSBox *netBox;
@property (readwrite, weak) IBOutlet NSButton *hardwareAccelerationCheckbox;
@property (readwrite, weak) IBOutlet NSTextField *skipLoopLabel;
@property (readwrite, weak) IBOutlet NSPopUpButton *skipLoopPopup;
@property (readwrite, weak) IBOutlet NSButton *urlhandlerButton;
@property (readwrite, weak) IBOutlet NSButton *fastSeekCheckbox;

// URL handler popup window
@property (readwrite, strong) IBOutlet NSWindow *urlhandlerWindow;

@property (readwrite, weak) IBOutlet NSTextField *urlhandlerTitleLabel;
@property (readwrite, weak) IBOutlet NSTextField *urlhandlerSubtitleLabel;
@property (readwrite, weak) IBOutlet NSButton *urlhandlerSaveButton;
@property (readwrite, weak) IBOutlet NSButton *urlhandlerCancelButton;
@property (readwrite, weak) IBOutlet NSPopUpButton *urlhandlerFtpPopup;
@property (readwrite, weak) IBOutlet NSPopUpButton *urlhandlerMmsPopup;
@property (readwrite, weak) IBOutlet NSPopUpButton *urlhandlerRtmpPopup;
@property (readwrite, weak) IBOutlet NSPopUpButton *urlhandlerRtpPopup;
@property (readwrite, weak) IBOutlet NSPopUpButton *urlhandlerRtspPopup;
@property (readwrite, weak) IBOutlet NSPopUpButton *urlhandlerSftpPopup;
@property (readwrite, weak) IBOutlet NSPopUpButton *urlhandlerSmbPopup;
@property (readwrite, weak) IBOutlet NSPopUpButton *urlhandlerUdpPopup;

- (IBAction)urlHandlerAction:(id)sender;
- (IBAction)inputSettingChanged:(id)sender;

@end
