#import "Injector.h"
#import <GameController/GameController.h>
#import <UIKit/UIKit.h>
#import "Common.h"
#import "Input.h"
#import "Pad.h"

static GCVirtualController *g_vc;
static GCController *g_ctl;
static GCExtendedGamepad *g_pad;
static CADisplayLink *g_link;
static BOOL g_active = NO;
static BOOL g_suppress = NO;

@implementation Injector

+ (void)setup {
    if (@available(iOS 15.0, *)) {
        GCVirtualControllerConfiguration *cfg = [GCVirtualControllerConfiguration new];
        cfg.elements = [NSSet setWithObjects:
            GCInputLeftThumbstick,
            GCInputButtonA, GCInputButtonB, GCInputButtonX, GCInputButtonY,
            GCInputLeftShoulder, GCInputRightShoulder,
            GCInputLeftTrigger, GCInputRightTrigger,
            GCInputDirectionPad,
            GCInputButtonMenu, GCInputButtonOptions,
            nil];
        g_vc = [[GCVirtualController alloc] initWithConfiguration:cfg];
        if (!g_vc) return;

        NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
        [nc addObserver:self selector:@selector(onConnect:)
            name:GCControllerDidConnectNotification object:nil];
        [nc addObserver:self selector:@selector(onDisconnect:)
            name:GCControllerDidDisconnectNotification object:nil];
        [nc addObserver:self selector:@selector(onBG)
            name:UIApplicationDidEnterBackgroundNotification object:nil];
        [nc addObserver:self selector:@selector(onFG)
            name:UIApplicationWillEnterForegroundNotification object:nil];

        [self activate];
    }
}

+ (void)activate {
    if (!g_vc) return;
    [g_vc connectWithReplyHandler:^(NSError *e) {
        if (e) return;
        g_active = YES;
        g_ctl = g_vc.controller;
        if (g_ctl) {
            g_ctl.playerIndex = GCControllerPlayerIndex1;
            g_pad = g_ctl.extendedGamepad;
        }
        dispatch_async(dispatch_get_main_queue(), ^{
            [self hideSystemUI];
            [Input installHook];
            [Input bindPad:g_pad];
            [self startLoop];
            [Pad setVisible:YES];
        });
    }];
}

+ (void)deactivate {
    g_suppress = YES;
    [self stopLoop];
    if (g_vc) [g_vc disconnect];
    g_active = NO;
    g_pad = nil;
    g_ctl = nil;
    [Input bindPad:nil];
    [[InputState shared] reset];
    [Pad setVisible:NO];
    g_suppress = NO;
}

+ (void)hideSystemUI {
    if (!g_vc) return;
    NSArray *els = @[
        GCInputDirectionPad, GCInputLeftThumbstick, GCInputRightThumbstick,
        GCInputButtonA, GCInputButtonB, GCInputButtonX, GCInputButtonY,
        GCInputLeftShoulder, GCInputRightShoulder,
        GCInputLeftTrigger, GCInputRightTrigger,
        GCInputButtonMenu, GCInputButtonOptions,
    ];
    for (NSString *e in els) {
        [g_vc updateConfigurationForElement:e
            configuration:^GCVirtualControllerElementConfiguration * _Nonnull(
                GCVirtualControllerElementConfiguration * _Nonnull c) {
                c.hidden = YES;
                return c;
            }];
    }
}

+ (void)startLoop {
    if (g_link) return;
    g_link = [CADisplayLink displayLinkWithTarget:self
                                         selector:@selector(tick)];
    if (@available(iOS 15.0, *)) {
        g_link.preferredFrameRateRange = CAFrameRateRangeMake(30, 120, 60);
    } else {
        g_link.preferredFramesPerSecond = 60;
    }
    [g_link addToRunLoop:[NSRunLoop mainRunLoop]
                 forMode:NSRunLoopCommonModes];
}

+ (void)stopLoop {
    if (g_link) {
        [g_link invalidate];
        g_link = nil;
    }
}

+ (void)tick {
    if (!g_pad || !g_pad.leftThumbstick) return;
    float x, y;
    [[InputState shared] snapshotStickX:&x y:&y];

    @try {
        SEL sel = NSSelectorFromString(@"setValue:");

        NSMethodSignature *sx = [g_pad.leftThumbstick.xAxis
            methodSignatureForSelector:sel];
        if (sx) {
            NSInvocation *inv = [NSInvocation invocationWithMethodSignature:sx];
            inv.selector = sel;
            inv.target = g_pad.leftThumbstick.xAxis;
            [inv setArgument:&x atIndex:2];
            [inv invoke];
        }

        NSMethodSignature *sy = [g_pad.leftThumbstick.yAxis
            methodSignatureForSelector:sel];
        if (sy) {
            NSInvocation *inv = [NSInvocation invocationWithMethodSignature:sy];
            inv.selector = sel;
            inv.target = g_pad.leftThumbstick.yAxis;
            [inv setArgument:&y atIndex:2];
            [inv invoke];
        }
    } @catch (NSException *e) {
        LOG(@"tick EX: %@", e);
    }
}

+ (void)onConnect:(NSNotification *)n {
    if (!n) return;
    GCController *c = n.object;
    if (![c isKindOfClass:[GCController class]]) return;
    if (g_vc && c == g_vc.controller) return;
    if (!c.extendedGamepad && !c.microGamepad) return;
    dispatch_async(dispatch_get_main_queue(), ^{ [self deactivate]; });
}

+ (void)onDisconnect:(NSNotification *)n {
    if (g_suppress) return;
    if (!n) return;
    GCController *c = n.object;
    if (![c isKindOfClass:[GCController class]]) return;
    if (g_vc && c == g_vc.controller) return;
    for (GCController *x in [GCController controllers]) {
        if (g_vc && x == g_vc.controller) continue;
        if (x.extendedGamepad || x.microGamepad) return;
    }
    dispatch_async(dispatch_get_main_queue(), ^{ [self activate]; });
}

+ (void)onBG {
    if (g_active) [self deactivate];
}

+ (void)onFG {
    for (GCController *x in [GCController controllers]) {
        if (g_vc && x == g_vc.controller) continue;
        if (x.extendedGamepad || x.microGamepad) return;
    }
    if (!g_active) [self activate];
}

@end