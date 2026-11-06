/*****************************************************************************
 * VLCInputPreferencesController.m: Input and codecs preferences
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

#import "VLCInputPreferencesController.h"
#import "VLCPreferencesControlHelper.h"
#import <vlc_common.h>
#import <vlc_configuration.h>
#import "extensions/NSString+Helpers.h"
#import "main/VLCMain.h"

static void saveIntList(NSPopUpButton *object, const char *name)
{
    NSNumber *value = object.selectedItem.representedObject;
    if (value)
        config_PutInt(name, value.intValue);
}

@implementation VLCInputPreferencesController
{
    BOOL _inputSettingChanged;
    NSOpenPanel *_selectFolderPanel;
}

- (void)setupControls
{
    /* input */
    [_recordBox setTitle: _NS("Record directory or filename")];
    [_recordButton setTitle: _NS("Browse...")];
    [_recordButton setToolTip: _NS("Directory or filename where the records will be stored")];
    [_aviLabel setStringValue: _NS("Repair AVI Files")];
    [_cachelevelLabel setStringValue: _NS("Default Caching Level")];
    [_cachingBox setTitle: _NS("Caching")];
    [_cachelevelCustomLabel setStringValue: _NS("Use the complete preferences to configure custom caching values for each access module.")];
    [_muxBox setTitle: _NS("Codecs / Muxers")];
    [_netBox setTitle: _NS("Network")];
    [_hardwareAccelerationCheckbox setTitle: _NS("Enable hardware acceleration")];
    [_skipLoopLabel setStringValue: _NS("Skip the loop filter for H.264 decoding")];
    [_urlhandlerButton setTitle: _NS("Edit default application settings for network protocols")];
    [_fastSeekCheckbox setTitle: _NS("Fast seek")];

    /* url handler */
    [_urlhandlerTitleLabel setStringValue: _NS("Open network streams using the following protocols")];
    [_urlhandlerSubtitleLabel setStringValue: _NS("Note that these are system-wide settings.")];
    [_urlhandlerSaveButton setTitle: _NS("Save")];
    [_urlhandlerCancelButton setTitle: _NS("Cancel")];
}

- (void)resetControls
{
    [VLCPreferencesControlHelper setupField:_recordTextField forOption:"input-record-path"];

    [VLCPreferencesControlHelper setupButton:_hardwareAccelerationCheckbox forBoolValue: "videotoolbox"];
    [VLCPreferencesControlHelper setupButton:_fastSeekCheckbox forBoolValue: "input-fast-seek"];
    [VLCPreferencesControlHelper setupButton:_aviPopup forIntList: "avi-index"];
    [VLCPreferencesControlHelper setupButton:_skipLoopPopup forIntList: "avcodec-skiploopfilter"];

    [_cachelevelPopup removeAllItems];
    NSMenuItem *item = [[_cachelevelPopup menu] addItemWithTitle:_NS("Custom") action:nil keyEquivalent:@""];
    [item setTag: 0];
    item = [[_cachelevelPopup menu] addItemWithTitle:_NS("Lowest Latency") action:nil keyEquivalent:@""];
    [item setTag: 100];
    item = [[_cachelevelPopup menu] addItemWithTitle:_NS("Low Latency") action:nil keyEquivalent:@""];
    [item setTag: 200];
    item = [[_cachelevelPopup menu] addItemWithTitle:_NS("Normal") action:nil keyEquivalent:@""];
    [item setTag: 300];
    item = [[_cachelevelPopup menu] addItemWithTitle:_NS("Higher Latency") action:nil keyEquivalent:@""];
    [item setTag: 500];
    item = [[_cachelevelPopup menu] addItemWithTitle:_NS("Highest Latency") action:nil keyEquivalent:@""];
    [item setTag: 1000];

    #define TestCaC(name, factor) \
    cache_equal = cache_equal && \
    (i_cache * factor == config_GetInt(name));

    /* Select the accurate value of the PopupButton */
    bool cache_equal = true;
    int i_cache = (int)config_GetInt("file-caching");

    TestCaC("network-caching", 10/3);
    TestCaC("disc-caching", 1);
    TestCaC("live-caching", 1);
    if (cache_equal) {
        [_cachelevelPopup selectItemWithTag: i_cache];
        [_cachelevelCustomLabel setHidden: YES];
    } else {
        [_cachelevelPopup selectItemWithTitle: _NS("Custom")];
        [_cachelevelCustomLabel setHidden: NO];
    }
    #undef TestCaC
}

- (void)saveChangedSettings
{
    if (_inputSettingChanged) {
        config_PutPsz("input-record-path", [[_recordTextField stringValue] UTF8String]);

        config_PutInt("videotoolbox", [_hardwareAccelerationCheckbox state]);
        config_PutInt("input-fast-seek", [_fastSeekCheckbox state]);

        saveIntList(_aviPopup, "avi-index");

        saveIntList(_skipLoopPopup, "avcodec-skiploopfilter");

        #define CaC(name, factor) config_PutInt(name, [[_cachelevelPopup selectedItem] tag] * factor)
        if ([[_cachelevelPopup selectedItem] tag] == 0) {
            msg_Dbg(getIntf(), "Custom chosen, not adjusting cache values");
        } else {
            msg_Dbg(getIntf(), "Adjusting all cache values to: %i", (int)[[_cachelevelPopup selectedItem] tag]);
            CaC("file-caching", 1);
            CaC("network-caching", 10/3);
            CaC("disc-caching", 1);
            CaC("live-caching", 1);
        }
        #undef CaC
        _inputSettingChanged = NO;
    }
}

- (IBAction)inputSettingChanged:(id)sender
{
    if (sender == _cachelevelPopup) {
        if ([[[_cachelevelPopup selectedItem] title] isEqualToString: _NS("Custom")])
            [_cachelevelCustomLabel setHidden: NO];
        else
            [_cachelevelCustomLabel setHidden: YES];
    } else if (sender == _recordButton) {
        _selectFolderPanel = [[NSOpenPanel alloc] init];
        [_selectFolderPanel setCanChooseDirectories: YES];
        [_selectFolderPanel setCanChooseFiles: YES];
        [_selectFolderPanel setResolvesAliases: YES];
        [_selectFolderPanel setAllowsMultipleSelection: NO];
        [_selectFolderPanel setMessage: _NS("Choose the directory or filename where the records will be stored.")];
        [_selectFolderPanel setCanCreateDirectories: YES];
        [_selectFolderPanel setPrompt: _NS("Choose")];
        [_selectFolderPanel beginSheetModalForWindow:_view.window completionHandler: ^(NSInteger returnCode) {
            if (returnCode == NSModalResponseOK)
            {
                [self->_recordTextField setStringValue: [[self->_selectFolderPanel URL] path]];
                self->_inputSettingChanged = YES;
            }
        }];

        return;
    }

    _inputSettingChanged = YES;
}

- (void)controlTextDidChange:(NSNotification *)notification
{
    _inputSettingChanged = YES;
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
    if (sender == _urlhandlerButton) {

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

        fillUrlHandlerPopup(@"ftp", _urlhandlerFtpPopup);
        fillUrlHandlerPopup(@"mms", _urlhandlerMmsPopup);
        fillUrlHandlerPopup(@"rtmp", _urlhandlerRtmpPopup);
        fillUrlHandlerPopup(@"rtp", _urlhandlerRtpPopup);
        fillUrlHandlerPopup(@"rtsp", _urlhandlerRtspPopup);
        fillUrlHandlerPopup(@"sftp", _urlhandlerSftpPopup);
        fillUrlHandlerPopup(@"smb", _urlhandlerSmbPopup);
        fillUrlHandlerPopup(@"udp", _urlhandlerUdpPopup);

        [self.view.window beginSheet:_urlhandlerWindow completionHandler:nil];
    } else {
        [_urlhandlerWindow orderOut:sender];
        [NSApp endSheet:_urlhandlerWindow];

        if (sender == _urlhandlerSaveButton) {
            LSSetDefaultHandlerForURLScheme(CFSTR("ftp"), (__bridge CFStringRef)[self bundleIdentifierForApplicationName:[[_urlhandlerFtpPopup selectedItem] title]]);
            LSSetDefaultHandlerForURLScheme(CFSTR("mms"), (__bridge CFStringRef)[self bundleIdentifierForApplicationName:[[_urlhandlerMmsPopup selectedItem] title]]);
            LSSetDefaultHandlerForURLScheme(CFSTR("mmsh"), (__bridge CFStringRef)[self bundleIdentifierForApplicationName:[[_urlhandlerMmsPopup selectedItem] title]]);
            LSSetDefaultHandlerForURLScheme(CFSTR("rtmp"), (__bridge CFStringRef)[self bundleIdentifierForApplicationName:[[_urlhandlerRtmpPopup selectedItem] title]]);
            LSSetDefaultHandlerForURLScheme(CFSTR("rtp"), (__bridge CFStringRef)[self bundleIdentifierForApplicationName:[[_urlhandlerRtpPopup selectedItem] title]]);
            LSSetDefaultHandlerForURLScheme(CFSTR("rtsp"), (__bridge CFStringRef)[self bundleIdentifierForApplicationName:[[_urlhandlerRtspPopup selectedItem] title]]);
            LSSetDefaultHandlerForURLScheme(CFSTR("sftp"), (__bridge CFStringRef)[self bundleIdentifierForApplicationName:[[_urlhandlerSftpPopup selectedItem] title]]);
            LSSetDefaultHandlerForURLScheme(CFSTR("smb"), (__bridge CFStringRef)[self bundleIdentifierForApplicationName:[[_urlhandlerSmbPopup selectedItem] title]]);
            LSSetDefaultHandlerForURLScheme(CFSTR("udp"), (__bridge CFStringRef)[self bundleIdentifierForApplicationName:[[_urlhandlerUdpPopup selectedItem] title]]);
        }
    }
}

@end
