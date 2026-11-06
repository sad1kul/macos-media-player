/*****************************************************************************
 * NSView+VLCAdditions.m: MacOS X interface module
 *****************************************************************************
 * Copyright (C) 2013-2019 VLC authors and VideoLAN
 *
 * Authors: David Fuhrmann <dfuhrmann # videolan.org>
 *          Felix Paul Kühne <fkuehne at videolan dot org>
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

#import "NSView+VLCAdditions.h"

#import "NSAppearance+VLCAdditions.h"
#import "NSColor+VLCAdditions.h"

static NSString * const VLCVividockGlassBackdropIdentifier = @"VLCVividockGlassBackdrop";
static NSString * const VLCVividockGoldenGateGlassIdentifier = @"VLCVividockGoldenGateGlass";

@implementation NSView (VLCAdditions)

+ (instancetype)fromNibWithOwner:(id)owner
{
    return [self fromNibNamed:NSStringFromClass(self) withClass:self withOwner:owner];
}

+ (instancetype)fromNibNamed:(NSString *)nibName withClass:(Class)viewClass withOwner:(id)owner
{
    /* the following code saves us an instance of NSViewController which we don't need */
    NSNib *nib = [[NSNib alloc] initWithNibNamed:nibName bundle:nil];
    NSArray *topLevelObjects;
    if (![nib instantiateWithOwner:owner topLevelObjects:&topLevelObjects]) {
        NSAssert(1, @"Failed to load nib file to show view");
        return nil;
    }

    for (id topLevelObject in topLevelObjects) {
        if ([topLevelObject isKindOfClass:viewClass]) {
            return topLevelObject;
            break;
        }
    }

    return nil;
}

- (BOOL)shouldShowDarkAppearance
{
    return self.effectiveAppearance.shouldShowDarkAppearance;
}

- (void)enableSubviews:(BOOL)enabled
{
    for (NSView *view in [self subviews]) {
        [view enableSubviews:enabled];

        // enable NSControl
        if ([view respondsToSelector:@selector(setEnabled:)]) {
            [(NSControl *)view setEnabled:enabled];
        }
        // also "enable / disable" text views
        if ([view respondsToSelector:@selector(setTextColor:)]) {
            if (enabled == NO) {
                [(NSTextField *)view setTextColor:[NSColor disabledControlTextColor]];
            } else {
                [(NSTextField *)view setTextColor:[NSColor controlTextColor]];
            }
        }

    }
}

- (NSArray<NSLayoutConstraint *> *)applyConstraintsToFillSuperview
{
    NSAssert(self.superview, @"View must have a valid superview when applying fill constraints!");
    return [self.superview constraintsToFillView:self activate:YES];
}

- (NSArray<NSLayoutConstraint *> *)constraintsToFillView:(NSView *)view activate:(BOOL)activate
{
    NSArray<NSLayoutConstraint *> * const constraints = @[
        [self.leadingAnchor constraintEqualToAnchor:view.leadingAnchor],
        [self.trailingAnchor constraintEqualToAnchor:view.trailingAnchor],
        [self.topAnchor constraintEqualToAnchor:view.topAnchor],
        [self.bottomAnchor constraintEqualToAnchor:view.bottomAnchor]
    ];
    if (activate) {
        [NSLayoutConstraint activateConstraints:constraints];
    }
    return constraints;
}

- (NSView *)VLCInstallVividockGlassBackdropWithMaterial:(NSVisualEffectMaterial)material
                                           blendingMode:(NSVisualEffectBlendingMode)blendingMode
{
#if __MAC_OS_X_VERSION_MAX_ALLOWED >= 260000
    if (@available(macOS 26.0, *)) {
        for (NSView * const subview in self.subviews) {
            if ([subview.identifier isEqualToString:VLCVividockGoldenGateGlassIdentifier]) {
#if __MAC_OS_X_VERSION_MAX_ALLOWED >= 260000
                if ([subview isKindOfClass:NSGlassEffectView.class]) {
                    NSGlassEffectView * const glass = (NSGlassEffectView *)subview;
                    glass.tintColor = nil;
                    return glass;
                }
#endif
            }
        }

        const BOOL hudLike = material == NSVisualEffectMaterialHUDWindow;
        const BOOL sidebarLike = material == NSVisualEffectMaterialSidebar;
        const BOOL magnifyingGlass = hudLike || sidebarLike ||
            blendingMode == NSVisualEffectBlendingModeBehindWindow;
        NSGlassEffectView * const glass = [[NSGlassEffectView alloc] initWithFrame:self.bounds];
        glass.identifier = VLCVividockGoldenGateGlassIdentifier;
        glass.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
        glass.style = magnifyingGlass ? NSGlassEffectViewStyleClear : NSGlassEffectViewStyleRegular;
        glass.cornerRadius = hudLike ? 22. : 0.;
        glass.tintColor = nil;
        if (@available(macOS 27.0, *)) {
            glass.effectIsInteractive = hudLike || sidebarLike;
        }
        [self addSubview:glass positioned:NSWindowBelow relativeTo:nil];
        return glass;
    }
#endif

    for (NSView * const subview in self.subviews) {
        if ([subview.identifier isEqualToString:VLCVividockGlassBackdropIdentifier] &&
            [subview isKindOfClass:NSVisualEffectView.class]) {
            NSVisualEffectView * const backdrop = (NSVisualEffectView *)subview;
            backdrop.material = material;
            backdrop.blendingMode = blendingMode;
            backdrop.state = NSVisualEffectStateActive;
            return backdrop;
        }
    }

    NSVisualEffectView * const backdrop = [[NSVisualEffectView alloc] initWithFrame:self.bounds];
    backdrop.identifier = VLCVividockGlassBackdropIdentifier;
    backdrop.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
    backdrop.blendingMode = blendingMode;
    backdrop.material = material;
    backdrop.state = NSVisualEffectStateActive;
    backdrop.wantsLayer = YES;
    [self addSubview:backdrop positioned:NSWindowBelow relativeTo:nil];
    return backdrop;
}

- (void)VLCApplyVividockGlassAccentRimWithCornerRadius:(CGFloat)radius
{
    self.wantsLayer = YES;
    self.layer.cornerRadius = radius;
    self.layer.masksToBounds = YES;
    self.layer.borderWidth = 1.;
    self.layer.borderColor = [NSColor colorWithWhite:1. alpha:0.18].CGColor;
}

- (void)VLCUpdateVividockGlassAccentRim
{
    if (self.layer == nil || self.layer.borderWidth <= 0.) {
        return;
    }
    self.layer.borderColor = [NSColor colorWithWhite:1. alpha:0.18].CGColor;
}

- (void)VLCUpdateVividockGoldenGateGlassTint
{
#if __MAC_OS_X_VERSION_MAX_ALLOWED >= 260000
    if (@available(macOS 26.0, *)) {
        for (NSView * const subview in self.subviews) {
            if ([subview.identifier isEqualToString:VLCVividockGoldenGateGlassIdentifier] &&
                [subview isKindOfClass:NSGlassEffectView.class]) {
                ((NSGlassEffectView *)subview).tintColor = nil;
            }
            [subview VLCUpdateVividockGoldenGateGlassTint];
        }
    }
#endif
}

@end
