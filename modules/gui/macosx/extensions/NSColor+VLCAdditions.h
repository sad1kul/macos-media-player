/*****************************************************************************
 * NSColor+VLCAdditions.h: MacOS X interface module
 *****************************************************************************
 * Copyright (C) 2019 VLC authors and VideoLAN
 *
 * Authors: Felix Paul Kühne <fkuehne # videolan -dot- org>
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

NS_ASSUME_NONNULL_BEGIN

extern NSString * const VLCVividockAccentIdentifierNeonTeal;
extern NSString * const VLCVividockAccentIdentifierElectricCyan;
extern NSString * const VLCVividockAccentIdentifierSapphireBlue;
extern NSString * const VLCVividockAccentIdentifierNeonGreen;
extern NSString * const VLCVividockAccentDidChangeNotification;

@interface NSColor (VLCAdditions)

@property (class, readonly) NSColor *VLCAccentColor;
@property (class, readonly) NSColor *VLCSubtlerAccentColor;
@property (class, readonly) NSColor *VLClibrarySubtitleColor;
@property (class, readonly) NSColor *VLClibraryAnnotationColor;
@property (class, readonly) NSColor *VLClibraryAnnotationBackgroundColor;
@property (class, readonly) NSColor *VLClibrarySeparatorLightColor;
@property (class, readonly) NSColor *VLClibrarySeparatorDarkColor;
@property (class, readonly) NSColor *VLClibraryProgressIndicatorBackgroundColor;
@property (class, readonly) NSColor *VLCSliderFillColor;
@property (class, readonly) NSColor *VLCSliderLightBackgroundColor;
@property (class, readonly) NSColor *VLCSliderDarkBackgroundColor;
@property (class, readonly) NSColor *VLCLightSubtleBorderColor;
@property (class, readonly) NSColor *VLCDarkSubtleBorderColor;
@property (class, readonly) NSColor *VLCSubtleBorderColor;

@property (class, readonly) NSArray<NSString *> *VLCVividockAccentIdentifiers;
@property (class, readonly) NSString *VLCVividockSavedAccentIdentifier;
@property (class, readonly) NSString *VLCVividockAccentIdentifier;
@property (class, readonly) NSColor *VLCVividockAccentColor;

+ (NSString *)VLCVividockAccentNameForIdentifier:(NSString *)identifier;
+ (NSColor *)VLCVividockAccentColorForIdentifier:(NSString *)identifier;
+ (void)VLCPreviewVividockAccentIdentifier:(NSString *)identifier;
+ (void)VLCSaveVividockAccentIdentifier:(NSString *)identifier;
+ (void)VLCCancelVividockAccentPreview;

@end

NS_ASSUME_NONNULL_END
