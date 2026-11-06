/*****************************************************************************
 * VLCSimplePrefsController.m: Simple Preferences for Mac OS X
 *****************************************************************************
 * Copyright (C) 2008-2019 VLC authors and VideoLAN
 *
 * Authors: Felix Paul Kühne <fkuehne # videolan dot org>
 *          David Fuhrmann <dfuhrmann # videolan dot org>
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

#import "VLCSimplePrefsController.h"
#import "VLCMediaLibraryFolderManagementController.h"
#import "VLCHotkeyPreferencesController.h"
#import "VLCAudioPreferencesController.h"
#import "VLCVideoPreferencesController.h"
#import "VLCInputPreferencesController.h"
#import "VLCPreferencesControlHelper.h"

#ifdef HAVE_SPARKLE
#import <Sparkle/Sparkle.h>                        //for o_intf_last_updateLabel
#endif

#import <vlc_configuration.h>
#import <vlc_actions.h>
#import <vlc_interface.h>
#import <vlc_dialog.h>
#import <vlc_modules.h>
#import <vlc_plugin.h>
#import <vlc_config_cat.h>
#import <vlc_aout.h>

#import "extensions/NSString+Helpers.h"
#import "extensions/NSFont+VLCAdditions.h"
#import "main/VLCMain.h"
#import "main/VLCMain+OldPrefs.h"
#import "os-integration/VLCClickerManager.h"
#import "preferences/prefs.h"
#import "library/VLCLibraryController.h"
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

static NSString* VLCSPrefsToolbarIdentifier = @"Our Simple Preferences Toolbar Identifier";
static NSString* VLCIntfSettingToolbarIdentifier = @"Intf Settings Item Identifier";
static NSString* VLCAudioSettingToolbarIdentifier = @"Audio Settings Item Identifier";
static NSString* VLCVideoSettingToolbarIdentifier = @"Video Settings Item Identifier";
static NSString* VLCOSDSettingToolbarIdentifier = @"Subtitles Settings Item Identifier";
static NSString* VLCInputSettingToolbarIdentifier = @"Input Settings Item Identifier";
static NSString* VLCMediaLibrarySettingToolbarIdentifier = @"Media Library Settings Item Identifier";
static NSString* VLCHotkeysSettingToolbarIdentifier = @"Hotkeys Settings Item Identifier";

@interface VLCSimplePrefsController() <NSToolbarDelegate, NSWindowDelegate>
{
    BOOL _intfSettingChanged;
    BOOL _osdSettingChanged;

    VLCMediaLibraryFolderManagementController *_mediaLibraryManagementController;

    intf_thread_t *p_intf;
}
@property (nonatomic, strong) IBOutlet VLCHotkeyPreferencesController *hotkeyPreferencesController;
@property (nonatomic, strong) IBOutlet VLCAudioPreferencesController *audioPreferencesController;
@property (nonatomic, strong) IBOutlet VLCVideoPreferencesController *videoPreferencesController;
@property (nonatomic, strong) IBOutlet VLCInputPreferencesController *inputPreferencesController;
@end

@implementation VLCSimplePrefsController

#pragma mark Initialisation

- (id)init
{
    self = [super initWithWindowNibName:@"SimplePreferences"];
    if (self) {
        p_intf = getIntf();
    }

    return self;
}

- (void)windowDidLoad
{
    [self initStrings];

#ifdef HAVE_SPARKLE
    [_intf_updateCheckbox bind:@"value"
                   toObject:VLCMain.sharedInstance.sparkleUpdaterController.updater
                withKeyPath:@"automaticallyChecksForUpdates"
                    options:nil];
#else
    [_intf_updateCheckbox setState:NSControlStateValueOff];
    [_intf_updateCheckbox setEnabled:NO];
#endif

    /* setup the toolbar */
    NSToolbar * toolbar = [[NSToolbar alloc] initWithIdentifier: VLCSPrefsToolbarIdentifier];
    [toolbar setAllowsUserCustomization: NO];
    [toolbar setAutosavesConfiguration: NO];
    [toolbar setDisplayMode: NSToolbarDisplayModeIconAndLabel];
    [toolbar setSizeMode: NSToolbarSizeModeRegular];
    [toolbar setDelegate: self];
    [self.window setToolbar:toolbar];

    [self.window setCollectionBehavior: NSWindowCollectionBehaviorFullScreenAuxiliary];
    [self.window setHidesOnDeactivate:YES];

    [_hotkeyPreferencesController setupControls];
    [_audioPreferencesController setupControls];
    [_videoPreferencesController setupControls];
    [_inputPreferencesController setupControls];

    // Workaround for Mac OS X Lion, which does not apply the same constraints when set in IB
    NSView *clipView = _contentView.superview;

    NSDictionary *views = @{ @"view": _contentView };
    NSArray *constraints = [NSLayoutConstraint constraintsWithVisualFormat:@"|[view]|" options:0 metrics:nil views:views];
    [clipView addConstraints:constraints];

    [self setupMediaLibraryControlInterface];
}

- (void)setupMediaLibraryControlInterface
{
    _mediaLibraryManagementController = [[VLCMediaLibraryFolderManagementController alloc] init];
    _mediaLibraryBanFolderButton.enabled = _mediaLibraryRemoveFolderButton.enabled = _mediaLibraryReloadFolderButton.enabled = NO;

    _mediaLibraryFolderTableView.delegate = _mediaLibraryManagementController;
    _mediaLibraryFolderTableView.dataSource = _mediaLibraryManagementController;
    _mediaLibraryManagementController.libraryFolderTableView = _mediaLibraryFolderTableView;

    _mediaLibraryManagementController.nameTableColumn = _mediaLibraryNameTableColumn;
    _mediaLibraryManagementController.presentTableColumn = _mediaLibraryPresentTableColumn;
    _mediaLibraryManagementController.bannedTableColumn = _mediaLibraryBannedTableColumn;
    _mediaLibraryManagementController.pathTableColumn = _mediaLibraryPathTableColumn;
    _mediaLibraryManagementController.removeFolderButton = _mediaLibraryRemoveFolderButton;
    _mediaLibraryManagementController.banFolderButton = _mediaLibraryBanFolderButton;
    _mediaLibraryManagementController.reloadFolderButton = _mediaLibraryReloadFolderButton;

    _mediaLibraryAddFolderButton.target = _mediaLibraryManagementController;
    _mediaLibraryAddFolderButton.action = @selector(addFolder:);
    _mediaLibraryBanFolderButton.target = _mediaLibraryManagementController;
    _mediaLibraryBanFolderButton.action = @selector(banFolder:);
    _mediaLibraryRemoveFolderButton.target = _mediaLibraryManagementController;
    _mediaLibraryRemoveFolderButton.action = @selector(removeFolder:);
    _mediaLibraryReloadFolderButton.target = _mediaLibraryManagementController;
    _mediaLibraryReloadFolderButton.action = @selector(reloadFolder:);
}

#define CreateToolbarItem(name, desc, img, sel) \
    toolbarItem = create_toolbar_item(itemIdent, name, desc, img, self, @selector(sel));
static inline NSToolbarItem *
create_toolbar_item(NSString *itemIdent, NSString *name, NSString *desc, NSString *img, id target, SEL selector)
{
    NSToolbarItem *toolbarItem = [[NSToolbarItem alloc] initWithItemIdentifier: itemIdent];

    [toolbarItem setLabel:name];
    [toolbarItem setPaletteLabel:desc];

    [toolbarItem setToolTip:desc];
    [toolbarItem setImage:[NSImage imageNamed:img]];

    [toolbarItem setTarget:target];
    [toolbarItem setAction:selector];

    [toolbarItem setEnabled:YES];
    [toolbarItem setAutovalidates:YES];

    return toolbarItem;
}

- (NSToolbarItem *) toolbar:(NSToolbar *)toolbar
      itemForItemIdentifier:(NSString *)itemIdent
  willBeInsertedIntoToolbar:(BOOL)willBeInserted
{
    NSToolbarItem *toolbarItem = nil;

    if ([itemIdent isEqual: VLCIntfSettingToolbarIdentifier]) {
        CreateToolbarItem(NSTR(INTF_TITLE), NSTR(INTF_TOOLTIP), @"VLCInterfaceCone", showInterfaceSettings);
    } else if ([itemIdent isEqual: VLCAudioSettingToolbarIdentifier]) {
        CreateToolbarItem(NSTR(AUDIO_TITLE), NSTR(AUDIO_TOOLTIP), @"VLCAudioCone", showAudioSettings);
    } else if ([itemIdent isEqual: VLCVideoSettingToolbarIdentifier]) {
        CreateToolbarItem(NSTR(VIDEO_TITLE), NSTR(VIDEO_TOOLTIP), @"VLCVideoCone", showVideoSettings);
    } else if ([itemIdent isEqual: VLCOSDSettingToolbarIdentifier]) {
        CreateToolbarItem(NSTR(SUBPIC_TITLE), NSTR(SUBPIC_TOOLTIP), @"VLCSubtitleCone", showOSDSettings);
    } else if ([itemIdent isEqual: VLCInputSettingToolbarIdentifier]) {
        CreateToolbarItem(NSTR(INPUT_TITLE), NSTR(INPUT_TOOLTIP), @"VLCInputCone", showInputSettings);
    } else if ([itemIdent isEqual: VLCMediaLibrarySettingToolbarIdentifier]) {
        CreateToolbarItem(NSTR(ML_TITLE), NSTR(ML_TOOLTIP), @"NXHelpBacktrack", showMediaLibrarySettings);
    } else if ([itemIdent isEqual: VLCHotkeysSettingToolbarIdentifier]) {
        CreateToolbarItem(NSTR(HOTKEYS_TITLE), NSTR(HOTKEYS_TOOLTIP), @"VLCHotkeysCone", showHotkeySettings);
    }

    return toolbarItem;
}

- (NSArray<NSString *> *)toolbarIdentifiers {
    static dispatch_once_t onceToken;
    static NSArray<NSString *> *toolbarIdentifiers = nil;

    dispatch_once(&onceToken, ^{
        if (VLCMain.sharedInstance.libraryController.shouldUseMediaLibrary) {
            toolbarIdentifiers = @[VLCIntfSettingToolbarIdentifier,
                                   VLCAudioSettingToolbarIdentifier,
                                   VLCVideoSettingToolbarIdentifier,
                                   VLCOSDSettingToolbarIdentifier,
                                   VLCInputSettingToolbarIdentifier,
                                   VLCMediaLibrarySettingToolbarIdentifier,
                                   VLCHotkeysSettingToolbarIdentifier,
                                   NSToolbarFlexibleSpaceItemIdentifier];
        } else {
            toolbarIdentifiers = @[VLCIntfSettingToolbarIdentifier,
                                   VLCAudioSettingToolbarIdentifier,
                                   VLCVideoSettingToolbarIdentifier,
                                   VLCOSDSettingToolbarIdentifier,
                                   VLCInputSettingToolbarIdentifier,
                                   VLCHotkeysSettingToolbarIdentifier,
                                   NSToolbarFlexibleSpaceItemIdentifier];
        }
    });

    return toolbarIdentifiers;
}

- (NSArray *)toolbarDefaultItemIdentifiers: (NSToolbar *)toolbar
{
    return [self toolbarIdentifiers];
}

- (NSArray *)toolbarAllowedItemIdentifiers: (NSToolbar *)toolbar
{
    return [self toolbarIdentifiers];
}

- (NSArray *)toolbarSelectableItemIdentifiers:(NSToolbar *)toolbar
{
    return [self toolbarIdentifiers];
}

- (BOOL)validateToolbarItem:(NSToolbarItem *)item
{
    if ([item.itemIdentifier isEqual:VLCMediaLibrarySettingToolbarIdentifier]) {
        return VLCMain.sharedInstance.libraryController.libraryModel != nil;
    }
    return YES;
}

- (void)initStrings
{
    /* url handler */
    [_urlhandler_titleLabel setStringValue: _NS("Open network streams using the following protocols")];
    [_urlhandler_subtitleLabel setStringValue: _NS("Note that these are system-wide settings.")];
    [_urlhandler_saveButton setTitle: _NS("Save")];
    [_urlhandler_cancelButton setTitle: _NS("Cancel")];

    /* interface */
    [_intf_generalSettingsBox setTitle:_NS("General settings")];
    [_intf_languageLabel setStringValue: _NS("Language")];

    [_intf_playbackControlBox setTitle:_NS("Playback control")];
    [_intf_continueplaybackLabel setStringValue:_NS("Continue playback")];
    [_intf_displayEndOfPlaybackViewCheckBox setTitle:_NS("Display end of playback view")];
    [_intf_statusIconCheckbox setTitle: _NS("Display VLC status menu icon")];
    [_intf_displayTrackNumberPlayQueueCheckBox setTitle: _NS("Display album track numbers in play queue")];

    [_intf_playbackBehaviourBox setTitle:_NS("Playback behaviour")];
    [_intf_enableNotificationsCheckbox setTitle: _NS("Enable notifications on play queue item change")];
    [_intf_pauseitunesLabel setStringValue:_NS("Control external music players")];

    [_intf_networkBox setTitle: _NS("Privacy / Network Interaction")];
    [_intf_artCheckbox setTitle: _NS("Allow metadata network access")];
    [_intf_updateCheckbox setTitle: _NS("Automatically check for updates")];
    [_intf_last_updateLabel setStringValue: @""];

    [_intf_luahttpBox setTitle:_NS("HTTP web interface")];
    [_intf_enableluahttpCheckbox setTitle: _NS("Enable HTTP web interface")];
    [_intf_luahttppwdLabel setStringValue:_NS("Password")];

    /* Subtitles and OSD */
    [_osd_encodingLabel setStringValue: _NS("Default Encoding")];
    [_osd_fontBox setTitle: _NS("Display Settings")];
    [_osd_fontButton setTitle: _NS("Choose...")];
    [_osd_font_colorLabel setStringValue: _NS("Font color")];
    [_osd_font_sizeLabel setStringValue: _NS("Font size")];
    [_osd_fontLabel setStringValue: _NS("Font")];
    [_osd_langBox setTitle: _NS("Subtitle languages")];
    [_osd_langLabel setStringValue: _NS("Preferred subtitle language")];
    [_osd_osdBox setTitle: _NS("On Screen Display")];
    [_osd_osdCheckbox setTitle: _NS("Enable OSD")];
    [_osd_opacityLabel setStringValue: _NS("Opacity")];
    [_osd_forceboldCheckbox setTitle: _NS("Force bold")];
    [_osd_outline_colorLabel setStringValue: _NS("Outline color")];
    [_osd_outline_thicknessLabel setStringValue: _NS("Outline thickness")];

    /* media library */
    [_mediaLibraryAddFolderButton setTitle:_NS("Add Folder...")];
    [_mediaLibraryBanFolderButton setTitle:_NS("Ban Folder")];
    [_mediaLibraryRemoveFolderButton setTitle:_NS("Remove Folder")];
    [_mediaLibraryReloadFolderButton setTitle:_NS("Reload Folder")];
    [_mediaLibraryNameTableColumn setTitle:_NS("Name")];
    [_mediaLibraryPresentTableColumn setTitle:_NS("Present")];
    [_mediaLibraryBannedTableColumn setTitle:_NS("Banned")];
    [_mediaLibraryPathTableColumn setTitle:_NS("Location")];

    /* generic stuff */
    [_showAllButton setTitle: _NS("Show All")];
    [_cancelButton setTitle: _NS("Cancel")];
    [_resetButton setTitle: _NS("Reset All")];
    [_saveButton setTitle: _NS("Save")];
    [self.window setTitle: _NS("Preferences")];
}

#pragma mark -
#pragma mark Setup controls

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
    int i = 0;

    /**********************
     * interface settings *
     **********************/
    NSUInteger sel = 0;
    const char *pref = NULL;
    NSUserDefaults * const defaults = NSUserDefaults.standardUserDefaults;
    pref = [[defaults objectForKey:@"language"] UTF8String];
    for (size_t x = 0; x < ARRAY_SIZE(language_map); x++) {
        [_intf_languagePopup addItemWithTitle:toNSStr(language_map[x].name)];
        if (pref) {
            if (!strcmp(language_map[x].iso, pref))
                sel = x;
        }
    }
    [_intf_languagePopup selectItemAtIndex:sel];

    [VLCPreferencesControlHelper setupButton:_intf_continueplaybackPopup forIntList: "macosx-continue-playback"];
    if (!var_InheritBool(p_intf, "macosx-recentitems")) {
        [_intf_continueplaybackPopup setEnabled: NO];
        [_intf_continueplaybackPopup setToolTip: _NS("Media files cannot be resumed because keeping recent media items is disabled.")];
    } else {
        [_intf_continueplaybackPopup setEnabled: YES];
    }

    self.intf_displayEndOfPlaybackViewCheckBox.state = [defaults boolForKey:VLCPlaybackEndViewEnabledKey] ? NSControlStateValueOn : NSControlStateValueOff;

    self.intf_displayTrackNumberPlayQueueCheckBox.state = [defaults boolForKey:VLCDisplayTrackNumberPlayQueueKey] ? NSControlStateValueOn : NSControlStateValueOff;

    [VLCPreferencesControlHelper setupButton:_intf_statusIconCheckbox forBoolValue: "macosx-statusicon"];

    [VLCPreferencesControlHelper setupButton:_intf_pauseitunesPopup forIntList: "macosx-control-itunes"];

    [VLCPreferencesControlHelper setupButton:_intf_artCheckbox forBoolValue: "metadata-network-access"];


#ifdef HAVE_SPARKLE
    NSDate * const lastUpdateCheckDate = VLCMain.sharedInstance.sparkleUpdaterController.updater.lastUpdateCheckDate;
    if (lastUpdateCheckDate != NULL)
        [_intf_last_updateLabel setStringValue: [NSString stringWithFormat: _NS("Last check on: %@"), [lastUpdateCheckDate descriptionWithLocale: [[NSUserDefaults standardUserDefaults] dictionaryRepresentation]]]];
    else
        [_intf_last_updateLabel setStringValue: _NS("No check was performed yet.")];
#endif

    BOOL growlEnabled = [self hasModule:@"growl" inConfig:@"control"];
    [_intf_enableNotificationsCheckbox setState: growlEnabled ? NSControlStateValueOn : NSControlStateValueOff];

    BOOL httpEnabled = [self hasModule:@"http" inConfig:@"extraintf"];
    [_intf_enableluahttpCheckbox setState: httpEnabled ? NSControlStateValueOn : NSControlStateValueOff];
    _intf_luahttppwdTextField.enabled = httpEnabled;

    [VLCPreferencesControlHelper setupField:_intf_luahttppwdTextField forOption: "http-password"];

    [_audioPreferencesController resetControls];

    [_videoPreferencesController resetControls];

    [_inputPreferencesController resetControls];

    /*********************
     * subtitle settings *
     *********************/
    [VLCPreferencesControlHelper setupButton:_osd_osdCheckbox forBoolValue: "osd"];

    [VLCPreferencesControlHelper setupButton:_osd_encodingPopup forStringList: "subsdec-encoding"];
    [VLCPreferencesControlHelper setupField:_osd_langTextField forOption: "sub-language" ];

    [VLCPreferencesControlHelper setupField:_osd_fontTextField forOption: "freetype-font"];
    [VLCPreferencesControlHelper setupButton:_osd_font_colorPopup forIntList: "freetype-color"];
    _osd_font_sizeSlider.intValue = (int)config_GetInt("sub-text-scale");
    [_osd_font_sizeTextField setStringValue: [NSString stringWithFormat:@"%.2fx", _osd_font_sizeSlider.intValue / 100.]];
    i = config_GetInt("freetype-opacity") * 100.0 / 255.0 + 0.5;
    [_osd_opacityTextField setIntValue: i];
    [_osd_opacitySlider setIntValue: i];
    [_osd_opacitySlider setToolTip: NSTR(config_GetLabel("freetype-opacity"))];
    [_osd_opacityTextField setToolTip: [_osd_opacitySlider toolTip]];
    [VLCPreferencesControlHelper setupButton:_osd_forceboldCheckbox forBoolValue: "freetype-bold"];
    [VLCPreferencesControlHelper setupButton:_osd_outline_colorPopup forIntList: "freetype-outline-color"];
    [VLCPreferencesControlHelper setupButton:_osd_outline_thicknessPopup forIntList: "freetype-outline-thickness"];

    [_hotkeyPreferencesController resetControls];
}

#pragma mark -
#pragma mark General actions

- (void)showSimplePrefs
{
    /* we want to show the interface settings, if no category was chosen */
    if ([[self.window toolbar] selectedItemIdentifier] == nil) {
        [[self.window toolbar] setSelectedItemIdentifier: VLCIntfSettingToolbarIdentifier];
        [self showInterfaceSettings];
    }

    [self resetControls];

    [self.window makeKeyAndOrderFront: self];
}

- (void)showSimplePrefsWithLevel:(NSInteger)i_window_level
{
    [self.window setLevel: i_window_level];
    [self showSimplePrefs];
}

- (IBAction)buttonAction:(id)sender
{
    if (sender == _cancelButton) {
        [[NSFontPanel sharedFontPanel] close];
        [self.window orderOut: sender];
    } else if (sender == _saveButton) {
        [self saveChangedSettings];
        [[NSFontPanel sharedFontPanel] close];
        [self.window orderOut: sender];
    } else if (sender == _showAllButton) {
        [self.window orderOut: self];
        [VLCMain.sharedInstance.preferences showPrefsWithLevel:[self.window level]];
    } else
        msg_Warn(p_intf, "unknown buttonAction sender");
}

- (IBAction)resetPreferences:(NSControl *)sender
{
    NSAlert *alert = [[NSAlert alloc] init];
    [alert setAlertStyle:NSAlertStyleInformational];
    [alert setMessageText:_NS("Reset Preferences")];
    [alert setInformativeText:_NS("This will reset VLC media player's preferences.\n\n"
                                  "Note that VLC will restart during the process, so your current "
                                  "play queue will be emptied and eventual playback, streaming or "
                                  "transcoding activities will stop immediately.\n\n"
                                  "The Media Library will not be affected.\n\n"
                                  "Are you sure you want to continue?")];
    [alert addButtonWithTitle:_NS("Cancel")];
    [alert addButtonWithTitle:_NS("Continue")];
    [alert beginSheetModalForWindow:[sender window] completionHandler:^(NSModalResponse returnCode) {
        if (returnCode == NSAlertSecondButtonReturn) {
            [VLCMain.sharedInstance resetPreferences];
        }
    }];
}

static inline void save_int_list(intf_thread_t * __unused p_intf, id object, const char * name)
{
    NSNumber *p_valueobject = (NSNumber *)[[object selectedItem] representedObject];
    if (p_valueobject) {
        assert([p_valueobject isKindOfClass:[NSNumber class]]);
        config_PutInt(name, [p_valueobject intValue]);
    }
}

static inline void save_string_list(intf_thread_t * __unused p_intf, id object, const char * name)
{
    NSString *p_stringobject = (NSString *)[[object selectedItem] representedObject];
    if (p_stringobject) {
        assert([p_stringobject isKindOfClass:[NSString class]]);
        config_PutPsz(name, [p_stringobject UTF8String]);
    }
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
#define SaveIntList(object, name) save_int_list(p_intf, object, name)

#define SaveStringList(object, name) save_string_list(p_intf, object, name)
#define SaveModuleList(object, name) SaveStringList(object, name)

    /**********************
     * interface settings *
     **********************/
    if (_intfSettingChanged) {
        NSUInteger index = [_intf_languagePopup indexOfSelectedItem];
        NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
        [defaults setObject:toNSStr(language_map[index].iso) forKey:@"language"];
        [VLCSimplePrefsController updateRightToLeftSettings];

        const BOOL originalDisplayTrackNumberSetting = [defaults boolForKey:VLCDisplayTrackNumberPlayQueueKey];

        [defaults setBool:self.intf_displayEndOfPlaybackViewCheckBox.state == NSControlStateValueOn
                   forKey:VLCPlaybackEndViewEnabledKey];
        [defaults setBool:self.intf_displayTrackNumberPlayQueueCheckBox.state == NSControlStateValueOn
                   forKey:VLCDisplayTrackNumberPlayQueueKey];
        
        if (originalDisplayTrackNumberSetting != [defaults boolForKey:VLCDisplayTrackNumberPlayQueueKey]) {
            [NSNotificationCenter.defaultCenter postNotificationName:VLCDisplayTrackNumberPlayQueueSettingChanged object:nil];
        }

        config_PutInt("metadata-network-access", [_intf_artCheckbox state]);

        config_PutInt("macosx-statusicon", [_intf_statusIconCheckbox state]);

        [self changeModule:@"growl" inConfig:@"control" enable:[_intf_enableNotificationsCheckbox state] == NSControlStateValueOn];

        [self changeModule:@"http" inConfig:@"extraintf" enable:[_intf_enableluahttpCheckbox state] == NSControlStateValueOn];
        config_PutPsz("http-password", [[_intf_luahttppwdTextField stringValue] UTF8String]);

        SaveIntList(_intf_pauseitunesPopup, "macosx-control-itunes");
        SaveIntList(_intf_continueplaybackPopup, "macosx-continue-playback");
        _intfSettingChanged = NO;
    }

    [_audioPreferencesController saveChangedSettings];

    [_videoPreferencesController saveChangedSettings];

    [_inputPreferencesController saveChangedSettings];

    /**********************
     * subtitles settings *
     **********************/
    if (_osdSettingChanged) {
        config_PutInt("osd", [_osd_osdCheckbox state]);

        if ([_osd_encodingPopup indexOfSelectedItem] >= 0)
            SaveStringList(_osd_encodingPopup, "subsdec-encoding");
        else
            config_PutPsz("subsdec-encoding", "");

        config_PutPsz("sub-language", [[_osd_langTextField stringValue] UTF8String]);

        config_PutPsz("freetype-font", [[_osd_fontTextField stringValue] UTF8String]);
        SaveIntList(_osd_font_colorPopup, "freetype-color");
        config_PutInt("sub-text-scale", _osd_font_sizeSlider.intValue);
        config_PutInt("freetype-opacity", [_osd_opacityTextField intValue] * 255.0 / 100.0 + 0.5);
        config_PutInt("freetype-bold", [_osd_forceboldCheckbox state]);
        SaveIntList(_osd_outline_colorPopup, "freetype-outline-color");
        SaveIntList(_osd_outline_thicknessPopup, "freetype-outline-thickness");
        _osdSettingChanged = NO;
    }

    [_hotkeyPreferencesController saveChangedSettings];
    fixIntfSettings();

    /* okay, let's save our changes to vlcrc */
    config_SaveConfigFile(p_intf);
    [NSNotificationCenter.defaultCenter postNotificationName:VLCConfigurationChangedNotification object:nil];
}

- (void)showSettingsForCategory:(NSView *)categoryView
{
    [_contentView setSubviews:[NSArray array]];
    [_contentView addSubview:categoryView];

    NSDictionary *views = @{ @"view": categoryView };
    NSArray *constraints = [NSLayoutConstraint constraintsWithVisualFormat:@"|[view]|" options:0 metrics:nil views:views];
    [_contentView addConstraints:constraints];
    constraints = [NSLayoutConstraint constraintsWithVisualFormat:@"V:|[view]|" options:0 metrics:nil views:views];
    [_contentView addConstraints:constraints];

    [_scrollView layoutSubtreeIfNeeded];
    [_scrollView flashScrollers];
}

#pragma mark -
#pragma mark Specific actions

- (IBAction)interfaceSettingChanged:(id)sender
{
    if (sender == _intf_enableluahttpCheckbox) {
        _intf_luahttppwdTextField.enabled = [sender state] == NSControlStateValueOn;
    }

    _intfSettingChanged = YES;
}

- (void)showInterfaceSettings
{
    [self showSettingsForCategory:_intfView];
}

- (void)showAudioSettings
{
    [self showSettingsForCategory:_audioPreferencesController.view];
}

- (void)showVideoSettings
{
    [self showSettingsForCategory:_videoPreferencesController.view];
}

- (IBAction)osdSettingChanged:(id)sender
{
    if (sender == _osd_opacityTextField) {
        [_osd_opacitySlider setIntValue: [_osd_opacityTextField intValue]];
    } else if (sender == _osd_opacitySlider) {
        [_osd_opacityTextField setIntValue: [_osd_opacitySlider intValue]];
    } else if (sender == _osd_font_sizeSlider) {
        [_osd_font_sizeTextField setStringValue: [NSString stringWithFormat:@"%.2fx", _osd_font_sizeSlider.intValue / 100.]];
    }

    _osdSettingChanged = YES;
}

- (void)showOSDSettings
{
    [self showSettingsForCategory:_osdView];
}

- (void)controlTextDidChange:(NSNotification *)notification
{
    id notificationObject = [notification object];
    if (notificationObject == _osd_fontTextField ||
            notificationObject == _osd_langTextField ||
            notificationObject == _osd_opacityTextField)
        _osdSettingChanged = YES;
    else if (notificationObject == _intf_luahttppwdTextField)
        _intfSettingChanged = YES;
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

    [_osd_fontTextField setStringValue:[selectedFont fontName]];
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

- (void)showInputSettings
{
    [self showSettingsForCategory:_inputPreferencesController.view];
}

- (NSString *)bundleIdentifierForApplicationName:(NSString *)appName
{
    NSWorkspace * workspace = NSWorkspace.sharedWorkspace;
    NSString * appPath = [workspace fullPathForApplication:appName];
    if (appPath) {
        NSBundle * appBundle = [NSBundle bundleWithPath:appPath];
        return [appBundle bundleIdentifier];
    }
    return nil;
}

- (NSString *)applicationNameForBundleIdentifier:(NSString *)bundleIdentifier
{
    return [[[NSFileManager defaultManager] displayNameAtPath:[NSWorkspace.sharedWorkspace absolutePathForAppBundleWithIdentifier:bundleIdentifier]] stringByDeletingPathExtension];
}

- (NSImage *)iconForBundleIdentifier:(NSString *)bundleIdentifier
{
    NSWorkspace *workspace = NSWorkspace.sharedWorkspace;
    NSSize iconSize = NSMakeSize(16., 16.);
    NSImage *icon = [workspace iconForFile:[workspace absolutePathForAppBundleWithIdentifier:bundleIdentifier]];
    [icon setSize:iconSize];
    return icon;
}

- (IBAction)urlHandlerAction:(id)sender
{
    if (sender == _inputPreferencesController.urlhandlerButton) {

        void (^fillUrlHandlerPopup)(NSString*, NSPopUpButton*) = ^void(NSString *protocol, NSPopUpButton *object) {

            NSArray *handlers = (__bridge_transfer NSArray *)LSCopyAllHandlersForURLScheme((__bridge CFStringRef)protocol);
            NSMutableArray *rawHandlers = [[NSMutableArray alloc] init];
            [object removeAllItems];
            NSUInteger count = [handlers count];
            for (NSUInteger x = 0; x < count; x++) {
                NSString *rawhandler = [handlers objectAtIndex:x];
                NSString *handler = [self applicationNameForBundleIdentifier:rawhandler];
                if (handler && ![handler isEqualToString:@""]) {
                    [object addItemWithTitle:handler];
                    [[object lastItem] setImage: [self iconForBundleIdentifier:[handlers objectAtIndex:x]]];
                    [rawHandlers addObject: rawhandler];
                }
            }
            [object selectItemAtIndex: [rawHandlers indexOfObject:(__bridge_transfer id)LSCopyDefaultHandlerForURLScheme((__bridge CFStringRef)protocol)]];
        };

        fillUrlHandlerPopup(@"ftp", _urlhandler_ftpPopup);
        fillUrlHandlerPopup(@"mms", _urlhandler_mmsPopup);
        fillUrlHandlerPopup(@"rtmp", _urlhandler_rtmpPopup);
        fillUrlHandlerPopup(@"rtp", _urlhandler_rtpPopup);
        fillUrlHandlerPopup(@"rtsp", _urlhandler_rtspPopup);
        fillUrlHandlerPopup(@"sftp", _urlhandler_sftpPopup);
        fillUrlHandlerPopup(@"smb", _urlhandler_smbPopup);
        fillUrlHandlerPopup(@"udp", _urlhandler_udpPopup);

        [self.window beginSheet:_urlhandler_win completionHandler:nil];
    } else {
        [_urlhandler_win orderOut:sender];
        [NSApp endSheet:_urlhandler_win];

        if (sender == _urlhandler_saveButton) {
            LSSetDefaultHandlerForURLScheme(CFSTR("ftp"), (__bridge CFStringRef)[self bundleIdentifierForApplicationName:[[_urlhandler_ftpPopup selectedItem] title]]);
            LSSetDefaultHandlerForURLScheme(CFSTR("mms"), (__bridge CFStringRef)[self bundleIdentifierForApplicationName:[[_urlhandler_mmsPopup selectedItem] title]]);
            LSSetDefaultHandlerForURLScheme(CFSTR("mmsh"), (__bridge CFStringRef)[self bundleIdentifierForApplicationName:[[_urlhandler_mmsPopup selectedItem] title]]);
            LSSetDefaultHandlerForURLScheme(CFSTR("rtmp"), (__bridge CFStringRef)[self bundleIdentifierForApplicationName:[[_urlhandler_rtmpPopup selectedItem] title]]);
            LSSetDefaultHandlerForURLScheme(CFSTR("rtp"), (__bridge CFStringRef)[self bundleIdentifierForApplicationName:[[_urlhandler_rtpPopup selectedItem] title]]);
            LSSetDefaultHandlerForURLScheme(CFSTR("rtsp"), (__bridge CFStringRef)[self bundleIdentifierForApplicationName:[[_urlhandler_rtspPopup selectedItem] title]]);
            LSSetDefaultHandlerForURLScheme(CFSTR("sftp"), (__bridge CFStringRef)[self bundleIdentifierForApplicationName:[[_urlhandler_sftpPopup selectedItem] title]]);
            LSSetDefaultHandlerForURLScheme(CFSTR("smb"), (__bridge CFStringRef)[self bundleIdentifierForApplicationName:[[_urlhandler_smbPopup selectedItem] title]]);
            LSSetDefaultHandlerForURLScheme(CFSTR("udp"), (__bridge CFStringRef)[self bundleIdentifierForApplicationName:[[_urlhandler_udpPopup selectedItem] title]]);
        }
    }
}

#pragma mark -
#pragma mark Hotkey actions

- (void)showHotkeySettings
{
    [self showSettingsForCategory:_hotkeyPreferencesController.view];
}

- (void)showMediaLibrarySettings
{
    [self showSettingsForCategory:_mediaLibraryView];
}


@end
