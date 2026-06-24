#import <Cocoa/Cocoa.h>

@interface HoldButtonView : NSView
@property(nonatomic, assign) BOOL pressed;
@end

@implementation HoldButtonView

- (instancetype)initWithFrame:(NSRect)frame
{
    self = [super initWithFrame:frame];
    if (self != nil) {
        _pressed = NO;
        [self setWantsLayer:YES];
    }
    return self;
}

- (BOOL)isFlipped
{
    return YES;
}

- (void)resetCursorRects
{
    [self addCursorRect:[self bounds] cursor:[NSCursor pointingHandCursor]];
}

- (void)mouseDown:(NSEvent *)event
{
    (void)event;

    self.pressed = YES;
    [self setNeedsDisplay:YES];

    BOOL tracking = YES;
    while (tracking) {
        NSEvent *nextEvent = [[self window] nextEventMatchingMask:NSEventMaskLeftMouseDragged | NSEventMaskLeftMouseUp];

        if ([nextEvent type] == NSEventTypeLeftMouseUp) {
            tracking = NO;
        }
    }

    self.pressed = NO;
    [self setNeedsDisplay:YES];
}

- (void)drawRect:(NSRect)dirtyRect
{
    (void)dirtyRect;

    const NSRect buttonRect = NSInsetRect([self bounds], 2.0, 2.0);
    NSBezierPath *buttonPath = [NSBezierPath bezierPathWithRoundedRect:buttonRect xRadius:10.0 yRadius:10.0];

    NSColor *fillColor = self.pressed
        ? [NSColor colorWithCalibratedRed:0.09 green:0.33 blue:0.68 alpha:1.0]
        : [NSColor colorWithCalibratedRed:0.94 green:0.96 blue:0.98 alpha:1.0];
    NSColor *strokeColor = self.pressed
        ? [NSColor colorWithCalibratedRed:0.03 green:0.18 blue:0.40 alpha:1.0]
        : [NSColor colorWithCalibratedRed:0.53 green:0.60 blue:0.68 alpha:1.0];
    NSColor *textColor = self.pressed ? [NSColor whiteColor] : [NSColor colorWithCalibratedWhite:0.13 alpha:1.0];

    [fillColor setFill];
    [buttonPath fill];

    [strokeColor setStroke];
    [buttonPath setLineWidth:self.pressed ? 3.0 : 2.0];
    [buttonPath stroke];

    NSString *title = self.pressed ? @"Pressed" : @"Hold click";
    NSString *subtitle = self.pressed ? @"Release to stop" : @"Keep mouse down";

    NSMutableParagraphStyle *paragraphStyle = [[NSMutableParagraphStyle alloc] init];
    [paragraphStyle setAlignment:NSTextAlignmentCenter];

    NSDictionary *titleAttributes = @{
        NSFontAttributeName: [NSFont boldSystemFontOfSize:24.0],
        NSForegroundColorAttributeName: textColor,
        NSParagraphStyleAttributeName: paragraphStyle,
    };
    NSDictionary *subtitleAttributes = @{
        NSFontAttributeName: [NSFont systemFontOfSize:13.0],
        NSForegroundColorAttributeName: textColor,
        NSParagraphStyleAttributeName: paragraphStyle,
    };

    NSRect titleRect = NSMakeRect(0.0, buttonRect.origin.y + 24.0, [self bounds].size.width, 30.0);
    NSRect subtitleRect = NSMakeRect(0.0, buttonRect.origin.y + 56.0, [self bounds].size.width, 20.0);

    [title drawInRect:titleRect withAttributes:titleAttributes];
    [subtitle drawInRect:subtitleRect withAttributes:subtitleAttributes];
}

@end

@interface SplitWindowView : NSView
@property(nonatomic, strong) NSView *leftPane;
@property(nonatomic, strong) NSView *rightPane;
@property(nonatomic, strong) HoldButtonView *holdButton;
@end

@implementation SplitWindowView

- (instancetype)initWithFrame:(NSRect)frame
{
    self = [super initWithFrame:frame];
    if (self != nil) {
        _leftPane = [[NSView alloc] initWithFrame:NSZeroRect];
        _rightPane = [[NSView alloc] initWithFrame:NSZeroRect];
        _holdButton = [[HoldButtonView alloc] initWithFrame:NSZeroRect];

        [_leftPane setWantsLayer:YES];
        [_rightPane setWantsLayer:YES];
        [[_leftPane layer] setBackgroundColor:[[NSColor colorWithCalibratedRed:0.96 green:0.97 blue:0.98 alpha:1.0] CGColor]];
        [[_rightPane layer] setBackgroundColor:[[NSColor whiteColor] CGColor]];

        [self addSubview:_leftPane];
        [self addSubview:_rightPane];
        [_leftPane addSubview:_holdButton];
    }
    return self;
}

- (BOOL)isFlipped
{
    return YES;
}

- (void)layout
{
    [super layout];

    const NSRect bounds = [self bounds];
    const CGFloat dividerWidth = 1.0;
    const CGFloat leftWidth = floor(bounds.size.width / 2.0);
    const CGFloat rightWidth = bounds.size.width - leftWidth - dividerWidth;

    [self.leftPane setFrame:NSMakeRect(0.0, 0.0, leftWidth, bounds.size.height)];
    [self.rightPane setFrame:NSMakeRect(leftWidth + dividerWidth, 0.0, rightWidth, bounds.size.height)];

    const NSSize buttonSize = NSMakeSize(240.0, 104.0);
    const CGFloat buttonX = floor((leftWidth - buttonSize.width) / 2.0);
    const CGFloat buttonY = floor((bounds.size.height - buttonSize.height) / 2.0);
    [self.holdButton setFrame:NSMakeRect(buttonX, buttonY, buttonSize.width, buttonSize.height)];
}

- (void)drawRect:(NSRect)dirtyRect
{
    (void)dirtyRect;

    const CGFloat leftWidth = floor([self bounds].size.width / 2.0);
    [[NSColor colorWithCalibratedRed:0.76 green:0.79 blue:0.83 alpha:1.0] setFill];
    NSRectFill(NSMakeRect(leftWidth, 0.0, 1.0, [self bounds].size.height));
}

@end

@interface AppDelegate : NSObject <NSApplicationDelegate>
@property(nonatomic, strong) NSWindow *window;
@end

@implementation AppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)notification
{
    (void)notification;

    NSRect windowFrame = NSMakeRect(0.0, 0.0, 900.0, 520.0);
    NSUInteger style = NSWindowStyleMaskTitled | NSWindowStyleMaskClosable | NSWindowStyleMaskMiniaturizable | NSWindowStyleMaskResizable;

    self.window = [[NSWindow alloc] initWithContentRect:windowFrame
                                              styleMask:style
                                                backing:NSBackingStoreBuffered
                                                  defer:NO];
    [self.window setTitle:@"Morse2Text"];
    [self.window setMinSize:NSMakeSize(640.0, 360.0)];
    [self.window center];

    SplitWindowView *rootView = [[SplitWindowView alloc] initWithFrame:[[self.window contentView] bounds]];
    [rootView setAutoresizingMask:NSViewWidthSizable | NSViewHeightSizable];
    [self.window setContentView:rootView];

    [self.window makeKeyAndOrderFront:nil];
    [NSApp activateIgnoringOtherApps:YES];
}

- (BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication *)sender
{
    (void)sender;
    return YES;
}

@end

int main(void)
{
    @autoreleasepool {
        NSApplication *application = [NSApplication sharedApplication];
        AppDelegate *delegate = [[AppDelegate alloc] init];

        [application setActivationPolicy:NSApplicationActivationPolicyRegular];
        [application setDelegate:delegate];
        [application run];
    }

    return 0;
}
