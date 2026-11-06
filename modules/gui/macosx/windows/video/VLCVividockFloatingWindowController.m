/*****************************************************************************
 * VLCVividockFloatingWindowController.m: Vividock floating video controller
 *****************************************************************************
 * Copyright (C) 2026 VLC authors and VideoLAN
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

#import "VLCVividockFloatingWindowController.h"

#import <vlc_common.h>

#import "extensions/NSString+Helpers.h"
#import "extensions/NSColor+VLCAdditions.h"
#import "extensions/NSView+VLCAdditions.h"

#import "playqueue/VLCPlayerController.h"

@interface VLCVividockTrackingView : NSView

@property (nonatomic, copy) void (^mouseEnteredHandler)(void);
@property (nonatomic, copy) void (^mouseExitedHandler)(void);
@property (nonatomic, copy) void (^mouseMovedHandler)(void);

@end


@implementation VLCVividockTrackingView

- (void)updateTrackingAreas
{
    [super updateTrackingAreas];

    for (NSTrackingArea * const trackingArea in self.trackingAreas) {
        [self removeTrackingArea:trackingArea];
    }

    NSTrackingArea * const trackingArea = [[NSTrackingArea alloc]
        initWithRect:NSZeroRect
             options:NSTrackingMouseEnteredAndExited |
                     NSTrackingMouseMoved |
                     NSTrackingActiveAlways |
                     NSTrackingInVisibleRect
               owner:self
            userInfo:nil];
    [self addTrackingArea:trackingArea];
}

- (void)mouseEntered:(NSEvent *)event
{
    if (self.mouseEnteredHandler) {
        self.mouseEnteredHandler();
    }
}

- (void)mouseExited:(NSEvent *)event
{
    if (self.mouseExitedHandler) {
        self.mouseExitedHandler();
    }
}

- (void)mouseMoved:(NSEvent *)event
{
    if (self.mouseMovedHandler) {
        self.mouseMovedHandler();
    }
}

@end


@interface VLCVividockSeekSlider : NSSlider

@property (nonatomic, copy) void (^trackingBeganHandler)(void);
@property (nonatomic, copy) void (^trackingEndedHandler)(void);

@end


@implementation VLCVividockSeekSlider

- (void)mouseDown:(NSEvent *)event
{
    if (self.trackingBeganHandler) {
        self.trackingBeganHandler();
    }

    [super mouseDown:event];

    if (self.trackingEndedHandler) {
        self.trackingEndedHandler();
    }
}

@end


@interface VLCVividockSeekSliderCell : NSSliderCell
@end

@implementation VLCVividockSeekSliderCell

- (void)drawBarInside:(NSRect)rect flipped:(BOOL)flipped
{
    const BOOL enabled = [(NSControl *)self.controlView isEnabled];
    const CGFloat trackHeight = 4.;
    NSRect trackRect = NSMakeRect(NSMinX(rect), NSMidY(rect) - trackHeight / 2., NSWidth(rect), trackHeight);
    NSBezierPath * const background = [NSBezierPath bezierPathWithRoundedRect:trackRect
                                                                      xRadius:trackHeight / 2.
                                                                      yRadius:trackHeight / 2.];
    [[NSColor colorWithWhite:1. alpha:enabled ? .24 : .12] setFill];
    [background fill];

    const double span = self.maxValue - self.minValue;
    const double fraction = span > 0. ? (self.doubleValue - self.minValue) / span : 0.;
    trackRect.size.width *= MIN(MAX(fraction, 0.), 1.);
    if (trackRect.size.width > 0.) {
        NSBezierPath * const progress = [NSBezierPath bezierPathWithRoundedRect:trackRect
                                                                        xRadius:trackHeight / 2.
                                                                        yRadius:trackHeight / 2.];
        [[NSColor.VLCVividockAccentColor colorWithAlphaComponent:enabled ? .9 : .35] setFill];
        [progress fill];
    }
}

- (void)drawKnob:(NSRect)knobRect
{
    const BOOL enabled = [(NSControl *)self.controlView isEnabled];
    NSRect insetRect = NSInsetRect(knobRect, 2., 2.);
    NSBezierPath * const knob = [NSBezierPath bezierPathWithOvalInRect:insetRect];
    [[NSColor.VLCVividockAccentColor colorWithAlphaComponent:enabled ? 1. : .4] setFill];
    [knob fill];
    [[NSColor colorWithWhite:1. alpha:.65] setStroke];
    knob.lineWidth = 1.;
    [knob stroke];
}

@end


@interface VLCVividockFloatingWindowController () <NSWindowDelegate>
{
    VLCPlayerController *_playerController;
    NSView *_videoView;
    NSButton *_backwardButton;
    NSButton *_playPauseButton;
    NSButton *_forwardButton;
    NSSlider *_seekSlider;
    NSTextField *_elapsedTimeField;
    NSTextField *_durationField;
    NSView *_centerControlsView;
    NSView *_timelineControlsView;
    NSVisualEffectView *_returnControlsView;
    NSButton *_returnButton;
    NSArray<NSVisualEffectView *> *_glassButtonViews;
    NSVisualEffectView *_playPauseButtonView;
    NSTimer *_hideControlsTimer;
    BOOL _seekSliderIsBeingDragged;
    BOOL _closeHandlerCalled;
}
@end

@implementation VLCVividockFloatingWindowController

- (instancetype)initWithVideoView:(NSView *)videoView
                  playerController:(VLCPlayerController *)playerController
                             title:(NSString *)title
{
    NSPanel * const panel = [[NSPanel alloc]
        initWithContentRect:NSMakeRect(0., 0., 420., 236.)
                  styleMask:NSWindowStyleMaskTitled |
                            NSWindowStyleMaskClosable |
                            NSWindowStyleMaskResizable |
                            NSWindowStyleMaskNonactivatingPanel |
                            NSWindowStyleMaskFullSizeContentView
                    backing:NSBackingStoreBuffered
                      defer:NO];

    self = [super initWithWindow:panel];
    if (self) {
        _playerController = playerController;
        _videoView = videoView;

        panel.delegate = self;
        panel.title = title ?: @"VLC";
        panel.titleVisibility = NSWindowTitleHidden;
        panel.titlebarAppearsTransparent = YES;
        panel.movableByWindowBackground = YES;
        panel.acceptsMouseMovedEvents = YES;
        panel.floatingPanel = YES;
        panel.becomesKeyOnlyIfNeeded = YES;
        panel.hidesOnDeactivate = NO;
        panel.level = NSFloatingWindowLevel;
        NSWindowCollectionBehavior collectionBehavior =
            NSWindowCollectionBehaviorCanJoinAllSpaces |
            NSWindowCollectionBehaviorFullScreenAuxiliary;
        if (@available(macOS 13.0, *)) {
            collectionBehavior |= NSWindowCollectionBehaviorCanJoinAllApplications;
        }
        panel.collectionBehavior = collectionBehavior;
        panel.contentMinSize = NSMakeSize(320., 180.);

        [panel standardWindowButton:NSWindowMiniaturizeButton].hidden = YES;
        [panel standardWindowButton:NSWindowZoomButton].hidden = YES;

        [self setupContentView];
        [self registerPlayerNotifications];
        [self updateControls:nil];
        [panel center];
    }
    return self;
}

- (void)dealloc
{
    [_hideControlsTimer invalidate];
    [NSNotificationCenter.defaultCenter removeObserver:self];
}

- (void)setupContentView
{
    VLCVividockTrackingView * const contentView = [[VLCVividockTrackingView alloc] initWithFrame:NSZeroRect];
    contentView.wantsLayer = YES;
    contentView.layer.backgroundColor = NSColor.blackColor.CGColor;
    self.window.contentView = contentView;

    __weak typeof(self) weakSelf = self;
    contentView.mouseEnteredHandler = ^{
        [weakSelf showControlsTemporarily];
    };
    contentView.mouseExitedHandler = ^{
        [weakSelf scheduleControlsHide];
    };
    contentView.mouseMovedHandler = ^{
        [weakSelf showControlsTemporarily];
    };

    _videoView.translatesAutoresizingMaskIntoConstraints = NO;
    [contentView addSubview:_videoView];
    [_videoView applyConstraintsToFillSuperview];

    _centerControlsView = [[NSView alloc] initWithFrame:NSZeroRect];
    _centerControlsView.translatesAutoresizingMaskIntoConstraints = NO;
    [contentView addSubview:_centerControlsView];

    _timelineControlsView = [self overlayView];
    [contentView addSubview:_timelineControlsView];

    _returnButton = [self transportButtonWithFallbackTitle:@"↗"
                                                symbolName:@"pip.exit"
                                                   toolTip:_NS("Return to main window")
                                                    action:@selector(returnToMainWindow:)];
    _returnControlsView = [self glassButtonViewContainingButton:_returnButton diameter:34.];
    [contentView addSubview:_returnControlsView];

    _backwardButton = [self transportButtonWithFallbackTitle:@"↶⑤"
                                                  symbolName:@"gobackward.5"
                                                     toolTip:_NS("Back 5 seconds")
                                                      action:@selector(backward:)];
    _playPauseButton = [self transportButtonWithFallbackTitle:@"▶"
                                                   symbolName:@"play.fill"
                                                      toolTip:_NS("Play")
                                                       action:@selector(togglePlayPause:)];
    _forwardButton = [self transportButtonWithFallbackTitle:@"⑤↷"
                                                 symbolName:@"goforward.5"
                                                    toolTip:_NS("Forward 5 seconds")
                                                     action:@selector(forward:)];

    NSVisualEffectView * const backwardButtonView =
        [self glassButtonViewContainingButton:_backwardButton diameter:48.];
    _playPauseButtonView =
        [self glassButtonViewContainingButton:_playPauseButton diameter:54.];
    NSVisualEffectView * const forwardButtonView =
        [self glassButtonViewContainingButton:_forwardButton diameter:48.];

    NSStackView * const buttonStack = [NSStackView stackViewWithViews:@[
        backwardButtonView,
        _playPauseButtonView,
        forwardButtonView,
    ]];
    _glassButtonViews = @[backwardButtonView, _playPauseButtonView, forwardButtonView, _returnControlsView];
    buttonStack.translatesAutoresizingMaskIntoConstraints = NO;
    buttonStack.orientation = NSUserInterfaceLayoutOrientationHorizontal;
    buttonStack.alignment = NSLayoutAttributeCenterY;
    buttonStack.spacing = 14.;
    [_centerControlsView addSubview:buttonStack];

    _elapsedTimeField = [self timeField];
    _elapsedTimeField.alignment = NSTextAlignmentRight;

    _seekSlider = [[VLCVividockSeekSlider alloc] initWithFrame:NSZeroRect];
    _seekSlider.cell = [[VLCVividockSeekSliderCell alloc] init];
    _seekSlider.minValue = 0.;
    _seekSlider.maxValue = 1.;
    _seekSlider.target = self;
    _seekSlider.action = @selector(seek:);
    _seekSlider.translatesAutoresizingMaskIntoConstraints = NO;
    _seekSlider.continuous = YES;
    _seekSlider.controlSize = NSControlSizeSmall;
    _seekSlider.accessibilityLabel = _NS("Playback position");

    VLCVividockSeekSlider * const seekSlider = (VLCVividockSeekSlider *)_seekSlider;
    seekSlider.trackingBeganHandler = ^{
        typeof(self) strongSelf = weakSelf;
        if (strongSelf == nil) {
            return;
        }
        strongSelf->_seekSliderIsBeingDragged = YES;
        [strongSelf showControlsTemporarily];
    };
    seekSlider.trackingEndedHandler = ^{
        typeof(self) strongSelf = weakSelf;
        if (strongSelf == nil) {
            return;
        }
        if (strongSelf->_playerController.seekable) {
            [strongSelf->_playerController setPositionPrecise:strongSelf->_seekSlider.floatValue];
        }
        strongSelf->_seekSliderIsBeingDragged = NO;
        [strongSelf showControlsTemporarily];
    };

    _durationField = [self timeField];
    _durationField.alignment = NSTextAlignmentLeft;

    NSStackView * const seekStack = [NSStackView stackViewWithViews:@[
        _elapsedTimeField,
        _seekSlider,
        _durationField,
    ]];
    seekStack.translatesAutoresizingMaskIntoConstraints = NO;
    seekStack.orientation = NSUserInterfaceLayoutOrientationHorizontal;
    seekStack.alignment = NSLayoutAttributeCenterY;
    seekStack.spacing = 8.;
    [_timelineControlsView addSubview:seekStack];

    [NSLayoutConstraint activateConstraints:@[
        [_centerControlsView.centerXAnchor constraintEqualToAnchor:contentView.centerXAnchor],
        [_centerControlsView.centerYAnchor constraintEqualToAnchor:contentView.centerYAnchor],
        [buttonStack.leadingAnchor constraintEqualToAnchor:_centerControlsView.leadingAnchor],
        [buttonStack.trailingAnchor constraintEqualToAnchor:_centerControlsView.trailingAnchor],
        [buttonStack.topAnchor constraintEqualToAnchor:_centerControlsView.topAnchor],
        [buttonStack.bottomAnchor constraintEqualToAnchor:_centerControlsView.bottomAnchor],

        [_timelineControlsView.leadingAnchor constraintEqualToAnchor:contentView.leadingAnchor constant:12.],
        [_timelineControlsView.trailingAnchor constraintEqualToAnchor:contentView.trailingAnchor constant:-12.],
        [_timelineControlsView.bottomAnchor constraintEqualToAnchor:contentView.bottomAnchor constant:-10.],
        [seekStack.leadingAnchor constraintEqualToAnchor:_timelineControlsView.leadingAnchor constant:12.],
        [seekStack.trailingAnchor constraintEqualToAnchor:_timelineControlsView.trailingAnchor constant:-12.],
        [seekStack.topAnchor constraintEqualToAnchor:_timelineControlsView.topAnchor constant:5.],
        [seekStack.bottomAnchor constraintEqualToAnchor:_timelineControlsView.bottomAnchor constant:-5.],

        [_returnControlsView.topAnchor constraintEqualToAnchor:contentView.topAnchor constant:8.],
        [_returnControlsView.trailingAnchor constraintEqualToAnchor:contentView.trailingAnchor constant:-10.],

        [_elapsedTimeField.widthAnchor constraintEqualToConstant:52.],
        [_durationField.widthAnchor constraintEqualToConstant:52.],
        [_seekSlider.widthAnchor constraintGreaterThanOrEqualToConstant:120.],
    ]];

    [self updateAccentStyling:nil];
}

- (NSVisualEffectView *)overlayView
{
    NSVisualEffectView * const overlayView = [[NSVisualEffectView alloc] initWithFrame:NSZeroRect];
    overlayView.translatesAutoresizingMaskIntoConstraints = NO;
    overlayView.material = NSVisualEffectMaterialHUDWindow;
    overlayView.blendingMode = NSVisualEffectBlendingModeWithinWindow;
    overlayView.state = NSVisualEffectStateActive;
    overlayView.appearance = [NSAppearance appearanceNamed:NSAppearanceNameVibrantDark];
    overlayView.wantsLayer = YES;
    overlayView.layer.cornerRadius = 14.;
    overlayView.layer.masksToBounds = YES;
    overlayView.layer.borderWidth = 0.6;
    overlayView.layer.borderColor = [NSColor colorWithWhite:1. alpha:0.22].CGColor;
    return overlayView;
}

- (NSVisualEffectView *)glassButtonViewContainingButton:(NSButton *)button
                                                diameter:(CGFloat)diameter
{
    NSVisualEffectView * const buttonView = [self overlayView];
    buttonView.layer.cornerRadius = diameter / 2.;
    [buttonView addSubview:button];

    [NSLayoutConstraint activateConstraints:@[
        [buttonView.widthAnchor constraintEqualToConstant:diameter],
        [buttonView.heightAnchor constraintEqualToConstant:diameter],
        [button.leadingAnchor constraintEqualToAnchor:buttonView.leadingAnchor],
        [button.trailingAnchor constraintEqualToAnchor:buttonView.trailingAnchor],
        [button.topAnchor constraintEqualToAnchor:buttonView.topAnchor],
        [button.bottomAnchor constraintEqualToAnchor:buttonView.bottomAnchor],
    ]];
    return buttonView;
}

- (NSButton *)transportButtonWithFallbackTitle:(NSString *)fallbackTitle
                                    symbolName:(NSString *)symbolName
                                       toolTip:(NSString *)toolTip
                                        action:(SEL)action
{
    NSButton * const button = [NSButton buttonWithTitle:fallbackTitle
                                                 target:self
                                                 action:action];
    button.translatesAutoresizingMaskIntoConstraints = NO;
    button.bordered = NO;
    button.font = [NSFont systemFontOfSize:13. weight:NSFontWeightSemibold];
    button.toolTip = toolTip;
    button.accessibilityLabel = toolTip;

    if (@available(macOS 10.14, *)) {
        button.contentTintColor = NSColor.whiteColor;
    }
    if (@available(macOS 11.0, *)) {
        NSImage * const image = [NSImage imageWithSystemSymbolName:symbolName
                                          accessibilityDescription:toolTip];
        if (image != nil) {
            button.image = [image imageWithSymbolConfiguration:
                [NSImageSymbolConfiguration configurationWithPointSize:18.
                                                                 weight:NSFontWeightMedium]];
            button.imagePosition = NSImageOnly;
            button.title = @"";
        }
    }
    return button;
}

- (NSTextField *)timeField
{
    NSTextField * const field = [NSTextField labelWithString:@"--:--"];
    field.translatesAutoresizingMaskIntoConstraints = NO;
    field.textColor = NSColor.whiteColor;
    field.font = [NSFont monospacedDigitSystemFontOfSize:NSFont.smallSystemFontSize
                                                  weight:NSFontWeightMedium];
    return field;
}

- (void)registerPlayerNotifications
{
    NSNotificationCenter * const notificationCenter = NSNotificationCenter.defaultCenter;
    NSArray<NSString *> * const notificationNames = @[
        VLCPlayerTimeAndPositionChanged,
        VLCPlayerLengthChanged,
        VLCPlayerCapabilitiesChanged,
        VLCPlayerStateChanged,
        VLCPlayerCurrentMediaItemChanged,
    ];

    for (NSString * const name in notificationNames) {
        [notificationCenter addObserver:self
                               selector:@selector(updateControls:)
                                   name:name
                                 object:_playerController];
    }
    [notificationCenter addObserver:self
                           selector:@selector(updateAccentStyling:)
                               name:VLCVividockAccentDidChangeNotification
                             object:nil];
    [notificationCenter addObserver:self
                           selector:@selector(updateAccentStyling:)
                               name:NSWorkspaceAccessibilityDisplayOptionsDidChangeNotification
                             object:nil];
}

- (void)updateAccentStyling:(NSNotification *)notification
{
    NSColor * const accent = NSColor.VLCVividockAccentColor;
    const BOOL reduceTransparency = NSWorkspace.sharedWorkspace.accessibilityDisplayShouldReduceTransparency;

    for (NSVisualEffectView * const buttonView in _glassButtonViews) {
        buttonView.layer.borderColor = [NSColor colorWithWhite:1. alpha:reduceTransparency ? .45 : .22].CGColor;
        buttonView.layer.borderWidth = reduceTransparency ? 1.5 : 0.6;
    }
    _playPauseButtonView.layer.borderColor = [NSColor colorWithWhite:1. alpha:reduceTransparency ? .55 : .28].CGColor;

    if (@available(macOS 10.14, *)) {
        _backwardButton.contentTintColor = accent;
        _forwardButton.contentTintColor = accent;
        _playPauseButton.contentTintColor = accent;
    }
    _timelineControlsView.layer.borderColor = [NSColor colorWithWhite:1. alpha:reduceTransparency ? .4 : .18].CGColor;
    _timelineControlsView.layer.borderWidth = reduceTransparency ? 1. : 0.6;
    _seekSlider.needsDisplay = YES;
}

- (void)showWindow:(id)sender
{
    [self.window orderFrontRegardless];
    [self showControlsTemporarily];
}

- (void)showControlsTemporarily
{
    [_hideControlsTimer invalidate];
    _centerControlsView.hidden = NO;
    _timelineControlsView.hidden = NO;
    _returnControlsView.hidden = NO;

    [NSAnimationContext runAnimationGroup:^(NSAnimationContext * const context) {
        context.duration = .15;
        self->_centerControlsView.animator.alphaValue = 1.;
        self->_timelineControlsView.animator.alphaValue = 1.;
        self->_returnControlsView.animator.alphaValue = 1.;
    } completionHandler:nil];

    [self scheduleControlsHide];
}

- (void)scheduleControlsHide
{
    [_hideControlsTimer invalidate];
    _hideControlsTimer = [NSTimer scheduledTimerWithTimeInterval:2.5
                                                          target:self
                                                        selector:@selector(hideControls:)
                                                        userInfo:nil
                                                         repeats:NO];
}

- (void)hideControls:(NSTimer *)timer
{
    if (_seekSliderIsBeingDragged) {
        [self scheduleControlsHide];
        return;
    }

    [NSAnimationContext runAnimationGroup:^(NSAnimationContext * const context) {
        context.duration = .25;
        self->_centerControlsView.animator.alphaValue = 0.;
        self->_timelineControlsView.animator.alphaValue = 0.;
        self->_returnControlsView.animator.alphaValue = 0.;
    } completionHandler:^{
        self->_centerControlsView.hidden = YES;
        self->_timelineControlsView.hidden = YES;
        self->_returnControlsView.hidden = YES;
    }];
}

- (void)returnToMainWindow:(id)sender
{
    [self.window performClose:sender];
}

- (void)backward:(id)sender
{
    [self showControlsTemporarily];
    [self seekBySeconds:-5];
}

- (void)forward:(id)sender
{
    [self showControlsTemporarily];
    [self seekBySeconds:5];
}

- (void)seekBySeconds:(NSInteger)seconds
{
    if (!_playerController.seekable) {
        return;
    }

    const vlc_tick_t currentTime = _playerController.time;
    if (currentTime == VLC_TICK_INVALID) {
        return;
    }

    const vlc_tick_t duration = _playerController.durationOfCurrentMediaItem;
    const vlc_tick_t interval = VLC_TICK_FROM_SEC(5);
    vlc_tick_t targetTime;
    if (seconds < 0) {
        targetTime = currentTime > interval ? currentTime - interval : 0;
    } else if (duration > 0) {
        targetTime = currentTime < duration - interval ? currentTime + interval : duration;
    } else {
        targetTime = currentTime + interval;
    }
    [_playerController setTimePrecise:targetTime];
}

- (void)togglePlayPause:(id)sender
{
    [self showControlsTemporarily];
    if (_playerController.playerState == VLC_PLAYER_STATE_PLAYING) {
        [_playerController pause];
    } else if (_playerController.playerState == VLC_PLAYER_STATE_PAUSED) {
        [_playerController resume];
    } else {
        [_playerController start];
    }
}

- (void)seek:(NSSlider *)sender
{
    [self showControlsTemporarily];
    if (!_playerController.seekable) {
        return;
    }

    if (_seekSliderIsBeingDragged) {
        [_playerController setPositionFast:sender.floatValue];
    } else {
        [_playerController setPositionPrecise:sender.floatValue];
    }
}

- (void)updateControls:(NSNotification *)notification
{
    const vlc_tick_t duration = _playerController.durationOfCurrentMediaItem;
    const vlc_tick_t currentTime = _playerController.time;
    const BOOL validTimeline = duration > 0 && currentTime != VLC_TICK_INVALID;
    const BOOL seekEnabled = validTimeline && _playerController.seekable;

    _backwardButton.enabled = seekEnabled;
    _forwardButton.enabled = seekEnabled;
    _seekSlider.enabled = seekEnabled;

    if (!_seekSliderIsBeingDragged) {
        const double position = _playerController.position;
        _seekSlider.doubleValue = position >= 0. ? MIN(MAX(position, 0.), 1.) : 0.;
    }

    _elapsedTimeField.stringValue = currentTime != VLC_TICK_INVALID
        ? [NSString stringWithTimeFromTicks:MAX(currentTime, 0)]
        : @"--:--";
    _durationField.stringValue = duration > 0
        ? [NSString stringWithTimeFromTicks:duration]
        : @"--:--";

    const BOOL playing = _playerController.playerState == VLC_PLAYER_STATE_PLAYING;
    NSString * const playPauseTitle = playing ? _NS("Pause") : _NS("Play");
    _playPauseButton.toolTip = playPauseTitle;
    if (@available(macOS 11.0, *)) {
        NSString * const symbolName = playing ? @"pause.fill" : @"play.fill";
        NSImage * const image = [NSImage imageWithSystemSymbolName:symbolName
                                          accessibilityDescription:playPauseTitle];
        if (image != nil) {
            _playPauseButton.image = [image imageWithSymbolConfiguration:
                [NSImageSymbolConfiguration configurationWithPointSize:18.
                                                                 weight:NSFontWeightMedium]];
            _playPauseButton.imagePosition = NSImageOnly;
            _playPauseButton.title = @"";
        } else {
            _playPauseButton.image = nil;
            _playPauseButton.title = playing ? @"‖" : @"▶";
        }
    } else {
        _playPauseButton.title = playing ? @"‖" : @"▶";
    }
    _playPauseButton.enabled = _playerController.currentMedia != nil;
}

- (void)windowWillClose:(NSNotification *)notification
{
    [_hideControlsTimer invalidate];
    if (_closeHandlerCalled) {
        return;
    }
    _closeHandlerCalled = YES;
    if (self.closeHandler) {
        self.closeHandler(_videoView);
    }
}

@end
