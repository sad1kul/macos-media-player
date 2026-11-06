/*****************************************************************************
 * VLCLibraryWindowNavigationSidebarViewController.h: MacOS X interface module
 *****************************************************************************
 * Copyright (C) 2023 VLC authors and VideoLAN
 *
 * Authors: Claudio Cambra <developer@claudiocambra.com>
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

#import "VLCLibraryWindowNavigationSidebarViewController.h"

#import "extensions/NSAnimationContext+VLCAdditions.h"
#import "extensions/NSColor+VLCAdditions.h"
#import "extensions/NSView+VLCAdditions.h"
#import "extensions/NSWindow+VLCAdditions.h"

#import "library/VLCLibraryController.h"
#import "library/VLCLibraryDataTypes.h"
#import "library/VLCLibraryModel.h"
#import "library/VLCLibrarySegment.h"
#import "library/VLCLibrarySegmentBookmarkedLocation.h"
#import "library/VLCLibraryWindow.h"
#import "library/VLCLibraryWindowNavigationSidebarOutlineView.h"

#import "main/VLCMain.h"

#import "views/VLCStatusNotifierView.h"
#import "views/VLCUIUnits.h"

#include <sys/types.h>
#include <sys/stat.h>
#include <fcntl.h>
#include <unistd.h>

// This needs to match whatever identifier has been set in the library window XIB
static NSString * const VLCLibrarySegmentCellIdentifier = @"VLCLibrarySegmentCellIdentifier";

/* AppKit source-list selection uses the system accent (orange here). Paint a
 * frosted glass capsule instead so the row stays readable and navigable. */
static NSString * const VLCVividockSidebarRowViewIdentifier = @"VLCVividockSidebarRowView";
static NSString * const VLCVividockSelectionGlassIdentifier = @"VLCVividockSelectionGlass";

static NSRect VLCVividockSidebarSelectionRect(NSRect bounds)
{
    /* Match AppKit source-list highlight: ~10pt side inset, ~2pt vertical. */
    return NSInsetRect(bounds, 10., 2.);
}

@interface VLCVividockSidebarRowView : NSTableRowView
@property (nonatomic) NSView *selectionGlassView;
@end

@implementation VLCVividockSidebarRowView

- (NSBackgroundStyle)interiorBackgroundStyle
{
    return NSBackgroundStyleNormal;
}

- (void)drawBackgroundInRect:(NSRect)dirtyRect
{
}

- (void)hideSystemSelectionChrome
{
    for (NSView * const subview in self.subviews) {
        if ([subview isKindOfClass:NSTableCellView.class] ||
            [subview.identifier isEqualToString:VLCVividockSelectionGlassIdentifier]) {
            continue;
        }
        NSString * const className = NSStringFromClass(subview.class);
        if ([className containsString:@"Glass"] ||
            [className containsString:@"Selection"] ||
            [className containsString:@"Highlight"] ||
            [className containsString:@"Emphasiz"]) {
            subview.hidden = YES;
            subview.alphaValue = 0.;
        }
    }
}

- (void)updateSelectionGlass
{
    const NSRect pill = VLCVividockSidebarSelectionRect(self.bounds);

#if __MAC_OS_X_VERSION_MAX_ALLOWED >= 260000
    if (@available(macOS 26.0, *)) {
        if (self.selectionGlassView == nil) {
            NSGlassEffectView * const glass = [[NSGlassEffectView alloc] initWithFrame:pill];
            glass.identifier = VLCVividockSelectionGlassIdentifier;
            glass.style = NSGlassEffectViewStyleClear;
            glass.cornerRadius = 8.;
            glass.tintColor = nil;
            if (@available(macOS 27.0, *)) {
                glass.effectIsInteractive = YES;
            }
            [self addSubview:glass positioned:NSWindowBelow relativeTo:nil];
            self.selectionGlassView = glass;
        }
        self.selectionGlassView.frame = pill;
        self.selectionGlassView.hidden = !self.selected;
        return;
    }
#endif

    self.selectionGlassView.hidden = YES;
}

- (void)drawSelectionInRect:(NSRect)dirtyRect
{
#if __MAC_OS_X_VERSION_MAX_ALLOWED >= 260000
    if (@available(macOS 26.0, *)) {
        return;
    }
#endif
    if (!self.selected) {
        return;
    }

    const NSRect pill = VLCVividockSidebarSelectionRect(self.bounds);
    NSBezierPath * const path = [NSBezierPath bezierPathWithRoundedRect:pill
                                                                 xRadius:8.
                                                                 yRadius:8.];
    [[NSColor.whiteColor colorWithAlphaComponent:0.12] setFill];
    [path fill];
}

- (void)setSelected:(BOOL)selected
{
    [super setSelected:selected];
    [self hideSystemSelectionChrome];
    [self updateSelectionGlass];
    [self setNeedsDisplay:YES];
}

- (void)didAddSubview:(NSView *)subview
{
    [super didAddSubview:subview];
    [self hideSystemSelectionChrome];
}

- (void)layout
{
    [super layout];
    [self hideSystemSelectionChrome];
    [self updateSelectionGlass];
}

@end

@interface VLCLibraryWindowNavigationSidebarViewController ()

@property BOOL ignoreSegmentSelectionChanges;
@property (readonly) NSEdgeInsets scrollViewInsets;
@property (readonly) NSMutableDictionary<NSString *, dispatch_source_t> *observedPathDispatchSources;

- (void)updateSidebarSelectionAppearance;

@end

@implementation VLCLibraryWindowNavigationSidebarViewController

- (instancetype)initWithLibraryWindow:(VLCLibraryWindow *)libraryWindow
{
    self = [super initWithNibName:@"VLCLibraryWindowNavigationSidebarView" bundle:nil];
    if (self) {
        _libraryWindow = libraryWindow;
        _segments = VLCLibrarySegment.librarySegments;
        _ignoreSegmentSelectionChanges = NO;
        _observedPathDispatchSources = NSMutableDictionary.dictionary;
    }
    return self;
}

- (void)viewDidLoad
{
    _treeController = [[NSTreeController alloc] init];
    self.treeController.objectClass = VLCLibrarySegment.class;
    self.treeController.countKeyPath = @"childCount";
    self.treeController.childrenKeyPath = @"childNodes";
    self.treeController.leafKeyPath = @"leaf";

    self.outlineView.rowSizeStyle = NSTableViewRowSizeStyleMedium;
    self.outlineView.allowsMultipleSelection = NO;
    self.outlineView.allowsEmptySelection = NO;
    self.outlineView.allowsColumnSelection = NO;
    self.outlineView.allowsColumnReordering = NO;
    self.outlineView.selectionHighlightStyle = NSTableViewSelectionHighlightStyleNone;
    self.outlineView.backgroundColor = NSColor.clearColor;
    self.outlineViewScrollView.drawsBackground = NO;
    self.view.wantsLayer = YES;
    [self.view VLCInstallVividockGlassBackdropWithMaterial:NSVisualEffectMaterialSidebar
                                              blendingMode:NSVisualEffectBlendingModeBehindWindow];

    [self internalNodesChanged:nil];

    const NSEdgeInsets scrollViewInsets = self.outlineViewScrollView.contentInsets;
    _scrollViewInsets =
        NSEdgeInsetsMake(scrollViewInsets.top + VLCUIUnits.libraryWindowContentSafeTopInset,
                         scrollViewInsets.left,
                         scrollViewInsets.bottom,
                         scrollViewInsets.right);

    self.statusNotifierView.postsFrameChangedNotifications = YES;

    NSNotificationCenter * const defaultCenter = NSNotificationCenter.defaultCenter;
    [defaultCenter addObserver:self
                      selector:@selector(internalNodesChanged:)
                          name:VLCLibraryBookmarkedLocationsChanged
                        object:nil];
    [defaultCenter addObserver:self
                      selector:@selector(internalNodesChanged:)
                          name:VLCLibraryModelListOfGroupsReset
                        object:nil];
    [defaultCenter addObserver:self
                      selector:@selector(internalNodesChanged:)
                          name:VLCLibraryModelGroupUpdated
                        object:nil];
    [defaultCenter addObserver:self
                      selector:@selector(internalNodesChanged:)
                          name:VLCLibraryModelGroupDeleted
                        object:nil];
    [defaultCenter addObserver:self
                      selector:@selector(statusViewActivated:)
                          name:VLCStatusNotifierViewActivated
                        object:nil];
    [defaultCenter addObserver:self
                      selector:@selector(statusViewDeactivated:)
                          name:VLCStatusNotifierViewDeactivated
                        object:nil];
    [defaultCenter addObserver:self
                      selector:@selector(statusViewSizeChanged:)
                          name:NSViewFrameDidChangeNotification
                        object:nil];
    [defaultCenter addObserver:self
                      selector:@selector(vividockAccentChanged:)
                          name:VLCVividockAccentDidChangeNotification
                        object:nil];
}

- (void)vividockAccentChanged:(NSNotification *)notification
{
    [self updateSidebarSelectionAppearance];
}

- (void)internalNodesChanged:(NSNotification *)notification
{
    const VLCLibrarySegmentType currentSegmentType = self.libraryWindow.librarySegmentType;

    NSMutableSet<NSNumber *> * const expandedSegmentTypes = NSMutableSet.set;
    for (VLCLibrarySegment * const segment in self.treeController.content) {
        NSTreeNode * const node = [self nodeForSegmentType:segment.segmentType];
        if ([self.outlineView isItemExpanded:node]) {
            [expandedSegmentTypes addObject:@(segment.segmentType)];
        }
    }

    self.ignoreSegmentSelectionChanges = YES;

    _segments = VLCLibrarySegment.librarySegments;
    [self.treeController bind:@"contentArray" toObject:self withKeyPath:@"segments" options:nil];
    [self.outlineView bind:@"content"
                  toObject:self.treeController
               withKeyPath:@"arrangedObjects"
                   options:nil];
    [self.outlineView reloadData];

    self.ignoreSegmentSelectionChanges = NO;

    [self updateBookmarkObservation];

    for (VLCLibrarySegment * const segment in self.treeController.content) {
        if ([expandedSegmentTypes containsObject:@(segment.segmentType)]) {
            NSTreeNode * const node = [self nodeForSegmentType:segment.segmentType];
            [self.outlineView expandItem:node];
        }
    }

    [self selectSegment:currentSegmentType];
}

- (void)updateBookmarkObservation
{
    NSUserDefaults * const defaults = NSUserDefaults.standardUserDefaults;
    NSArray<NSString *> * const bookmarkedLocations =
        [defaults stringArrayForKey:VLCLibraryBookmarkedLocationsKey];
    if (bookmarkedLocations.count == 0) {
        return;
    }

    NSMutableArray<NSString *> * const deletedLocations = self.observedPathDispatchSources.allKeys.mutableCopy;
    const __weak typeof(self) weakSelf = self;

    for (NSString * const locationMrl in bookmarkedLocations) {
        [deletedLocations removeObject:locationMrl];
        if ([self.observedPathDispatchSources objectForKey:locationMrl] != nil) {
            continue;
        }
        NSURL * const locationUrl = [NSURL URLWithString:locationMrl];
        const uintptr_t descriptor = open(locationUrl.path.UTF8String, O_EVTONLY);
        if (descriptor == (uintptr_t)-1) {
            continue;
        }
        struct stat fileStat;
        const int statResult = fstat(descriptor, &fileStat);

        const dispatch_queue_t globalQueue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
        const dispatch_source_t fileDispatchSource = dispatch_source_create(DISPATCH_SOURCE_TYPE_VNODE, descriptor, DISPATCH_VNODE_DELETE | DISPATCH_VNODE_RENAME, globalQueue);
        dispatch_source_set_event_handler(fileDispatchSource, ^{
            const unsigned long eventFlags = dispatch_source_get_data(fileDispatchSource);
            if (eventFlags & DISPATCH_VNODE_RENAME && statResult != -1) {
                NSURL * const parentLocationUrl = locationUrl.URLByDeletingLastPathComponent;
                NSString * const parentLocationPath = parentLocationUrl.path;
                NSArray<NSString *> * const files = [NSFileManager.defaultManager contentsOfDirectoryAtPath:parentLocationPath error:nil];
                NSString *newFileName = nil;

                for (NSString * const file in files) {
                    NSString * const fullChildPath = [parentLocationPath stringByAppendingPathComponent:file];
                    struct stat currentFileStat;
                    if (stat(fullChildPath.UTF8String, &currentFileStat) == -1) {
                        continue;
                    } else if (currentFileStat.st_ino == fileStat.st_ino) {
                        newFileName = fullChildPath.lastPathComponent;
                        break;
                    }
                }

                if (newFileName != nil) {
                    NSMutableArray<NSString *> * const mutableBookmarkedLocations = bookmarkedLocations.mutableCopy;
                    const NSUInteger locationIndex = [mutableBookmarkedLocations indexOfObject:locationMrl];
                    NSString * const newLocationMrl = [parentLocationUrl URLByAppendingPathComponent:newFileName].absoluteString;
                    [mutableBookmarkedLocations replaceObjectAtIndex:locationIndex withObject:newLocationMrl];
                    [defaults setObject:mutableBookmarkedLocations forKey:VLCLibraryBookmarkedLocationsKey];
                }
            }
            dispatch_async(dispatch_get_main_queue(), ^{
                [weakSelf internalNodesChanged:nil];
            });
        });
        dispatch_source_set_cancel_handler(fileDispatchSource, ^{
            close(descriptor);
        });
        dispatch_resume(fileDispatchSource);
        [self.observedPathDispatchSources setObject:fileDispatchSource forKey:locationMrl];
    }

    [self.observedPathDispatchSources removeObjectsForKeys:deletedLocations];
}

- (void)statusViewActivated:(NSNotification *)notification
{
    const CGFloat statusNotifierHeight = self.statusNotifierView.frame.size.height;
    self.outlineViewScrollView.contentInsets =
        NSEdgeInsetsMake(self.scrollViewInsets.top,
                         self.scrollViewInsets.left,
                         self.scrollViewInsets.bottom + statusNotifierHeight,
                         self.scrollViewInsets.right);
    self.statusNotifierView.hidden = NO;

    [NSAnimationContext runAnimationRespectingPreferencesWithChanges:^(NSAnimationContext * const __unused context) {
        self.statusNotifierView.animator.alphaValue = 1.0;
    } completionHandler:nil];
}

- (void)statusViewDeactivated:(NSNotification *)notification
{
    [NSAnimationContext runAnimationRespectingPreferencesWithChanges:^(NSAnimationContext * const __unused context) {
        self.statusNotifierView.animator.alphaValue = 0.0;
    } completionHandler:^{
        self.statusNotifierView.hidden = YES;
        self.outlineViewScrollView.contentInsets = self.scrollViewInsets;
    }];
}

- (void)statusViewSizeChanged:(NSNotification *)notification
{
    if (self.statusNotifierView.hidden) {
        return;
    }

    const CGFloat statusNotifierHeight = self.statusNotifierView.frame.size.height;
    self.outlineViewScrollView.contentInsets =
        NSEdgeInsetsMake(self.scrollViewInsets.top,
                         self.scrollViewInsets.left,
                         self.scrollViewInsets.bottom + statusNotifierHeight,
                         self.scrollViewInsets.right);
}

- (NSTreeNode *)nodeForSegmentType:(VLCLibrarySegmentType)segmentType
{
    NSArray<NSTreeNode *> *nodes = self.treeController.arrangedObjects.childNodes;
    while (nodes.count != 0) {
        NSMutableArray<NSTreeNode *> * const nextLevelNodes = NSMutableArray.array;

        const NSInteger nodeIdx = [nodes indexOfObjectPassingTest:^BOOL(NSTreeNode * const obj,
                                                                        const NSUInteger __unused idx,
                                                                        BOOL * const __unused stop) {
            VLCLibrarySegment * const segment = obj.representedObject;
            const BOOL matching = segment.segmentType == segmentType;
            if (!matching) {
                [nextLevelNodes addObjectsFromArray:obj.childNodes];
            }
            return matching;
        }];

        if (nodeIdx != NSNotFound) {
            return nodes[nodeIdx];
        }

        nodes = nextLevelNodes.copy;
    }
    return nil;
}

- (void)expandParentsOfNode:(NSTreeNode *)targetNode
{
    NSMutableArray * const parentNodes = NSMutableArray.array;
    NSTreeNode *currentNode = targetNode.parentNode;
    while (currentNode != nil) {
        [parentNodes insertObject:currentNode atIndex:0];
        currentNode = currentNode.parentNode;
    }

    for (NSTreeNode * const node in parentNodes) {
        [self.outlineView expandItem:node];
    }
}

- (void)selectSegment:(NSInteger)segmentType
{
    NSAssert(segmentType > VLCLibraryLowSentinelSegment &&
             segmentType < VLCLibraryHighSentinelSegment,
             @"Invalid segment type value provided");

    if (segmentType == VLCLibraryHeaderSegmentType) {
        return;
    }

    VLCLibrarySegment * const segment = [VLCLibrarySegment segmentWithSegmentType:segmentType];
    if (segment.mediaLibraryRequired &&
        VLCMain.sharedInstance.libraryController.libraryModel == nil) {
        segmentType = VLCLibraryBrowseSegmentType;
    }

    NSTreeNode *targetNode = [self nodeForSegmentType:segmentType];
    if (targetNode == nil) {
        // Fallback to Browse if the segment is not available
        segmentType = VLCLibraryBrowseSegmentType;
        targetNode = [self nodeForSegmentType:segmentType];
    }

    self.libraryWindow.librarySegmentType = segmentType;

    if (segmentType == VLCLibraryMusicSegmentType) {
        [self.outlineView expandItem:[self nodeForSegmentType:VLCLibraryMusicSegmentType]];
    }

    [self expandParentsOfNode:targetNode];
    const NSInteger segmentIndex = [self.outlineView rowForItem:targetNode];
    [self.outlineView selectRowIndexes:[NSIndexSet indexSetWithIndex:segmentIndex]
                  byExtendingSelection:NO];
}

# pragma mark - NSOutlineView delegation

- (NSView *)outlineView:(NSOutlineView *)outlineView
     viewForTableColumn:(NSTableColumn *)tableColumn
                   item:(id)item
{
    NSAssert(outlineView == _outlineView, @"VLCLibraryWindowNavigationSidebarController should only be a delegate for the libraryWindow nav sidebar outline view!");

    const BOOL isHeader = [self outlineView:outlineView isGroupItem:item];
    NSTableCellView * const cellView = isHeader
        ? [outlineView makeViewWithIdentifier:@"VLCLibrarySegmentHeaderCellIdentifier" owner:self]
        : [outlineView makeViewWithIdentifier:@"VLCLibrarySegmentCellIdentifier" owner:self];
    NSAssert(cellView != nil, @"Provided cell view for navigation outline view should be valid!");
    [cellView.textField bind:NSValueBinding toObject:cellView withKeyPath:@"objectValue.displayString" options:nil];
    [cellView.imageView bind:NSImageBinding toObject:cellView withKeyPath:@"objectValue.displayImage" options:nil];

    if (@available(macOS 10.14, *)) {
        const NSInteger row = [outlineView rowForItem:item];
        const BOOL selected = [outlineView.selectedRowIndexes containsIndex:row];
        cellView.imageView.contentTintColor = NSColor.VLCVividockAccentColor;
        cellView.textField.textColor = selected ? NSColor.VLCVividockAccentColor : NSColor.labelColor;
    }

    NSTreeNode * const treeNode = (NSTreeNode *)item;
    VLCLibrarySegment * const segment = (VLCLibrarySegment *)treeNode.representedObject;
    const BOOL mediaLibraryUnavailable =
        segment.mediaLibraryRequired &&
        VLCMain.sharedInstance.libraryController.libraryModel == nil;
    if (mediaLibraryUnavailable) {
        cellView.textField.textColor = NSColor.tertiaryLabelColor;
        if (@available(macOS 10.14, *)) {
            cellView.imageView.contentTintColor = NSColor.tertiaryLabelColor;
        }
    }

    return cellView;
}

- (NSIndexSet *)outlineView:(NSOutlineView *)outlineView selectionIndexesForProposedSelection:(nonnull NSIndexSet *)proposedSelectionIndexes
{
    NSAssert(outlineView == _outlineView, @"VLCLibraryWindowNavigationSidebarController should only be a delegate for the libraryWindow nav sidebar outline view!");

    if (proposedSelectionIndexes.count > 0) {
        NSTreeNode * const node = [self.outlineView itemAtRow:proposedSelectionIndexes.firstIndex];
        VLCLibrarySegment * const segment = (VLCLibrarySegment *)node.representedObject;

        if (segment.segmentType == VLCLibraryHeaderSegmentType) {
            return NSIndexSet.indexSet;
        }

        const BOOL mediaLibraryUnavailable =
            segment.mediaLibraryRequired &&
            VLCMain.sharedInstance.libraryController.libraryModel == nil;
        if (mediaLibraryUnavailable) {
            return [outlineView selectedRowIndexes];
        }
    }

    return proposedSelectionIndexes;
}

- (void)outlineViewSelectionDidChange:(NSNotification *)notification
{
    if (self.ignoreSegmentSelectionChanges) {
        return;
    }
    
    NSTreeNode * const node = (NSTreeNode *)[_outlineView itemAtRow:_outlineView.selectedRow];
    NSParameterAssert(node != nil);
    VLCLibrarySegment * const segment = (VLCLibrarySegment *)node.representedObject;
    NSObject * const representedObject = segment.representedObject;
    NSParameterAssert(representedObject != nil);

    if (segment.segmentType == VLCLibraryMusicSegmentType) {
        [self.outlineView expandItem:[self nodeForSegmentType:VLCLibraryMusicSegmentType]];
        NSTreeNode * const artistsNode = [self nodeForSegmentType:VLCLibraryArtistsMusicSubSegmentType];
        const NSInteger artistsIndex = [self.outlineView rowForItem:artistsNode];
        [self.outlineView selectRowIndexes:[NSIndexSet indexSetWithIndex:artistsIndex]
                      byExtendingSelection:NO];
        return;
    } else if ([representedObject isKindOfClass:NSNumber.class]) {
        self.libraryWindow.librarySegmentType = segment.segmentType;
    } else if ([representedObject isKindOfClass:VLCLibrarySegmentBookmarkedLocation.class]) {
        VLCLibrarySegmentBookmarkedLocation * const bookmarkedLocation =
            (VLCLibrarySegmentBookmarkedLocation *)representedObject;
        self.libraryWindow.librarySegmentType = bookmarkedLocation.segmentType;
        [self.libraryWindow browseFolderByMrl:bookmarkedLocation.mrl];
    } else if ([representedObject isKindOfClass:VLCMediaLibraryGroup.class]) {
        [self.libraryWindow presentLibraryItem:(VLCMediaLibraryGroup *)representedObject];
    }
    
    // Refresh disclosure triangles when selection changes
    [(VLCLibraryWindowNavigationSidebarOutlineView *)self.outlineView refreshDisclosureCaret];
    [self updateSidebarSelectionAppearance];
}

- (void)updateSidebarSelectionAppearance
{
    const NSInteger rowCount = self.outlineView.numberOfRows;
    for (NSInteger row = 0; row < rowCount; row++) {
        NSTableRowView * const rowView = [self.outlineView rowViewAtRow:row makeIfNecessary:NO];
        [rowView setNeedsDisplay:YES];

        NSTableCellView * const cellView = [self.outlineView viewAtColumn:0 row:row makeIfNecessary:NO];
        if (cellView == nil) {
            continue;
        }

        NSTreeNode * const treeNode = [self.outlineView itemAtRow:row];
        VLCLibrarySegment * const segment = (VLCLibrarySegment *)treeNode.representedObject;
        const BOOL mediaLibraryUnavailable =
            segment.mediaLibraryRequired &&
            VLCMain.sharedInstance.libraryController.libraryModel == nil;
        if (mediaLibraryUnavailable) {
            cellView.textField.textColor = NSColor.tertiaryLabelColor;
            if (@available(macOS 10.14, *)) {
                cellView.imageView.contentTintColor = NSColor.tertiaryLabelColor;
            }
            continue;
        }

        const BOOL selected = [self.outlineView.selectedRowIndexes containsIndex:row];
        cellView.textField.textColor = selected ? NSColor.VLCVividockAccentColor : NSColor.labelColor;
        if (@available(macOS 10.14, *)) {
            cellView.imageView.contentTintColor = NSColor.VLCVividockAccentColor;
        }
    }
    [self.outlineView setNeedsDisplay:YES];
}

- (NSTableRowView *)outlineView:(NSOutlineView *)outlineView
              rowViewForItem:(id)item
{
    VLCVividockSidebarRowView *rowView = [outlineView makeViewWithIdentifier:VLCVividockSidebarRowViewIdentifier owner:self];
    if (rowView == nil) {
        rowView = [[VLCVividockSidebarRowView alloc] initWithFrame:NSZeroRect];
        rowView.identifier = VLCVividockSidebarRowViewIdentifier;
    }
    return rowView;
}

- (BOOL)outlineView:(NSOutlineView*)outlineView isGroupItem:(id)item
{
    NSTreeNode * const treeNode = (NSTreeNode *)item;
    VLCLibrarySegment * const segment = (VLCLibrarySegment *)treeNode.representedObject;
    return segment.segmentType == VLCLibraryHeaderSegmentType;
}

- (BOOL)outlineView:(nonnull NSOutlineView *)outlineView shouldCollapseItem:(nonnull id)item
{
    NSAssert(outlineView == _outlineView, @"VLCLibraryWindowNavigationSidebarController should only be a delegate for the libraryWindow nav sidebar outline view!");

    // Don't allow collapsing the parent segment of the selected segment, if selection is a child
    NSTreeNode * const treeNode = (NSTreeNode *)item;
    VLCLibrarySegment * const segment = (VLCLibrarySegment *)treeNode.representedObject;
    NSTreeNode * const selectedSegmentItem = (NSTreeNode *)[self.outlineView itemAtRow:self.outlineView.selectedRow];
    VLCLibrarySegment * const selectedSegment = (VLCLibrarySegment *)selectedSegmentItem.representedObject;
    const NSInteger childNodeIndex = [segment.childNodes indexOfObjectPassingTest:^BOOL(NSTreeNode * const _Nonnull obj, const NSUInteger __unused idx, BOOL * const _Nonnull __unused stop) {
        VLCLibrarySegment * const childSegment = (VLCLibrarySegment *)obj;
        return childSegment.segmentType == selectedSegment.segmentType;
    }];
    return childNodeIndex == NSNotFound;
}

@end
