/*****************************************************************************
 * VLCHotkeyPreferencesController.m: Hotkey preferences
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

#import "VLCHotkeyPreferencesController.h"
#import <vlc_common.h>
#import <vlc_configuration.h>
#import <vlc_modules.h>
#import <vlc_plugin.h>
#import "extensions/NSString+Helpers.h"
#import "main/VLCMain.h"

@interface VLCHotkeyPreferencesController ()
{
    BOOL _hotkeyChanged;
    NSArray *_hotkeyDescriptions;
    NSArray *_hotkeyNames;
    NSArray *_hotkeysNonUseableKeys;
    NSMutableArray *_hotkeySettings;
    NSString *_keyInTransition;
}
@end

@implementation VLCHotkeyPreferencesController

- (void)setupControls
{
    [_changeWindow setTitle:_NS("Change Hotkey")];
    [_changeCancelButton setTitle:_NS("Cancel")];
    [_changeOKButton setTitle:_NS("OK")];
    [_changeClearButton setTitle:_NS("Clear")];
    [_descriptionLabel setStringValue:_NS("Double-click an action to change the associated hotkey:")];
    [[[_listbox tableColumnWithIdentifier:@"action"] headerCell] setStringValue:_NS("Action")];
    [[[_listbox tableColumnWithIdentifier:@"shortcut"] headerCell] setStringValue:_NS("Shortcut")];
    [_mediaKeysCheckbox setTitle:_NS("Control playback with media keys")];

    _hotkeysNonUseableKeys = [NSArray arrayWithObjects:@"Command-c", @"Command-x", @"Command-v", @"Command-a", @"Command-," , @"Command-h", @"Command-Alt-h", @"Command-Shift-o", @"Command-o", @"Command-d", @"Command-n", @"Command-s", @"Command-l", @"Command-r", @"Command-3", @"Command-m", @"Command-w", @"Command-Shift-w", @"Command-Shift-c", @"Command-Shift-p", @"Command-i", @"Command-e", @"Command-Shift-e", @"Command-b", @"Command-Shift-m", @"Command-Ctrl-m", @"Command-?", @"Command-Alt-?", @"Command-Shift-f", nil];
    _listbox.dataSource = self;
    _listbox.target = self;
    _listbox.doubleAction = @selector(hotkeyTableDoubleClick:);
    _changeWindow.hotkeyDelegate = self;
    for (NSButton *button in @[_changeCancelButton, _changeOKButton,
                               _changeClearButton, _mediaKeysCheckbox]) {
        button.target = self;
        button.action = @selector(hotkeySettingChanged:);
    }
}

- (void)resetControls
{
    _hotkeySettings = [[NSMutableArray alloc] init];
    NSMutableArray *tempArray_desc = [[NSMutableArray alloc] init];
    NSMutableArray *tempArray_names = [[NSMutableArray alloc] init];

    /* Get the main Module */
    module_t *p_main = module_get_main();
    assert(p_main);
    unsigned confsize;
    module_config_t *p_config;

    p_config = module_config_get (p_main, &confsize);

    for (size_t i = 0; i < confsize; i++) {
        module_config_t *p_item = p_config + i;

        if (p_item->i_type == CONFIG_ITEM_KEY
           && strncmp(p_item->psz_name, "global-", 7) != 0
           && !EMPTY_STR(p_item->psz_text)) {
            [tempArray_desc addObject: NSTR(p_item->psz_text)];
            [tempArray_names addObject: toNSStr(p_item->psz_name)];
            if (p_item->value.psz)
                [_hotkeySettings addObject: toNSStr(p_item->value.psz)];
            else
                [_hotkeySettings addObject: [NSString string]];
        }
    }
    module_config_free (p_config);

    _hotkeyDescriptions = [[NSArray alloc] initWithArray:tempArray_desc copyItems: YES];
    _hotkeyNames = [[NSArray alloc] initWithArray:tempArray_names copyItems: YES];

    [_listbox reloadData];
    _mediaKeysCheckbox.state = config_GetInt("macosx-mediakeys");
    _mediaKeysCheckbox.toolTip = NSTR(config_GetLabel("macosx-mediakeys"));
}

- (void)saveChangedSettings
{
    if (_hotkeyChanged) {
        NSUInteger hotKeyCount = [_hotkeySettings count];
        for (NSUInteger i = 0; i < hotKeyCount; i++)
            config_PutPsz([[_hotkeyNames objectAtIndex:i] UTF8String], [[_hotkeySettings objectAtIndex:i]UTF8String]);
        _hotkeyChanged = NO;

        config_PutInt("macosx-mediakeys", [_mediaKeysCheckbox state]);
    }
}

- (void)hotkeyTableDoubleClick:(id)object
{
    // -1 is header
    if ([_listbox clickedRow] >= 0)
        [self hotkeySettingChanged:_listbox];
}

- (IBAction)hotkeySettingChanged:(id)sender
{
    if (sender == _listbox) {
        [_changeLabel setStringValue: [NSString stringWithFormat: _NS("Press new keys for\n\"%@\""),
                                               [_hotkeyDescriptions objectAtIndex:[_listbox selectedRow]]]];
        [_changeKeysLabel setStringValue: OSXStringKeyToString([_hotkeySettings objectAtIndex:[_listbox selectedRow]])];
        [_changeTakenLabel setStringValue: @""];
        [_changeWindow setInitialFirstResponder: [_changeWindow contentView]];
        [_changeWindow makeFirstResponder: [_changeWindow contentView]];
        [NSApp runModalForWindow:_changeWindow];
    } else if (sender == _changeCancelButton) {
        [NSApp stopModal];
        [_changeWindow close];
    } else if (sender == _changeOKButton) {
        NSInteger i_returnValue;
        if (! _keyInTransition) {
            [NSApp stopModal];
            [_changeWindow close];
            NSAssert(1, @"internal error prevented the hotkey switch");
            return;
        }

        _hotkeyChanged = YES;

        i_returnValue = [_hotkeySettings indexOfObject: _keyInTransition];
        if (i_returnValue != NSNotFound)
            [_hotkeySettings replaceObjectAtIndex: i_returnValue withObject: [NSString string]];
        NSString *tempString;
        tempString = [_keyInTransition stringByReplacingOccurrencesOfString:@"-" withString:@"+"];
        i_returnValue = [_hotkeySettings indexOfObject: tempString];
        if (i_returnValue != NSNotFound)
            [_hotkeySettings replaceObjectAtIndex: i_returnValue withObject: [NSString string]];

        [_hotkeySettings replaceObjectAtIndex: [_listbox selectedRow] withObject:_keyInTransition];

        [NSApp stopModal];
        [_changeWindow close];

        [_listbox reloadData];
    } else if (sender == _changeClearButton) {
        [_hotkeySettings replaceObjectAtIndex: [_listbox selectedRow] withObject: [NSString string]];
        _hotkeyChanged = YES;
        [NSApp stopModal];
        [_changeWindow close];
        [_listbox reloadData];
    }
}

- (NSInteger)numberOfRowsInTableView:(NSTableView *)aTableView
{
    return [_hotkeySettings count];
}

- (id)tableView:(NSTableView *)aTableView objectValueForTableColumn:(NSTableColumn *)aTableColumn row:(NSInteger)rowIndex
{
    NSString * identifier = [aTableColumn identifier];

    if ([identifier isEqualToString: @"action"])
        return [_hotkeyDescriptions objectAtIndex:rowIndex];
    else if ([identifier isEqualToString: @"shortcut"])
        return OSXStringKeyToString([_hotkeySettings objectAtIndex:rowIndex]);
    else {
        msg_Err(getIntf(), "unknown TableColumn identifier (%s)!", [identifier UTF8String]);
        return NULL;
    }
}

- (BOOL)changeHotkeyTo: (NSString *)theKey
{
    NSInteger i_returnValue, i_returnValue2;
    i_returnValue = [_hotkeysNonUseableKeys indexOfObject: theKey];

    if (i_returnValue != NSNotFound || [theKey isEqualToString:@""]) {
        [_changeKeysLabel setStringValue: _NS("Invalid combination")];
        [_changeTakenLabel setStringValue: _NS("Regrettably, these keys cannot be assigned as hotkey shortcuts.")];
        [_changeOKButton setEnabled: NO];
        return NO;
    } else {
        [_changeKeysLabel setStringValue: OSXStringKeyToString(theKey)];

        i_returnValue = [_hotkeySettings indexOfObject: theKey];
        i_returnValue2 = [_hotkeySettings indexOfObject: [theKey stringByReplacingOccurrencesOfString:@"-" withString:@"+"]];
        if (i_returnValue != NSNotFound)
            [_changeTakenLabel setStringValue: [NSString stringWithFormat:
                                                         _NS("This combination is already taken by \"%@\"."),
                                                         [_hotkeyDescriptions objectAtIndex:i_returnValue]]];
        else if (i_returnValue2 != NSNotFound)
            [_changeTakenLabel setStringValue: [NSString stringWithFormat:
                                                         _NS("This combination is already taken by \"%@\"."),
                                                         [_hotkeyDescriptions objectAtIndex:i_returnValue2]]];
        else
            [_changeTakenLabel setStringValue: @""];

        [_changeOKButton setEnabled: YES];
        _keyInTransition = theKey;
        return YES;
    }
}

@end
