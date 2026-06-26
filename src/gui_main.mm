#import <Cocoa/Cocoa.h>
#import <AVFoundation/AVFoundation.h>

#include "morse2text/ClickInterpreter.hpp"

#include <cmath>
#include <exception>
#include <string>

namespace {

constexpr double sinePi = 3.14159265358979323846;
constexpr double dotTargetSeconds = 0.2;
constexpr double dashTargetSeconds = 0.5;
constexpr double wordGapSeconds = 1.0;
constexpr double timerRefreshSeconds = 1.0 / 60.0;

double clampedValue(double value, double minimum, double maximum)
{
    if (value < minimum) {
        return minimum;
    }

    if (value > maximum) {
        return maximum;
    }

    return value;
}

m2t::ClickInterpreter::Milliseconds timestampFromDate(NSDate *date)
{
    return m2t::ClickInterpreter::Milliseconds(
        static_cast<long long>([date timeIntervalSinceReferenceDate] * 1000.0)
    );
}

} // namespace

@interface MorseTonePlayer : NSObject
@property(nonatomic, strong) AVAudioEngine *engine;
@property(nonatomic, strong) AVAudioSourceNode *sourceNode;
@end

@implementation MorseTonePlayer

- (instancetype)init
{
    self = [super init];
    if (self != nil) {
        constexpr double sampleRate = 44100.0;
        constexpr double frequency = 700.0;
        constexpr double volume = 0.20;
        constexpr double phaseStep = 2.0 * sinePi * frequency / sampleRate;
        __block double phase = 0.0;

        _engine = [[AVAudioEngine alloc] init];
        AVAudioFormat *format = [[AVAudioFormat alloc] initStandardFormatWithSampleRate:sampleRate channels:1];
        _sourceNode = [[AVAudioSourceNode alloc] initWithRenderBlock:^OSStatus(
            BOOL *isSilence,
            const AudioTimeStamp *timestamp,
            AVAudioFrameCount frameCount,
            AudioBufferList *outputData
        ) {
            (void)timestamp;

            *isSilence = NO;
            for (AVAudioFrameCount frame = 0; frame < frameCount; ++frame) {
                const float sample = static_cast<float>(std::sin(phase) * volume);

                for (UInt32 bufferIndex = 0; bufferIndex < outputData->mNumberBuffers; ++bufferIndex) {
                    auto *buffer = static_cast<float *>(outputData->mBuffers[bufferIndex].mData);
                    buffer[frame] = sample;
                }

                phase += phaseStep;
                if (phase >= 2.0 * sinePi) {
                    phase -= 2.0 * sinePi;
                }
            }

            return noErr;
        }];

        [_engine attachNode:_sourceNode];
        [_engine connect:_sourceNode to:[_engine mainMixerNode] format:format];
        [_engine prepare];
    }

    return self;
}

- (void)start
{
    if ([self.engine isRunning]) {
        return;
    }

    NSError *error = nil;
    if (![self.engine startAndReturnError:&error]) {
        NSBeep();
    }
}

- (void)stop
{
    if ([self.engine isRunning]) {
        [self.engine pause];
    }
}

@end

@class HoldButtonView;

@protocol HoldButtonViewDelegate <NSObject>
- (void)holdButtonDidPress:(HoldButtonView *)button atTime:(NSDate *)timestamp;
- (void)holdButtonDidRelease:(HoldButtonView *)button atTime:(NSDate *)timestamp;
- (void)holdButtonDidTick:(HoldButtonView *)button atTime:(NSDate *)timestamp;
@end

@interface HoldButtonView : NSView
@property(nonatomic, assign) BOOL pressed;
@property(nonatomic, assign) NSTimeInterval holdDuration;
@property(nonatomic, assign) NSTimeInterval idleRemaining;
@property(nonatomic, assign) BOOL spacePending;
@property(nonatomic, strong) NSDate *pressStartedAt;
@property(nonatomic, strong) NSDate *lastReleasedAt;
@property(nonatomic, strong) NSTimer *refreshTimer;
@property(nonatomic, strong) MorseTonePlayer *tonePlayer;
@property(nonatomic, weak) id<HoldButtonViewDelegate> delegate;
- (void)startRefreshTimer;
- (void)stopRefreshTimer;
- (void)refreshTimers:(NSTimer *)timer;
- (void)updateTimers;
- (BOOL)shouldInsertSpaceAfterIdle;
- (void)drawPressTimerInRect:(NSRect)timerRect;
- (void)drawIdleTimerInRect:(NSRect)timerRect;
@end

@implementation HoldButtonView

- (instancetype)initWithFrame:(NSRect)frame
{
    self = [super initWithFrame:frame];
    if (self != nil) {
        _pressed = NO;
        _holdDuration = 0.0;
        _idleRemaining = wordGapSeconds;
        _spacePending = NO;
        _pressStartedAt = nil;
        _lastReleasedAt = nil;
        _refreshTimer = nil;
        _tonePlayer = [[MorseTonePlayer alloc] init];
        [self setWantsLayer:YES];
    }
    return self;
}

- (BOOL)isFlipped
{
    return YES;
}

- (void)viewDidMoveToWindow
{
    [super viewDidMoveToWindow];

    if ([self window] == nil) {
        [self stopRefreshTimer];
        return;
    }

    [self startRefreshTimer];
}

- (void)dealloc
{
    [self stopRefreshTimer];
}

- (void)resetCursorRects
{
    [self addCursorRect:[self bounds] cursor:[NSCursor pointingHandCursor]];
}

- (void)mouseDown:(NSEvent *)event
{
    (void)event;

    NSDate *pressDate = [NSDate date];
    self.pressed = YES;
    self.holdDuration = 0.0;
    self.idleRemaining = wordGapSeconds;
    self.spacePending = NO;
    self.pressStartedAt = pressDate;
    self.lastReleasedAt = nil;
    [self.delegate holdButtonDidPress:self atTime:pressDate];
    [self setNeedsDisplay:YES];
    [self startTone];

    BOOL tracking = YES;
    while (tracking) {
        NSEvent *nextEvent = [[self window] nextEventMatchingMask:NSEventMaskLeftMouseDragged | NSEventMaskLeftMouseUp
                                                        untilDate:[NSDate dateWithTimeIntervalSinceNow:1.0 / 60.0]
                                                           inMode:NSEventTrackingRunLoopMode
                                                          dequeue:YES];
        [self updateTimers];

        if (nextEvent == nil) {
            continue;
        }

        if ([nextEvent type] == NSEventTypeLeftMouseUp) {
            tracking = NO;
        }
    }

    [self updateTimers];
    NSDate *releaseDate = [NSDate date];
    [self stopTone];
    self.pressed = NO;
    self.pressStartedAt = nil;
    self.lastReleasedAt = releaseDate;
    [self.delegate holdButtonDidRelease:self atTime:releaseDate];
    [self setNeedsDisplay:YES];
}

- (void)startRefreshTimer
{
    if (self.refreshTimer != nil) {
        return;
    }

    self.refreshTimer = [NSTimer timerWithTimeInterval:timerRefreshSeconds
                                                target:self
                                              selector:@selector(refreshTimers:)
                                              userInfo:nil
                                               repeats:YES];
    [[NSRunLoop mainRunLoop] addTimer:self.refreshTimer forMode:NSRunLoopCommonModes];
}

- (void)stopRefreshTimer
{
    [self.refreshTimer invalidate];
    self.refreshTimer = nil;
}

- (void)refreshTimers:(NSTimer *)timer
{
    (void)timer;
    [self updateTimers];
}

- (void)updateTimers
{
    if (self.pressed && self.pressStartedAt != nil) {
        self.holdDuration = -[self.pressStartedAt timeIntervalSinceNow];
        self.idleRemaining = wordGapSeconds;
        self.spacePending = NO;
    } else if (self.lastReleasedAt != nil) {
        const NSTimeInterval idleTime = -[self.lastReleasedAt timeIntervalSinceNow];

        self.idleRemaining = clampedValue(wordGapSeconds - idleTime, 0.0, wordGapSeconds);
        if (self.idleRemaining <= 0.0) {
            // Future transcription hook: when connected, this state should insert a word space.
            self.spacePending = YES;
        }
    } else {
        self.idleRemaining = wordGapSeconds;
    }

    [self setNeedsDisplay:YES];
    if (!self.pressed && self.lastReleasedAt != nil) {
        [self.delegate holdButtonDidTick:self atTime:[NSDate date]];
    }
}

- (BOOL)shouldInsertSpaceAfterIdle
{
    return self.spacePending;
}

- (void)startTone
{
    [self.tonePlayer start];
}

- (void)stopTone
{
    [self.tonePlayer stop];
}

- (void)drawRect:(NSRect)dirtyRect
{
    (void)dirtyRect;

    const NSRect bounds = [self bounds];
    const CGFloat pressTimerHeight = 40.0;
    const CGFloat buttonHeight = 104.0;
    const CGFloat idleTimerHeight = 48.0;
    const CGFloat buttonGap = 12.0;
    const CGFloat idleGap = 12.0;
    const NSRect pressTimerRect = NSMakeRect(10.0, 2.0, bounds.size.width - 20.0, pressTimerHeight);
    const NSRect buttonRect = NSMakeRect(
        2.0,
        pressTimerHeight + buttonGap,
        bounds.size.width - 4.0,
        buttonHeight
    );
    const NSRect idleTimerRect = NSMakeRect(
        10.0,
        NSMaxY(buttonRect) + idleGap,
        bounds.size.width - 20.0,
        idleTimerHeight
    );
    NSBezierPath *buttonPath = [NSBezierPath bezierPathWithRoundedRect:buttonRect xRadius:10.0 yRadius:10.0];

    NSColor *fillColor = self.pressed
        ? [NSColor colorWithCalibratedRed:0.09 green:0.33 blue:0.68 alpha:1.0]
        : [NSColor colorWithCalibratedRed:0.94 green:0.96 blue:0.98 alpha:1.0];
    NSColor *strokeColor = self.pressed
        ? [NSColor colorWithCalibratedRed:0.03 green:0.18 blue:0.40 alpha:1.0]
        : [NSColor colorWithCalibratedRed:0.53 green:0.60 blue:0.68 alpha:1.0];
    NSColor *textColor = self.pressed ? [NSColor whiteColor] : [NSColor colorWithCalibratedWhite:0.13 alpha:1.0];

    [self drawPressTimerInRect:pressTimerRect];
    [self drawIdleTimerInRect:idleTimerRect];

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

- (void)drawPressTimerInRect:(NSRect)timerRect
{
    const CGFloat trackHeight = 8.0;
    const CGFloat labelHeight = 16.0;
    const NSRect trackRect = NSMakeRect(
        timerRect.origin.x,
        timerRect.origin.y + labelHeight,
        timerRect.size.width,
        trackHeight
    );
    double cappedDuration = self.holdDuration;
    if (cappedDuration < 0.0) {
        cappedDuration = 0.0;
    }
    if (cappedDuration > dashTargetSeconds) {
        cappedDuration = dashTargetSeconds;
    }

    const CGFloat fillWidth = trackRect.size.width * static_cast<CGFloat>(cappedDuration / dashTargetSeconds);
    const NSRect fillRect = NSMakeRect(trackRect.origin.x, trackRect.origin.y, fillWidth, trackRect.size.height);
    const CGFloat dotTargetX = trackRect.origin.x + trackRect.size.width * static_cast<CGFloat>(dotTargetSeconds / dashTargetSeconds);
    const CGFloat dashTargetX = NSMaxX(trackRect);
    const CGFloat indicatorX = trackRect.origin.x + fillWidth;

    NSMutableParagraphStyle *centeredStyle = [[NSMutableParagraphStyle alloc] init];
    [centeredStyle setAlignment:NSTextAlignmentCenter];

    NSDictionary *timeAttributes = @{
        NSFontAttributeName: [NSFont monospacedDigitSystemFontOfSize:13.0 weight:NSFontWeightSemibold],
        NSForegroundColorAttributeName: [NSColor colorWithCalibratedWhite:0.12 alpha:1.0],
        NSParagraphStyleAttributeName: centeredStyle,
    };
    NSDictionary *markerAttributes = @{
        NSFontAttributeName: [NSFont monospacedDigitSystemFontOfSize:11.0 weight:NSFontWeightMedium],
        NSForegroundColorAttributeName: [NSColor colorWithCalibratedWhite:0.36 alpha:1.0],
        NSParagraphStyleAttributeName: centeredStyle,
    };

    NSString *durationText = [NSString stringWithFormat:@"%.1fs", cappedDuration];
    [durationText drawInRect:NSMakeRect(timerRect.origin.x, timerRect.origin.y - 1.0, timerRect.size.width, labelHeight)
              withAttributes:timeAttributes];

    NSBezierPath *trackPath = [NSBezierPath bezierPathWithRoundedRect:trackRect xRadius:trackHeight / 2.0 yRadius:trackHeight / 2.0];
    [[NSColor colorWithCalibratedRed:0.82 green:0.86 blue:0.90 alpha:1.0] setFill];
    [trackPath fill];

    if (fillWidth > 0.0) {
        NSBezierPath *fillPath = [NSBezierPath bezierPathWithRoundedRect:fillRect xRadius:trackHeight / 2.0 yRadius:trackHeight / 2.0];
        [[NSColor colorWithCalibratedRed:0.12 green:0.45 blue:0.82 alpha:1.0] setFill];
        [fillPath fill];
    }

    [[NSColor colorWithCalibratedWhite:0.27 alpha:1.0] setStroke];
    NSBezierPath *dotMarker = [NSBezierPath bezierPath];
    [dotMarker moveToPoint:NSMakePoint(dotTargetX, trackRect.origin.y - 3.0)];
    [dotMarker lineToPoint:NSMakePoint(dotTargetX, trackRect.origin.y + trackRect.size.height + 3.0)];
    [dotMarker setLineWidth:1.0];
    [dotMarker stroke];

    NSBezierPath *dashMarker = [NSBezierPath bezierPath];
    [dashMarker moveToPoint:NSMakePoint(dashTargetX, trackRect.origin.y - 3.0)];
    [dashMarker lineToPoint:NSMakePoint(dashTargetX, trackRect.origin.y + trackRect.size.height + 3.0)];
    [dashMarker setLineWidth:1.0];
    [dashMarker stroke];

    [[NSColor colorWithCalibratedRed:0.03 green:0.18 blue:0.40 alpha:1.0] setStroke];
    NSBezierPath *indicator = [NSBezierPath bezierPath];
    [indicator moveToPoint:NSMakePoint(indicatorX, trackRect.origin.y - 5.0)];
    [indicator lineToPoint:NSMakePoint(indicatorX, trackRect.origin.y + trackRect.size.height + 5.0)];
    [indicator setLineWidth:2.0];
    [indicator stroke];

    const CGFloat markerY = trackRect.origin.y + trackRect.size.height + 2.0;
    [@"0" drawInRect:NSMakeRect(trackRect.origin.x - 12.0, markerY, 24.0, 14.0) withAttributes:markerAttributes];
    [@"0.2" drawInRect:NSMakeRect(dotTargetX - 18.0, markerY, 36.0, 14.0) withAttributes:markerAttributes];
    [@"0.5" drawInRect:NSMakeRect(dashTargetX - 18.0, markerY, 36.0, 14.0) withAttributes:markerAttributes];
}

- (void)drawIdleTimerInRect:(NSRect)timerRect
{
    const CGFloat labelHeight = 18.0;
    const CGFloat trackHeight = 8.0;
    const NSRect trackRect = NSMakeRect(
        timerRect.origin.x,
        timerRect.origin.y + labelHeight + 2.0,
        timerRect.size.width,
        trackHeight
    );
    const double cappedRemaining = clampedValue(self.idleRemaining, 0.0, wordGapSeconds);
    const CGFloat fillWidth = trackRect.size.width * static_cast<CGFloat>(cappedRemaining / wordGapSeconds);
    const NSRect fillRect = NSMakeRect(trackRect.origin.x, trackRect.origin.y, fillWidth, trackRect.size.height);
    const CGFloat halfSecondX = trackRect.origin.x + trackRect.size.width / 2.0;
    const CGFloat oneSecondX = NSMaxX(trackRect);

    NSMutableParagraphStyle *centeredStyle = [[NSMutableParagraphStyle alloc] init];
    [centeredStyle setAlignment:NSTextAlignmentCenter];

    NSDictionary *titleAttributes = @{
        NSFontAttributeName: [NSFont monospacedDigitSystemFontOfSize:11.0 weight:NSFontWeightSemibold],
        NSForegroundColorAttributeName: [NSColor colorWithCalibratedWhite:0.18 alpha:1.0],
        NSParagraphStyleAttributeName: centeredStyle,
    };
    NSDictionary *markerAttributes = @{
        NSFontAttributeName: [NSFont monospacedDigitSystemFontOfSize:11.0 weight:NSFontWeightMedium],
        NSForegroundColorAttributeName: [NSColor colorWithCalibratedWhite:0.36 alpha:1.0],
        NSParagraphStyleAttributeName: centeredStyle,
    };

    NSString *title = [NSString stringWithFormat:@"Temps restant avant un espace %.1fs", cappedRemaining];
    [title drawInRect:NSMakeRect(timerRect.origin.x, timerRect.origin.y, timerRect.size.width, labelHeight)
       withAttributes:titleAttributes];

    NSBezierPath *trackPath = [NSBezierPath bezierPathWithRoundedRect:trackRect xRadius:trackHeight / 2.0 yRadius:trackHeight / 2.0];
    [[NSColor colorWithCalibratedRed:0.84 green:0.86 blue:0.88 alpha:1.0] setFill];
    [trackPath fill];

    if (fillWidth > 0.0) {
        NSBezierPath *fillPath = [NSBezierPath bezierPathWithRoundedRect:fillRect xRadius:trackHeight / 2.0 yRadius:trackHeight / 2.0];
        [[NSColor colorWithCalibratedRed:0.86 green:0.43 blue:0.18 alpha:1.0] setFill];
        [fillPath fill];
    }

    [[NSColor colorWithCalibratedWhite:0.27 alpha:1.0] setStroke];
    NSBezierPath *halfSecondMarker = [NSBezierPath bezierPath];
    [halfSecondMarker moveToPoint:NSMakePoint(halfSecondX, trackRect.origin.y - 3.0)];
    [halfSecondMarker lineToPoint:NSMakePoint(halfSecondX, trackRect.origin.y + trackRect.size.height + 3.0)];
    [halfSecondMarker setLineWidth:1.0];
    [halfSecondMarker stroke];

    NSBezierPath *oneSecondMarker = [NSBezierPath bezierPath];
    [oneSecondMarker moveToPoint:NSMakePoint(oneSecondX, trackRect.origin.y - 3.0)];
    [oneSecondMarker lineToPoint:NSMakePoint(oneSecondX, trackRect.origin.y + trackRect.size.height + 3.0)];
    [oneSecondMarker setLineWidth:1.0];
    [oneSecondMarker stroke];

    const CGFloat markerY = trackRect.origin.y + trackRect.size.height + 2.0;
    [@"0" drawInRect:NSMakeRect(trackRect.origin.x - 12.0, markerY, 24.0, 14.0) withAttributes:markerAttributes];
    [@"0.5" drawInRect:NSMakeRect(halfSecondX - 18.0, markerY, 36.0, 14.0) withAttributes:markerAttributes];
    [@"1" drawInRect:NSMakeRect(oneSecondX - 12.0, markerY, 24.0, 14.0) withAttributes:markerAttributes];
}

@end

@interface SplitWindowView : NSView <HoldButtonViewDelegate> {
    m2t::ClickInterpreter _interpreter;
}
@property(nonatomic, strong) NSView *leftPane;
@property(nonatomic, strong) NSView *rightPane;
@property(nonatomic, strong) HoldButtonView *holdButton;
@property(nonatomic, strong) NSTextField *morseTitle;
@property(nonatomic, strong) NSTextField *wordsTitle;
@property(nonatomic, strong) NSScrollView *morseScrollView;
@property(nonatomic, strong) NSScrollView *wordsScrollView;
@property(nonatomic, strong) NSTextView *morseTextView;
@property(nonatomic, strong) NSTextView *wordsTextView;
@property(nonatomic, copy) NSString *transcriptionError;
- (NSTextField *)makeTitleLabel:(NSString *)title;
- (NSTextView *)makeTextViewWithFont:(NSFont *)font;
- (NSScrollView *)makeScrollViewWithTextView:(NSTextView *)textView;
- (void)updateTranscriptionViews;
- (void)handleInterpreterException:(const std::exception&)exception;
@end

@implementation SplitWindowView

- (instancetype)initWithFrame:(NSRect)frame
{
    self = [super initWithFrame:frame];
    if (self != nil) {
        _leftPane = [[NSView alloc] initWithFrame:NSZeroRect];
        _rightPane = [[NSView alloc] initWithFrame:NSZeroRect];
        _holdButton = [[HoldButtonView alloc] initWithFrame:NSZeroRect];
        _morseTitle = [self makeTitleLabel:@"Morse"];
        _wordsTitle = [self makeTitleLabel:@"Mots"];
        _morseTextView = [self makeTextViewWithFont:[NSFont monospacedSystemFontOfSize:24.0 weight:NSFontWeightRegular]];
        _wordsTextView = [self makeTextViewWithFont:[NSFont systemFontOfSize:24.0 weight:NSFontWeightRegular]];
        _morseScrollView = [self makeScrollViewWithTextView:_morseTextView];
        _wordsScrollView = [self makeScrollViewWithTextView:_wordsTextView];

        [_leftPane setWantsLayer:YES];
        [_rightPane setWantsLayer:YES];
        [[_leftPane layer] setBackgroundColor:[[NSColor colorWithCalibratedRed:0.96 green:0.97 blue:0.98 alpha:1.0] CGColor]];
        [[_rightPane layer] setBackgroundColor:[[NSColor whiteColor] CGColor]];

        [self addSubview:_leftPane];
        [self addSubview:_rightPane];
        [_leftPane addSubview:_holdButton];
        [_rightPane addSubview:_morseTitle];
        [_rightPane addSubview:_morseScrollView];
        [_rightPane addSubview:_wordsTitle];
        [_rightPane addSubview:_wordsScrollView];

        [_holdButton setDelegate:self];
        [self updateTranscriptionViews];
    }
    return self;
}

- (BOOL)isFlipped
{
    return YES;
}

- (NSTextField *)makeTitleLabel:(NSString *)title
{
    NSTextField *label = [[NSTextField alloc] initWithFrame:NSZeroRect];

    [label setStringValue:title];
    [label setEditable:NO];
    [label setSelectable:NO];
    [label setBordered:NO];
    [label setDrawsBackground:NO];
    [label setFont:[NSFont boldSystemFontOfSize:13.0]];
    [label setTextColor:[NSColor colorWithCalibratedWhite:0.20 alpha:1.0]];
    return label;
}

- (NSTextView *)makeTextViewWithFont:(NSFont *)font
{
    NSTextView *textView = [[NSTextView alloc] initWithFrame:NSZeroRect];

    [textView setEditable:NO];
    [textView setSelectable:YES];
    [textView setRichText:NO];
    [textView setDrawsBackground:NO];
    [textView setFont:font];
    [textView setTextColor:[NSColor colorWithCalibratedWhite:0.12 alpha:1.0]];
    [textView setTextContainerInset:NSMakeSize(10.0, 10.0)];
    [[textView textContainer] setWidthTracksTextView:YES];
    return textView;
}

- (NSScrollView *)makeScrollViewWithTextView:(NSTextView *)textView
{
    NSScrollView *scrollView = [[NSScrollView alloc] initWithFrame:NSZeroRect];

    [scrollView setBorderType:NSNoBorder];
    [scrollView setHasVerticalScroller:YES];
    [scrollView setDrawsBackground:YES];
    [scrollView setBackgroundColor:[NSColor colorWithCalibratedRed:0.97 green:0.98 blue:0.99 alpha:1.0]];
    [scrollView setDocumentView:textView];
    return scrollView;
}

- (void)updateTranscriptionViews
{
    NSString *morseText = [NSString stringWithUTF8String:_interpreter.morse().c_str()];
    NSString *wordsText = self.transcriptionError != nil
        ? self.transcriptionError
        : [NSString stringWithUTF8String:_interpreter.message().c_str()];

    [self.morseTextView setString:morseText];
    [self.wordsTextView setString:wordsText];
    [self.morseTextView scrollRangeToVisible:NSMakeRange([[self.morseTextView string] length], 0)];
    [self.wordsTextView scrollRangeToVisible:NSMakeRange([[self.wordsTextView string] length], 0)];
}

- (void)handleInterpreterException:(const std::exception&)exception
{
    self.transcriptionError = [NSString stringWithFormat:@"Erreur: %s", exception.what()];
    _interpreter.reset();
    [self updateTranscriptionViews];
}

- (void)holdButtonDidPress:(HoldButtonView *)button atTime:(NSDate *)timestamp
{
    (void)button;

    self.transcriptionError = nil;
    try {
        _interpreter.press(timestampFromDate(timestamp));
    } catch (const std::exception& exception) {
        [self handleInterpreterException:exception];
    }
    [self updateTranscriptionViews];
}

- (void)holdButtonDidRelease:(HoldButtonView *)button atTime:(NSDate *)timestamp
{
    (void)button;

    self.transcriptionError = nil;
    try {
        _interpreter.release(timestampFromDate(timestamp));
    } catch (const std::exception& exception) {
        [self handleInterpreterException:exception];
    }
    [self updateTranscriptionViews];
}

- (void)holdButtonDidTick:(HoldButtonView *)button atTime:(NSDate *)timestamp
{
    (void)button;

    if (self.transcriptionError != nil) {
        return;
    }

    try {
        _interpreter.tick(timestampFromDate(timestamp));
    } catch (const std::exception& exception) {
        [self handleInterpreterException:exception];
    }
    [self updateTranscriptionViews];
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

    const NSSize buttonSize = NSMakeSize(300.0, 216.0);
    const CGFloat buttonX = floor((leftWidth - buttonSize.width) / 2.0);
    const CGFloat buttonY = floor((bounds.size.height - buttonSize.height) / 2.0);
    [self.holdButton setFrame:NSMakeRect(buttonX, buttonY, buttonSize.width, buttonSize.height)];

    const NSRect rightBounds = [self.rightPane bounds];
    const CGFloat padding = 24.0;
    const CGFloat sectionGap = 24.0;
    const CGFloat titleHeight = 20.0;
    const CGFloat titleGap = 8.0;
    CGFloat sectionHeight = floor((rightBounds.size.height - padding * 2.0 - sectionGap) / 2.0);
    if (sectionHeight < 80.0) {
        sectionHeight = 80.0;
    }

    const CGFloat contentWidth = rightBounds.size.width - padding * 2.0;
    const NSRect wordsSection = NSMakeRect(padding, padding, contentWidth, sectionHeight);
    const NSRect morseSection = NSMakeRect(padding, padding + sectionHeight + sectionGap, contentWidth, sectionHeight);
    const CGFloat textHeight = sectionHeight - titleHeight - titleGap;

    [self.morseTitle setFrame:NSMakeRect(morseSection.origin.x, NSMaxY(morseSection) - titleHeight, contentWidth, titleHeight)];
    [self.morseScrollView setFrame:NSMakeRect(morseSection.origin.x, morseSection.origin.y, contentWidth, textHeight)];
    [self.wordsTitle setFrame:NSMakeRect(wordsSection.origin.x, NSMaxY(wordsSection) - titleHeight, contentWidth, titleHeight)];
    [self.wordsScrollView setFrame:NSMakeRect(wordsSection.origin.x, wordsSection.origin.y, contentWidth, textHeight)];

    NSRect morseContentBounds = [[self.morseScrollView contentView] bounds];
    NSRect wordsContentBounds = [[self.wordsScrollView contentView] bounds];
    [self.morseTextView setFrame:NSMakeRect(0.0, 0.0, morseContentBounds.size.width, morseContentBounds.size.height)];
    [self.wordsTextView setFrame:NSMakeRect(0.0, 0.0, wordsContentBounds.size.width, wordsContentBounds.size.height)];
}

- (void)drawRect:(NSRect)dirtyRect
{
    (void)dirtyRect;

    const CGFloat leftWidth = floor([self bounds].size.width / 2.0);
    [[NSColor colorWithCalibratedRed:0.76 green:0.79 blue:0.83 alpha:1.0] setFill];
    NSRectFill(NSMakeRect(leftWidth, 0.0, 1.0, [self bounds].size.height));

    const CGFloat rightX = leftWidth + 1.0;
    const CGFloat rightWidth = [self bounds].size.width - rightX;
    const CGFloat horizontalDividerY = floor([self bounds].size.height / 2.0);
    NSRectFill(NSMakeRect(rightX, horizontalDividerY, rightWidth, 1.0));
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
