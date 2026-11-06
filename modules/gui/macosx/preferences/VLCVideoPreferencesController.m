/*****************************************************************************
 * VLCVideoPreferencesController.m: Video preferences
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

#import "VLCVideoPreferencesController.h"
#import "VLCPreferencesControlHelper.h"
#import <vlc_common.h>
#import <vlc_configuration.h>
#import "extensions/NSScreen+VLCAdditions.h"
#import "extensions/NSString+Helpers.h"
#import "windows/video/VLCMainVideoViewController.h"

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

@implementation VLCVideoPreferencesController
{
    BOOL _videoSettingChanged;
    NSOpenPanel *_selectFolderPanel;
}

- (void)setupControls
{
    /* video */
    [_enableCheckbox setTitle: _NS("Enable video")];
    [_displayBox setTitle: _NS("Display")];
    [_embeddedCheckbox setTitle: _NS("Show video within the main window")];
    [_pauseWhenMinimizedCheckbox setTitle:_NS("Pause the video playback when minimized")];
    [_resizeToNativeSizeCheckbox setTitle:_NS("Resize interface to the native video size")];
    [_onTopCheckbox setTitle: _NS("Float on Top")];
    [_videodecoCheckbox setTitle: _NS("Window decorations")];

    [_fullscreenBox setTitle:_NS("Fullscreen settings")];
    [_startInFullscreenCheckbox setTitle:_NS("Start in fullscreen")];
    [_blackScreenCheckbox setTitle: _NS("Black screens in Fullscreen mode")];
    [_nativeFullscreenCheckbox setTitle: _NS("Use the native fullscreen mode")];
    [_deviceLabel setStringValue: _NS("Fullscreen Video Device")];

    [_snapBox setTitle: _NS("Video snapshots")];
    [_snapFolderButton setTitle: _NS("Browse...")];
    [_snapFolderLabel setStringValue: _NS("Folder")];
    [_snapFormatLabel setStringValue: _NS("Format")];
    [_snapPrefixLabel setStringValue: _NS("Prefix")];
    [_snapSeqnumCheckbox setTitle: _NS("Sequential numbering")];
    [_deinterlaceLabel setStringValue: _NS("Deinterlace")];
    [_deinterlaceModeLabel setStringValue: _NS("Deinterlace mode")];
    [_videoBox setTitle: _NS("Video")];
}

- (void)resetControls
{
    NSUserDefaults * const defaults = NSUserDefaults.standardUserDefaults;
    [VLCPreferencesControlHelper setupButton:_nativeFullscreenCheckbox forBoolValue: "macosx-nativefullscreenmode"];
    [VLCPreferencesControlHelper setupButton:_embeddedCheckbox forBoolValue: "embedded-video"];

    [VLCPreferencesControlHelper setupButton:_enableCheckbox forBoolValue: "video"];
    [VLCPreferencesControlHelper setupButton:_startInFullscreenCheckbox forBoolValue: "fullscreen"];
    [VLCPreferencesControlHelper setupButton:_onTopCheckbox forBoolValue: "video-on-top"];
    [VLCPreferencesControlHelper setupButton:_blackScreenCheckbox forBoolValue: "macosx-black"];
    [VLCPreferencesControlHelper setupButton:_videodecoCheckbox forBoolValue: "video-deco"];
    [VLCPreferencesControlHelper setupButton:_pauseWhenMinimizedCheckbox forBoolValue: "macosx-pause-minimized"];
    [VLCPreferencesControlHelper setupButton:_resizeToNativeSizeCheckbox forBoolValue: "macosx-video-autoresize"];
    
    self.useClassicLayoutCheckbox.state = [defaults boolForKey:VLCUseClassicVideoPlayerLayoutKey] ? NSControlStateValueOn : NSControlStateValueOff;

    [_devicePopup removeAllItems];
    int i = 0;
    NSInteger y = [[NSScreen screens] count];
    [_devicePopup addItemWithTitle: _NS("Default")];
    [[_devicePopup lastItem] setTag: 0];
    while (i < y) {
        NSRect s_rect = [[[NSScreen screens] objectAtIndex:i] frame];
        [_devicePopup addItemWithTitle:
         [NSString stringWithFormat: @"%@ %i (%ix%i)", _NS("Screen"), i+1,
                   (int)s_rect.size.width, (int)s_rect.size.height]];
        [[_devicePopup lastItem] setTag: (int)[[[NSScreen screens] objectAtIndex:i] displayID]];
        i++;
    }
    [_devicePopup selectItemAtIndex: 0];
    [_devicePopup selectItemWithTag: config_GetInt("macosx-vdev")];

    [VLCPreferencesControlHelper setupField:_snapFolderTextField forOption:"snapshot-path"];
    [VLCPreferencesControlHelper setupField:_snapPrefixTextField forOption:"snapshot-prefix"];
    [VLCPreferencesControlHelper setupButton:_snapSeqnumCheckbox forBoolValue: "snapshot-sequential"];
    [VLCPreferencesControlHelper setupButton:_snapFormatPopup forStringList: "snapshot-format"];
    [VLCPreferencesControlHelper setupButton:_deinterlacePopup forIntList: "deinterlace"];
    [VLCPreferencesControlHelper setupButton:_deinterlaceModePopup forStringList: "deinterlace-mode"];

    // set lion fullscreen mode restrictions
    [self enableLionFullscreenMode: [_nativeFullscreenCheckbox state]];
}

- (void)saveChangedSettings
{
    if (_videoSettingChanged) {
        config_PutInt("video", [_enableCheckbox state]);
        config_PutInt("fullscreen", [_startInFullscreenCheckbox state]);
        config_PutInt("video-deco", [_videodecoCheckbox state]);
        config_PutInt("video-on-top", [_onTopCheckbox state]);
        config_PutInt("macosx-black", [_blackScreenCheckbox state]);

        config_PutInt("macosx-pause-minimized", [_pauseWhenMinimizedCheckbox state]);
        config_PutInt("macosx-video-autoresize", [_resizeToNativeSizeCheckbox state]);
        
        [NSUserDefaults.standardUserDefaults setBool:self.useClassicLayoutCheckbox.state == NSControlStateValueOn
                                              forKey:VLCUseClassicVideoPlayerLayoutKey];

        config_PutInt("embedded-video", [_embeddedCheckbox state]);
        config_PutInt("macosx-nativefullscreenmode", [_nativeFullscreenCheckbox state]);
        config_PutInt("macosx-vdev", [[_devicePopup selectedItem] tag]);

        config_PutPsz("snapshot-path", [[_snapFolderTextField stringValue] UTF8String]);
        config_PutPsz("snapshot-prefix", [[_snapPrefixTextField stringValue] UTF8String]);
        config_PutInt("snapshot-sequential", [_snapSeqnumCheckbox state]);
        saveStringList(_snapFormatPopup, "snapshot-format");
        saveIntList(_deinterlacePopup, "deinterlace");
        saveStringList(_deinterlaceModePopup, "deinterlace-mode");
        _videoSettingChanged = NO;
    }
}

// disables some video settings which do not work in lion mode
- (void)enableLionFullscreenMode: (BOOL)_value
{
    [_videodecoCheckbox setEnabled: !_value];
    [_blackScreenCheckbox setEnabled: !_value];
    [_devicePopup setEnabled: !_value];

    if (_value) {
        [_videodecoCheckbox setState: NSControlStateValueOn];
        [_blackScreenCheckbox setState: NSControlStateValueOff];

        NSString *tooltipText = _NS("This setting cannot be changed because the native fullscreen mode is enabled.");
        [_videodecoCheckbox setToolTip:tooltipText];
        [_blackScreenCheckbox setToolTip:tooltipText];
        [_devicePopup setToolTip:tooltipText];

    } else {
        [VLCPreferencesControlHelper setupButton:_videodecoCheckbox forBoolValue: "video-deco"];
        [VLCPreferencesControlHelper setupButton:_blackScreenCheckbox forBoolValue: "macosx-black"];

        [_devicePopup setToolTip:@""];
    }
}

- (IBAction)videoSettingChanged:(id)sender
{
    if (sender == _nativeFullscreenCheckbox)
        [self enableLionFullscreenMode:[sender state]];
    else if (sender == _snapFolderButton) {
        _selectFolderPanel = [[NSOpenPanel alloc] init];
        [_selectFolderPanel setCanChooseDirectories: YES];
        [_selectFolderPanel setCanChooseFiles: NO];
        [_selectFolderPanel setResolvesAliases: YES];
        [_selectFolderPanel setAllowsMultipleSelection: NO];
        [_selectFolderPanel setMessage: _NS("Choose the folder to save your video snapshots to.")];
        [_selectFolderPanel setCanCreateDirectories: YES];
        [_selectFolderPanel setPrompt: _NS("Choose")];
        [_selectFolderPanel beginSheetModalForWindow:_view.window completionHandler: ^(NSInteger returnCode) {
            if (returnCode == NSModalResponseOK) {
                [self->_snapFolderTextField setStringValue: [[self->_selectFolderPanel URL] path]];
            }
        }];
    }

    _videoSettingChanged = YES;
}

- (void)controlTextDidChange:(NSNotification *)notification
{
    _videoSettingChanged = YES;
}

@end
