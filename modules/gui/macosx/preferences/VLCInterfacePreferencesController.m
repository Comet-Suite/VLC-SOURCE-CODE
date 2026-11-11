/*****************************************************************************
 * VLCInterfacePreferencesController.m: Interface preferences
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

#import "VLCInterfacePreferencesController.h"
#import "VLCPreferencesControlHelper.h"
#ifdef HAVE_SPARKLE
#import <Sparkle/Sparkle.h>
#endif
#import <vlc_common.h>
#import <vlc_configuration.h>
#import <vlc_interface.h>
#import "extensions/NSString+Helpers.h"
#import "main/VLCMain.h"
#import "playqueue/VLCPlayQueueTableCellView.h"
#import "views/VLCPlaybackEndViewController.h"

static struct {
    const char iso[6];
    const char name[34];
    BOOL isRightToLeft;

} const language_map[] = {
    { "auto",  N_("Auto"),              NO },
    { "en",    "American English",      NO },
    { "ar",    "عربي",                  YES },
    { "an",    "Aragonés",              NO },
    { "as_IN", "অসমীয়া",                 NO },
    { "ast",   "Asturianu",             NO },
    { "be",    "беларуская мова",       NO },
    { "brx",   "बर'/बड़",                 NO },
    { "bn",    "বাংলা",                   NO },
    { "pt_BR", "Português Brasileiro",  NO },
    { "en_GB", "British English",       NO },
    { "el",    "Νέα Ελληνικά",          NO },
    { "bg",    "български език",        NO },
    { "ca",    "Català",                NO },
    { "zh_TW", "正體中文",                NO },
    { "cs",    "Čeština",               NO },
    { "cy",    "Cymraeg",               NO },
    { "da",    "Dansk",                 NO },
    { "nl",    "Nederlands",            NO },
    { "fi",    "Suomi",                 NO },
    { "et",    "eesti keel",            NO },
    { "eu",    "Euskara",               NO },
    { "fr",    "Français",              NO },
    { "ga",    "Gaeilge",               NO },
    { "gd",    "Gàidhlig",              NO },
    { "gl",    "Galego",                NO },
    { "gu",    "ગુજરાતી",                 NO },
    { "de",    "Deutsch",               NO },
    { "he",    "עברית",                 YES },
    { "hr",    "hrvatski",              NO },
    { "kn",    "ಕನ್ನಡ",                   NO },
    { "lv",    "Latviešu valoda",       NO },
    { "hu",    "Magyar",                NO },
    { "mr",    "मराठी",                   NO },
    { "is",    "íslenska",              NO },
    { "id",    "Bahasa Indonesia",      NO },
    { "it",    "Italiano",              NO },
    { "ja",    "日本語",                 NO },
    { "ko",    "한국어",                  NO },
    { "lt",    "lietuvių",              NO },
    { "ms",    "Melayu",                NO },
    { "nb",    "Bokmål",                NO },
    { "nn",    "Nynorsk",               NO },
    { "kk",    "Қазақ тілі",            NO },
    { "km",    "ភាសាខ្មែរ",                NO },
    { "ne",    "नेपाली",                  NO },
    { "oc",    "Occitan",               NO },
    { "pl",    "Polski",                NO },
    { "pt_PT", "Português",             NO },
    { "pa",    "ਪੰਜਾਬੀ",                  NO },
    { "ro",    "Română",                NO },
    { "ru",    "Русский",               NO },
    { "zh_CN", "简体中文",                NO },
    { "si",    "සිංහල",                   NO },
    { "sr",    "српски",                NO },
    { "sk",    "Slovensky",             NO },
    { "sl",    "slovenščina",           NO },
    { "es",    "Español",               NO },
    { "es_MX", "Español Mexicano",      NO },
    { "sv",    "Svenska",               NO },
    { "th",    "ภาษาไทย",               NO },
    { "tr",    "Türkçe",                NO },
    { "uk",    "украї́нська мо́ва",       NO },
    { "vi",    "tiếng Việt",            NO },
    { "wa",    "Walon",                 NO }
};

@implementation VLCInterfacePreferencesController
{
    BOOL _intfSettingChanged;
}

- (void)setupControls
{
    /* interface */
    [_generalSettingsBox setTitle:_NS("General settings")];
    [_languageLabel setStringValue: _NS("Language")];

    [_playbackControlBox setTitle:_NS("Playback control")];
    [_continueplaybackLabel setStringValue:_NS("Continue playback")];
    [_displayEndOfPlaybackViewCheckBox setTitle:_NS("Display end of playback view")];
    [_statusIconCheckbox setTitle: _NS("Display VLC status menu icon")];
    [_displayTrackNumberPlayQueueCheckBox setTitle: _NS("Display album track numbers in play queue")];

    [_playbackBehaviourBox setTitle:_NS("Playback behaviour")];
    [_enableNotificationsCheckbox setTitle: _NS("Enable notifications on play queue item change")];
    [_pauseitunesLabel setStringValue:_NS("Control external music players")];

    [_networkBox setTitle: _NS("Privacy / Network Interaction")];
    [_artCheckbox setTitle: _NS("Allow metadata network access")];
    [_updateCheckbox setTitle: _NS("Automatically check for updates")];
    [_lastUpdateLabel setStringValue: @""];

    [_luahttpBox setTitle:_NS("HTTP web interface")];
    [_enableluahttpCheckbox setTitle: _NS("Enable HTTP web interface")];
    [_luahttppwdLabel setStringValue:_NS("Password")];

#ifdef HAVE_SPARKLE
    [_updateCheckbox bind:@"value"
                   toObject:VLCMain.sharedInstance.sparkleUpdaterController.updater
                withKeyPath:@"automaticallyChecksForUpdates"
                    options:nil];
#else
    [_updateCheckbox setState:NSControlStateValueOff];
    [_updateCheckbox setEnabled:NO];
#endif

}

- (BOOL)hasModule:(NSString *)moduleName inConfig:(NSString *)config
{
    char *value = config_GetPsz([config UTF8String]);
    NSString *modules = toNSStr(value);
    free(value);

    return [[modules componentsSeparatedByString:@":"] containsObject:moduleName];
}

- (void)changeModule:(NSString *)moduleName inConfig:(NSString *)config enable:(BOOL)enable
{
    char *value = config_GetPsz([config UTF8String]);
    NSString *modules = toNSStr(value);
    free(value);

    NSMutableArray *components = [[modules componentsSeparatedByString:@":"] mutableCopy];
    if (enable) {
        if (![components containsObject:moduleName]) {
            [components addObject:moduleName];
        }
    } else {
        [components removeObject:moduleName];
    }

    // trim empty entries
    [components removeObject:@""];

    config_PutPsz([config UTF8String], [[components componentsJoinedByString:@":"] UTF8String]);
}

- (void)resetControls
{
    NSUInteger sel = 0;
    const char *pref = NULL;
    NSUserDefaults * const defaults = NSUserDefaults.standardUserDefaults;
    pref = [[defaults objectForKey:@"language"] UTF8String];
    for (size_t x = 0; x < ARRAY_SIZE(language_map); x++) {
        [_languagePopup addItemWithTitle:toNSStr(language_map[x].name)];
        if (pref) {
            if (!strcmp(language_map[x].iso, pref))
                sel = x;
        }
    }
    [_languagePopup selectItemAtIndex:sel];

    [VLCPreferencesControlHelper setupButton:_continueplaybackPopup forIntList: "macosx-continue-playback"];
    if (!var_InheritBool(getIntf(), "macosx-recentitems")) {
        [_continueplaybackPopup setEnabled: NO];
        [_continueplaybackPopup setToolTip: _NS("Media files cannot be resumed because keeping recent media items is disabled.")];
    } else {
        [_continueplaybackPopup setEnabled: YES];
    }

    self.displayEndOfPlaybackViewCheckBox.state = [defaults boolForKey:VLCPlaybackEndViewEnabledKey] ? NSControlStateValueOn : NSControlStateValueOff;

    self.displayTrackNumberPlayQueueCheckBox.state = [defaults boolForKey:VLCDisplayTrackNumberPlayQueueKey] ? NSControlStateValueOn : NSControlStateValueOff;

    [VLCPreferencesControlHelper setupButton:_statusIconCheckbox forBoolValue: "macosx-statusicon"];

    [VLCPreferencesControlHelper setupButton:_pauseitunesPopup forIntList: "macosx-control-itunes"];

    [VLCPreferencesControlHelper setupButton:_artCheckbox forBoolValue: "metadata-network-access"];


#ifdef HAVE_SPARKLE
    NSDate * const lastUpdateCheckDate = VLCMain.sharedInstance.sparkleUpdaterController.updater.lastUpdateCheckDate;
    if (lastUpdateCheckDate != NULL)
        [_lastUpdateLabel setStringValue: [NSString stringWithFormat: _NS("Last check on: %@"), [lastUpdateCheckDate descriptionWithLocale: [[NSUserDefaults standardUserDefaults] dictionaryRepresentation]]]];
    else
        [_lastUpdateLabel setStringValue: _NS("No check was performed yet.")];
#endif

    BOOL growlEnabled = [self hasModule:@"growl" inConfig:@"control"];
    [_enableNotificationsCheckbox setState: growlEnabled ? NSControlStateValueOn : NSControlStateValueOff];

    BOOL httpEnabled = [self hasModule:@"http" inConfig:@"extraintf"];
    [_enableluahttpCheckbox setState: httpEnabled ? NSControlStateValueOn : NSControlStateValueOff];
    _luahttppwdTextField.enabled = httpEnabled;

    [VLCPreferencesControlHelper setupField:_luahttppwdTextField forOption: "http-password"];
}

+ (BOOL)updateRightToLeftSettings
{
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSString *isoCode = [defaults stringForKey:@"language"];

    if (!isoCode || [isoCode isEqualToString:@"auto"]) {
        // Automatic handling of right to left
        [defaults removeObjectForKey:@"NSForceRightToLeftWritingDirection"];
        [defaults removeObjectForKey:@"AppleTextDirection"];
    } else {
        for(size_t i = 0; i < ARRAY_SIZE(language_map); i++) {
            if (!strcmp(language_map[i].iso, [isoCode UTF8String])) {
                [defaults setBool:language_map[i].isRightToLeft forKey:@"NSForceRightToLeftWritingDirection"];
                [defaults setBool:language_map[i].isRightToLeft forKey:@"AppleTextDirection"];
                return YES;
            }
        }
    }

    return NO;
}

- (void)saveChangedSettings
{
    if (_intfSettingChanged) {
        NSUInteger index = [_languagePopup indexOfSelectedItem];
        NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
        [defaults setObject:toNSStr(language_map[index].iso) forKey:@"language"];
        [VLCInterfacePreferencesController updateRightToLeftSettings];

        const BOOL originalDisplayTrackNumberSetting = [defaults boolForKey:VLCDisplayTrackNumberPlayQueueKey];

        [defaults setBool:self.displayEndOfPlaybackViewCheckBox.state == NSControlStateValueOn
                   forKey:VLCPlaybackEndViewEnabledKey];
        [defaults setBool:self.displayTrackNumberPlayQueueCheckBox.state == NSControlStateValueOn
                   forKey:VLCDisplayTrackNumberPlayQueueKey];
        
        if (originalDisplayTrackNumberSetting != [defaults boolForKey:VLCDisplayTrackNumberPlayQueueKey]) {
            [NSNotificationCenter.defaultCenter postNotificationName:VLCDisplayTrackNumberPlayQueueSettingChanged object:nil];
        }

        config_PutInt("metadata-network-access", [_artCheckbox state]);

        config_PutInt("macosx-statusicon", [_statusIconCheckbox state]);

        [self changeModule:@"growl" inConfig:@"control" enable:[_enableNotificationsCheckbox state] == NSControlStateValueOn];

        [self changeModule:@"http" inConfig:@"extraintf" enable:[_enableluahttpCheckbox state] == NSControlStateValueOn];
        config_PutPsz("http-password", [[_luahttppwdTextField stringValue] UTF8String]);

        [VLCPreferencesControlHelper saveIntList:_pauseitunesPopup forOption:"macosx-control-itunes"];
        [VLCPreferencesControlHelper saveIntList:_continueplaybackPopup forOption:"macosx-continue-playback"];
        _intfSettingChanged = NO;
    }
}

- (IBAction)interfaceSettingChanged:(id)sender
{
    if (sender == _enableluahttpCheckbox) {
        _luahttppwdTextField.enabled = [sender state] == NSControlStateValueOn;
    }

    _intfSettingChanged = YES;
}

- (void)controlTextDidChange:(NSNotification *)notification
{
    _intfSettingChanged = YES;
}

@end
