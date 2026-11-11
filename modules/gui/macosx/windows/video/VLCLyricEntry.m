/*****************************************************************************
 * Copyright (C) 2026 VLC authors and VideoLAN
 *
 * Authors: Serhii Bykov <esphynox@gmail.com>
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2 of the License, or
 * (at your option) any later version.
 *****************************************************************************/

#import "VLCLyricEntry.h"

static NSString * const VLCLyricEntrySeparator = @"\x1E";
static NSString * const VLCLyricFieldSeparator = @"\x1F";

@implementation VLCLyricEntry

- (instancetype)initWithParts:(NSArray<NSString *> *)parts
{
    if (parts.count < 2) {
        return nil;
    }
    return [self initWithTimeMs:parts[0].longLongValue text:parts[1]];
}

- (instancetype)initWithTimeMs:(long long)timeMs text:(NSString *)text
{
    self = [super init];
    if (self) {
        _timeMs = timeMs;
        _text = [text copy];
    }
    return self;
}

+ (NSArray<VLCLyricEntry *> *)entriesFromSYLTData:(NSString *)data
{
    NSMutableArray<VLCLyricEntry *> * const entries = [NSMutableArray array];
    for (NSString * const rawEntry in [data componentsSeparatedByString:VLCLyricEntrySeparator]) {
        if (rawEntry.length == 0) {
            continue;
        }
        NSArray<NSString *> * const parts = [rawEntry componentsSeparatedByString:VLCLyricFieldSeparator];
        VLCLyricEntry * const entry = [[VLCLyricEntry alloc] initWithParts:parts];
        if (entry) {
            [entries addObject:entry];
        }
    }
    return [entries copy];
}

@end
