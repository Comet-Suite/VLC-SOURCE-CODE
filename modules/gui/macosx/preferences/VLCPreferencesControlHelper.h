/*****************************************************************************
 * VLCPreferencesControlHelper.h: Preferences control setup
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

@interface VLCPreferencesControlHelper : NSObject
+ (void)setupButton:(NSPopUpButton *)object forStringList:(const char *)name;
+ (void)setupButton:(NSPopUpButton *)object forModuleList:(const char *)name;
+ (void)setupButton:(NSPopUpButton *)object forIntList:(const char *)name;
+ (void)setupButton:(NSButton *)object forBoolValue:(const char *)name;
+ (void)setupField:(NSTextField *)object forOption:(const char *)name;
@end
