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
#import "VLCSubtitlesPreferencesController.h"
#import "VLCInterfacePreferencesController.h"
#import "VLCPreferencesControlHelper.h"

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

    VLCMediaLibraryFolderManagementController *_mediaLibraryManagementController;

    intf_thread_t *p_intf;
}
@property (nonatomic, strong) IBOutlet VLCHotkeyPreferencesController *hotkeyPreferencesController;
@property (nonatomic, strong) IBOutlet VLCAudioPreferencesController *audioPreferencesController;
@property (nonatomic, strong) IBOutlet VLCVideoPreferencesController *videoPreferencesController;
@property (nonatomic, strong) IBOutlet VLCInputPreferencesController *inputPreferencesController;
@property (nonatomic, strong) IBOutlet VLCSubtitlesPreferencesController *subtitlesPreferencesController;
@property (nonatomic, strong) IBOutlet VLCInterfacePreferencesController *interfacePreferencesController;
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
    [_subtitlesPreferencesController setupControls];
    [_interfacePreferencesController setupControls];

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

- (void)resetControls
{

    [_interfacePreferencesController resetControls];

    [_audioPreferencesController resetControls];

    [_videoPreferencesController resetControls];

    [_inputPreferencesController resetControls];

    [_subtitlesPreferencesController resetControls];

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
        [_subtitlesPreferencesController closeFontPanel];
        [self.window orderOut: sender];
    } else if (sender == _saveButton) {
        [self saveChangedSettings];
        [_subtitlesPreferencesController closeFontPanel];
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

+ (BOOL)updateRightToLeftSettings
{
    return [VLCInterfacePreferencesController updateRightToLeftSettings];
}

- (void)saveChangedSettings
{
    [_interfacePreferencesController saveChangedSettings];

    [_audioPreferencesController saveChangedSettings];

    [_videoPreferencesController saveChangedSettings];

    [_inputPreferencesController saveChangedSettings];

    [_subtitlesPreferencesController saveChangedSettings];

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

- (void)showInterfaceSettings
{
    [self showSettingsForCategory:_interfacePreferencesController.view];
}

- (void)showAudioSettings
{
    [self showSettingsForCategory:_audioPreferencesController.view];
}

- (void)showVideoSettings
{
    [self showSettingsForCategory:_videoPreferencesController.view];
}

- (void)showOSDSettings
{
    [self showSettingsForCategory:_subtitlesPreferencesController.view];
}

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
