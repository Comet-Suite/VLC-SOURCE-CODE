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

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface VLCLyricEntry : NSObject

@property (nonatomic, readonly) long long timeMs;
@property (nonatomic, copy, readonly) NSString *text;

- (nullable instancetype)initWithParts:(NSArray<NSString *> *)parts;
- (instancetype)initWithTimeMs:(long long)timeMs text:(NSString *)text NS_DESIGNATED_INITIALIZER;
- (instancetype)init NS_UNAVAILABLE;

+ (NSArray<VLCLyricEntry *> *)entriesFromSYLTData:(nullable NSString *)data;

@end

NS_ASSUME_NONNULL_END
