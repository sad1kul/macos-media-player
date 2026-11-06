/*****************************************************************************
 * NSColor+VLCAdditions.m: MacOS X interface module
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

#import "NSColor+VLCAdditions.h"

NSString * const VLCVividockAccentIdentifierNeonTeal = @"neon-teal";
NSString * const VLCVividockAccentIdentifierElectricCyan = @"electric-cyan";
NSString * const VLCVividockAccentIdentifierSapphireBlue = @"sapphire-blue";
NSString * const VLCVividockAccentIdentifierNeonGreen = @"neon-green";
NSString * const VLCVividockAccentDidChangeNotification = @"VLCVividockAccentDidChangeNotification";

static NSString * const VLCVividockAccentDefaultsKey = @"VLCVividockAccentColor";
static NSString *VLCVividockPreviewAccentIdentifier;

@implementation NSColor (VLCAdditions)

+ (NSColor *)VLCAccentColor
{
    return self.VLCVividockAccentColor;
}

+ (NSColor *)VLCOrangeElementColor
{
    return [NSColor colorWithRed:1. green:.38 blue:.04 alpha:1.];
}

+ (NSColor *)VLCSubtlerAccentColor
{
    return [NSColor.VLCAccentColor colorWithAlphaComponent:0.8];
}

+ (NSColor *)VLClibrarySubtitleColor
{
    return [NSColor colorWithRed:0.52 green:0.57 blue:0.61 alpha:1.];
}

+ (NSColor *)VLClibraryAnnotationColor
{
    return [NSColor whiteColor];
}

+ (NSColor *)VLClibraryAnnotationBackgroundColor
{
    return [NSColor colorWithRed:0. green:0. blue:0. alpha:.2];
}

+ (NSColor *)VLClibrarySeparatorLightColor
{
    return [NSColor colorWithRed:0.89 green:0.91 blue:0.93 alpha:1.];
}

+ (NSColor *)VLClibrarySeparatorDarkColor
{
    return [NSColor colorWithRed:0.11 green:0.09 blue:0.07 alpha:1.];
}

+ (NSColor *)VLClibraryProgressIndicatorBackgroundColor
{
    return [NSColor colorWithRed:37./255. green:41./255. blue:44./255. alpha:.8];
}

+ (NSColor *)VLCSliderFillColor
{
    return NSColor.VLCAccentColor;
}

+ (NSColor *)VLCSliderLightBackgroundColor
{
    return [NSColor colorWithCalibratedWhite:0.5 alpha:0.5];
}

+ (NSColor *)VLCSliderDarkBackgroundColor
{
    return [NSColor colorWithCalibratedWhite:1 alpha:0.2];
}

+ (NSColor *)VLCLightSubtleBorderColor
{
    return [NSColor colorWithCalibratedWhite:0.85 alpha:1.0];
}

+ (NSColor *)VLCDarkSubtleBorderColor
{
    return [NSColor colorWithCalibratedWhite:0.3 alpha:1.0];
}

+ (NSColor *)VLCSubtleBorderColor
{
    return [NSColor colorNamed:@"VLCSubtleBorderColor"];
}

+ (NSArray<NSString *> *)VLCVividockAccentIdentifiers
{
    return @[
        VLCVividockAccentIdentifierNeonTeal,
        VLCVividockAccentIdentifierElectricCyan,
        VLCVividockAccentIdentifierSapphireBlue,
        VLCVividockAccentIdentifierNeonGreen,
    ];
}

+ (BOOL)VLCIsValidVividockAccentIdentifier:(NSString *)identifier
{
    return identifier != nil && [self.VLCVividockAccentIdentifiers containsObject:identifier];
}

+ (NSString *)VLCVividockSavedAccentIdentifier
{
    NSString * const identifier = [NSUserDefaults.standardUserDefaults stringForKey:VLCVividockAccentDefaultsKey];
    return [self VLCIsValidVividockAccentIdentifier:identifier]
        ? identifier
        : VLCVividockAccentIdentifierNeonTeal;
}

+ (NSString *)VLCVividockAccentIdentifier
{
    return [self VLCIsValidVividockAccentIdentifier:VLCVividockPreviewAccentIdentifier]
        ? VLCVividockPreviewAccentIdentifier
        : self.VLCVividockSavedAccentIdentifier;
}

+ (NSColor *)VLCVividockAccentColor
{
    return [self VLCVividockAccentColorForIdentifier:self.VLCVividockAccentIdentifier];
}

+ (NSString *)VLCVividockAccentNameForIdentifier:(NSString *)identifier
{
    if ([identifier isEqualToString:VLCVividockAccentIdentifierElectricCyan])
        return @"Electric Cyan";
    if ([identifier isEqualToString:VLCVividockAccentIdentifierSapphireBlue])
        return @"Sapphire Blue";
    if ([identifier isEqualToString:VLCVividockAccentIdentifierNeonGreen])
        return @"Neon Green";
    return @"Neon Teal";
}

+ (NSColor *)VLCVividockAccentColorForIdentifier:(NSString *)identifier
{
    if ([identifier isEqualToString:VLCVividockAccentIdentifierElectricCyan])
        return [NSColor colorWithSRGBRed:37. / 255. green:188. / 255. blue:1. alpha:1.];
    if ([identifier isEqualToString:VLCVividockAccentIdentifierSapphireBlue])
        return [NSColor colorWithSRGBRed:82. / 255. green:140. / 255. blue:1. alpha:1.];
    if ([identifier isEqualToString:VLCVividockAccentIdentifierNeonGreen])
        return [NSColor colorWithSRGBRed:168. / 255. green:1. blue:69. / 255. alpha:1.];
    return [NSColor colorWithSRGBRed:39. / 255. green:230. / 255. blue:195. / 255. alpha:1.];
}

+ (void)VLCPostVividockAccentChange
{
    [NSNotificationCenter.defaultCenter postNotificationName:VLCVividockAccentDidChangeNotification
                                                       object:nil];
}

+ (void)VLCPreviewVividockAccentIdentifier:(NSString *)identifier
{
    VLCVividockPreviewAccentIdentifier = [self VLCIsValidVividockAccentIdentifier:identifier]
        ? [identifier copy]
        : VLCVividockAccentIdentifierNeonTeal;
    [self VLCPostVividockAccentChange];
}

+ (void)VLCSaveVividockAccentIdentifier:(NSString *)identifier
{
    NSString * const validIdentifier = [self VLCIsValidVividockAccentIdentifier:identifier]
        ? identifier
        : VLCVividockAccentIdentifierNeonTeal;
    [NSUserDefaults.standardUserDefaults setObject:validIdentifier forKey:VLCVividockAccentDefaultsKey];
    VLCVividockPreviewAccentIdentifier = nil;
    [self VLCPostVividockAccentChange];
}

+ (void)VLCCancelVividockAccentPreview
{
    VLCVividockPreviewAccentIdentifier = nil;
    [self VLCPostVividockAccentChange];
}

@end
