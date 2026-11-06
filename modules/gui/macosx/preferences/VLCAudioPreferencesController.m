/*****************************************************************************
 * VLCAudioPreferencesController.m: Audio preferences
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

#import "VLCAudioPreferencesController.h"
#import "VLCPreferencesControlHelper.h"
#import <vlc_common.h>
#import <vlc_aout.h>
#import <vlc_configuration.h>
#import <vlc_interface.h>
#import <vlc_modules.h>
#import "extensions/NSString+Helpers.h"
#import "main/VLCMain.h"

@implementation VLCAudioPreferencesController
{
    BOOL _audioSettingChanged;
}

- (void)setupControls
{
    /* audio */
    [_effectsBox setTitle: _NS("Audio Effects")];
    [_enableCheckbox setTitle: _NS("Enable audio")];
    [_generalBox setTitle: _NS("General Audio")];
    [_langLabel setStringValue: _NS("Preferred Audio language")];
    [_lastCheckbox setTitle: _NS("Enable Last.fm submissions")];
    [_lastpwdLabel setStringValue: _NS("Password")];
    [_lastuserLabel setStringValue: _NS("Username")];
    [_visualLabel setStringValue: _NS("Visualization")];
    [_autosavevolYesButtonCell setTitle: _NS("Keep audio level between sessions")];
    [_autosavevolNoButtonCell setTitle: _NS("Always reset audio start level to:")];
}

- (void)resetControls
{
    [VLCPreferencesControlHelper setupButton:_enableCheckbox forBoolValue: "audio"];

    if (config_GetInt("volume-save")) {
        [_autosavevolYesButtonCell setState: NSControlStateValueOn];
        [_autosavevolNoButtonCell setState: NSControlStateValueOff];
        [_volTextField setEnabled: NO];
        [_volSlider setEnabled: NO];

        [_volSlider setIntValue: 100];
        [_volTextField setIntValue: 100];
    } else {
        [_autosavevolYesButtonCell setState: NSControlStateValueOff];
        [_autosavevolNoButtonCell setState: NSControlStateValueOn];
        [_volTextField setEnabled: YES];
        [_volSlider setEnabled: YES];

        int i = (int)var_InheritInteger(getIntf(), "auhal-volume");
        i = i * 200. / AOUT_VOLUME_MAX;
        [_volSlider setIntValue: i];
        [_volTextField setIntValue: i];
    }

    [VLCPreferencesControlHelper setupField:_langTextField forOption: "audio-language"];

    [VLCPreferencesControlHelper setupButton:_visualPopup forModuleList: "audio-visual"];

    /* Last.FM is optional */
    if (module_exists("audioscrobbler")) {
        [VLCPreferencesControlHelper setupField:_lastuserTextField forOption:"lastfm-username"];
        [VLCPreferencesControlHelper setupField:_lastpwdSecureTextField forOption:"lastfm-password"];

        if (config_ExistIntf("audioscrobbler")) {
            [_lastCheckbox setState: NSControlStateValueOn];
            [_lastuserTextField setEnabled: YES];
            [_lastpwdSecureTextField setEnabled: YES];
        } else {
            [_lastCheckbox setState: NSControlStateValueOff];
            [_lastuserTextField setEnabled: NO];
            [_lastpwdSecureTextField setEnabled: NO];
        }
    } else
        [_lastCheckbox setEnabled: NO];
}

- (void)saveChangedSettings
{
    if (_audioSettingChanged) {
        config_PutInt("audio", [_enableCheckbox state]);
        config_PutInt("volume-save", [_autosavevolYesButtonCell state]);
        var_SetBool(getIntf(), "volume-save", [_autosavevolYesButtonCell state]);
        if ([_volTextField isEnabled])
            config_PutInt("auhal-volume", ([_volTextField intValue] * AOUT_VOLUME_MAX) / 200);

        config_PutPsz("audio-language", [[_langTextField stringValue] UTF8String]);

        [VLCPreferencesControlHelper saveStringList:_visualPopup forOption:"audio-visual"];

        /* Last.FM is optional */
        if (module_exists("audioscrobbler")) {
            [_lastCheckbox setEnabled: YES];
            if ([_lastCheckbox state] == NSControlStateValueOn)
                config_AddIntf("audioscrobbler");
            else
                config_RemoveIntf("audioscrobbler");

            config_PutPsz("lastfm-username", [[_lastuserTextField stringValue] UTF8String]);
            config_PutPsz("lastfm-password", [[_lastpwdSecureTextField stringValue] UTF8String]);
        }
        else
            [_lastCheckbox setEnabled: NO];
        _audioSettingChanged = NO;
    }
}

- (IBAction)audioSettingChanged:(id)sender
{
    if (sender == _volSlider)
        [_volTextField setIntValue: [_volSlider intValue]];

    if (sender == _volTextField)
        [_volSlider setIntValue: [_volTextField intValue]];

    if (sender == _lastCheckbox) {
        if ([_lastCheckbox state] == NSControlStateValueOn) {
            [_lastpwdSecureTextField setEnabled: YES];
            [_lastuserTextField setEnabled: YES];
        } else {
            [_lastpwdSecureTextField setEnabled: NO];
            [_lastuserTextField setEnabled: NO];
        }
    }

    if (sender == _autosavevolMatrix) {
        BOOL enableVolumeSlider = [_autosavevolMatrix selectedTag] == 1;
        [_volTextField setEnabled: enableVolumeSlider];
        [_volSlider setEnabled: enableVolumeSlider];
    }

    _audioSettingChanged = YES;
}

- (void)controlTextDidChange:(NSNotification *)notification
{
    _audioSettingChanged = YES;
}

@end
