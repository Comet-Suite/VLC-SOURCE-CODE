/*****************************************************************************
 * VLCSubtitlesPreferencesController.h: Subtitle preferences
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

@interface VLCSubtitlesPreferencesController : NSObject <NSTextFieldDelegate, NSWindowDelegate>

@property (readwrite, strong) IBOutlet NSView *view;

@property (readwrite, weak) IBOutlet NSPopUpButton *encodingPopup;
@property (readwrite, weak) IBOutlet NSTextField *encodingLabel;
@property (readwrite, weak) IBOutlet NSBox *fontBox;
@property (readwrite, weak) IBOutlet NSButton *fontButton;
@property (readwrite, weak) IBOutlet NSPopUpButton *fontColorPopup;
@property (readwrite, weak) IBOutlet NSTextField *fontColorLabel;
@property (readwrite, weak) IBOutlet NSTextField *fontTextField;
@property (readwrite, weak) IBOutlet NSSlider *fontSizeSlider;
@property (readwrite, weak) IBOutlet NSTextField *fontSizeTextField;
@property (readwrite, weak) IBOutlet NSTextField *fontSizeLabel;
@property (readwrite, weak) IBOutlet NSTextField *fontLabel;
@property (readwrite, weak) IBOutlet NSBox *langBox;
@property (readwrite, weak) IBOutlet NSTextField *langTextField;
@property (readwrite, weak) IBOutlet NSTextField *langLabel;
@property (readwrite, weak) IBOutlet NSTextField *opacityLabel;
@property (readwrite, weak) IBOutlet NSTextField *opacityTextField;
@property (readwrite, weak) IBOutlet NSSlider *opacitySlider;
@property (readwrite, weak) IBOutlet NSPopUpButton *outlineColorPopup;
@property (readwrite, weak) IBOutlet NSTextField *outlineColorLabel;
@property (readwrite, weak) IBOutlet NSPopUpButton *outlineThicknessPopup;
@property (readwrite, weak) IBOutlet NSTextField *outlineThicknessLabel;
@property (readwrite, weak) IBOutlet NSButton *forceboldCheckbox;
@property (readwrite, weak) IBOutlet NSBox *osdBox;
@property (readwrite, weak) IBOutlet NSButton *osdCheckbox;

- (IBAction)osdSettingChanged:(id)sender;
- (IBAction)showFontPicker:(id)sender;
- (void)setupControls;
- (void)resetControls;
- (void)saveChangedSettings;
- (void)closeFontPanel;

@end
