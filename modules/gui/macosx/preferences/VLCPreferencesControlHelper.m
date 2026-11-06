/*****************************************************************************
 * VLCPreferencesControlHelper.m: Preferences control setup
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

#import "VLCPreferencesControlHelper.h"
#import <vlc_common.h>
#import <vlc_configuration.h>
#import <vlc_plugin.h>
#import "extensions/NSString+Helpers.h"
#import "main/VLCMain.h"

@implementation VLCPreferencesControlHelper

+ (void)setupButton: (NSPopUpButton *)object forStringList: (const char *)name
{
    module_config_t *p_item;

    [object removeAllItems];
    p_item = config_FindConfig(name);
    /* serious problem, if no item found */
    assert(p_item);

    char **values, **texts;
    ssize_t count = config_GetPszChoices(name, &values, &texts);
    if (count < 0) {
        msg_Err(getIntf(), "Cannot get choices for %s", name);
        return;
    }
    for (ssize_t i = 0; i < count && texts; i++) {
        if (texts[i] == NULL || values[i] == NULL)
            continue;

        if (strcmp(texts[i], "") != 0) {
            NSMenuItem *mi = [[NSMenuItem alloc] initWithTitle: toNSStr(texts[i]) action: NULL keyEquivalent: @""];
            [mi setRepresentedObject: toNSStr(values[i])];
            [[object menu] addItem:mi];

            if (p_item->value.psz && !strcmp(p_item->value.psz, values[i]))
                [object selectItem: [object lastItem]];
        } else {
            [[object menu] addItem: [NSMenuItem separatorItem]];
        }

        free(texts[i]);
        free(values[i]);
    }

    free(texts);
    free(values);

    if (p_item->psz_longtext)
        [object setToolTip: NSTR(p_item->psz_longtext)];
}

// just for clarification that this is a module list
+ (void)setupButton: (NSPopUpButton *)object forModuleList: (const char *)name
{
    [self setupButton: object forStringList: name];
}

+ (void)setupButton: (NSButton *)object forBoolValue: (const char *)name
{
    [object setState: config_GetInt(name)];
    [object setToolTip: NSTR(config_GetLabel(name))];
}

+ (void)setupField:(NSTextField *)object forOption:(const char *)psz_option
{
    char *psz_tmp = config_GetPsz(psz_option);
    [object setStringValue: toNSStr(psz_tmp)];
    [object setToolTip: NSTR(config_GetLabel(psz_option))];
    free(psz_tmp);
}

@end
