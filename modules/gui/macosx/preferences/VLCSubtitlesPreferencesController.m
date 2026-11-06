/*****************************************************************************
 * VLCSubtitlesPreferencesController.m: Subtitle preferences
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

#ifdef HAVE_CONFIG_H
# include "config.h"
#endif

#import "VLCSubtitlesPreferencesController.h"
#import "VLCPreferencesControlHelper.h"
#import <vlc_common.h>
#import <vlc_configuration.h>
#import "extensions/NSString+Helpers.h"

static void saveIntList(NSPopUpButton *object, const char *name)
{
    NSNumber *value = object.selectedItem.representedObject;
    if (value)
        config_PutInt(name, value.intValue);
}

static void saveStringList(NSPopUpButton *object, const char *name)
{
    NSString *value = object.selectedItem.representedObject;
    if (value)
        config_PutPsz(name, value.UTF8String);
}

@implementation VLCSubtitlesPreferencesController
{
    BOOL _osdSettingChanged;
}

- (void)setupControls
{
    /* Subtitles and OSD */
    [_encodingLabel setStringValue: _NS("Default Encoding")];
    [_fontBox setTitle: _NS("Display Settings")];
    [_fontButton setTitle: _NS("Choose...")];
    [_fontColorLabel setStringValue: _NS("Font color")];
    [_fontSizeLabel setStringValue: _NS("Font size")];
    [_fontLabel setStringValue: _NS("Font")];
    [_langBox setTitle: _NS("Subtitle languages")];
    [_langLabel setStringValue: _NS("Preferred subtitle language")];
    [_osdBox setTitle: _NS("On Screen Display")];
    [_osdCheckbox setTitle: _NS("Enable OSD")];
    [_opacityLabel setStringValue: _NS("Opacity")];
    [_forceboldCheckbox setTitle: _NS("Force bold")];
    [_outlineColorLabel setStringValue: _NS("Outline color")];
    [_outlineThicknessLabel setStringValue: _NS("Outline thickness")];
}

- (void)resetControls
{
    [VLCPreferencesControlHelper setupButton:_osdCheckbox forBoolValue: "osd"];

    [VLCPreferencesControlHelper setupButton:_encodingPopup forStringList: "subsdec-encoding"];
    [VLCPreferencesControlHelper setupField:_langTextField forOption: "sub-language" ];

    [VLCPreferencesControlHelper setupField:_fontTextField forOption: "freetype-font"];
    [VLCPreferencesControlHelper setupButton:_fontColorPopup forIntList: "freetype-color"];
    _fontSizeSlider.intValue = (int)config_GetInt("sub-text-scale");
    [_fontSizeTextField setStringValue: [NSString stringWithFormat:@"%.2fx", _fontSizeSlider.intValue / 100.]];
    int i = config_GetInt("freetype-opacity") * 100.0 / 255.0 + 0.5;
    [_opacityTextField setIntValue: i];
    [_opacitySlider setIntValue: i];
    [_opacitySlider setToolTip: NSTR(config_GetLabel("freetype-opacity"))];
    [_opacityTextField setToolTip: [_opacitySlider toolTip]];
    [VLCPreferencesControlHelper setupButton:_forceboldCheckbox forBoolValue: "freetype-bold"];
    [VLCPreferencesControlHelper setupButton:_outlineColorPopup forIntList: "freetype-outline-color"];
    [VLCPreferencesControlHelper setupButton:_outlineThicknessPopup forIntList: "freetype-outline-thickness"];
}

- (void)saveChangedSettings
{
    if (_osdSettingChanged) {
        config_PutInt("osd", [_osdCheckbox state]);

        if ([_encodingPopup indexOfSelectedItem] >= 0)
            saveStringList(_encodingPopup, "subsdec-encoding");
        else
            config_PutPsz("subsdec-encoding", "");

        config_PutPsz("sub-language", [[_langTextField stringValue] UTF8String]);

        config_PutPsz("freetype-font", [[_fontTextField stringValue] UTF8String]);
        saveIntList(_fontColorPopup, "freetype-color");
        config_PutInt("sub-text-scale", _fontSizeSlider.intValue);
        config_PutInt("freetype-opacity", [_opacityTextField intValue] * 255.0 / 100.0 + 0.5);
        config_PutInt("freetype-bold", [_forceboldCheckbox state]);
        saveIntList(_outlineColorPopup, "freetype-outline-color");
        saveIntList(_outlineThicknessPopup, "freetype-outline-thickness");
        _osdSettingChanged = NO;
    }
}

- (IBAction)osdSettingChanged:(id)sender
{
    if (sender == _opacityTextField) {
        [_opacitySlider setIntValue: [_opacityTextField intValue]];
    } else if (sender == _opacitySlider) {
        [_opacityTextField setIntValue: [_opacitySlider intValue]];
    } else if (sender == _fontSizeSlider) {
        [_fontSizeTextField setStringValue: [NSString stringWithFormat:@"%.2fx", _fontSizeSlider.intValue / 100.]];
    }

    _osdSettingChanged = YES;
}

- (void)controlTextDidChange:(NSNotification *)notification
{
    _osdSettingChanged = YES;
}

- (IBAction)showFontPicker:(id)sender
{
    char * font = config_GetPsz("freetype-font");
    NSString * fontName = font ? toNSStr(font) : nil;
    free(font);
    if (fontName) {
        NSFont * font = [NSFont fontWithName:fontName size:0.0];
        [[NSFontManager sharedFontManager] setSelectedFont:font isMultiple:NO];
    }
    [[NSFontManager sharedFontManager] setTarget: self];
    [[NSFontPanel sharedFontPanel] setDelegate:self];
    [[NSFontPanel sharedFontPanel] makeKeyAndOrderFront:self];
}

- (void)changeFont:(id)sender
{
    NSFont *someFont = [NSFont systemFontOfSize:12];

    // converts given font to changes in font panel. Original font is irrelevant
    NSFont *selectedFont = [sender convertFont:someFont];

    [_fontTextField setStringValue:[selectedFont fontName]];
    [self osdSettingChanged:self];
}

// NSFontPanelModeMask is replacing NSUInteger, and should be backwards compatible
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wunguarded-availability-new"
- (NSFontPanelModeMask)validModesForFontPanel:(NSFontPanel *)fontPanel
{
    return NSFontPanelFaceModeMask | NSFontPanelCollectionModeMask;
}
#pragma clang diagnostic pop

- (void)closeFontPanel
{
    [[NSFontPanel sharedFontPanel] close];
}

@end
