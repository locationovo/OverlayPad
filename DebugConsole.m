#import "DebugConsole.h"
#import <os/lock.h>

static os_unfair_lock gLk = OS_UNFAIR_LOCK_INIT;
static NSMutableArray<NSString *> *gBuf = nil;
static BOOL gDirty = NO;

static UIWindow *gWin = nil;
static UIView *gBox = nil;
static UILabel *gLabel = nil;
static UIScrollView *gScroll = nil;
static CADisplayLink *gLink = nil;
static NSTimeInterval gLastFlush = 0;
static BOOL gCollapsed = NO;

@interface DbgWindow : UIWindow @end
@implementation DbgWindow
- (UIView *)hitTest:(CGPoint)p withEvent:(UIEvent *)e {
    UIView *hit = [super hitTest:p withEvent:e];
    if (!hit) return nil;
    if (hit == self) return nil;
    if (hit == self.rootViewController.view) return nil;
    return hit;
}
@end

void DBGInit(void) {
    gBuf = [NSMutableArray array];
}

void DBG(NSString *fmt, ...) {
    va_list ap;
    va_start(ap, fmt);
    NSString *s = [[NSString alloc] initWithFormat:fmt arguments:ap];
    va_end(ap);
    [DebugConsole log:s];
}

@implementation DebugConsole

+ (void)log:(NSString *)line {
    if (!line) return;
    static NSDateFormatter *df;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        df = [NSDateFormatter new];
        df.dateFormat = @"HH:mm:ss.SSS";
    });
    NSString *full = [NSString stringWithFormat:@"%@  %@",
                      [df stringFromDate:[NSDate date]], line];
    os_unfair_lock_lock(&gLk);
    if (!gBuf) gBuf = [NSMutableArray array];
    [gBuf addObject:full];
    if (gBuf.count > 400) [gBuf removeObjectAtIndex:0];
    gDirty = YES;
    os_unfair_lock_unlock(&gLk);
    NSLog(@"[joy] %@", line);
}

+ (void)setup {
    dispatch_async(dispatch_get_main_queue(), ^{
        UIWindowScene *ws = nil;
        for (UIScene *s in [UIApplication sharedApplication].connectedScenes) {
            if ([s isKindOfClass:[UIWindowScene class]] &&
                s.activationState == UISceneActivationStateForegroundActive) {
                ws = (UIWindowScene *)s;
                break;
            }
        }
        if (!ws) return;

        gWin = [[DbgWindow alloc] initWithWindowScene:ws];
        gWin.frame = ws.coordinateSpace.bounds;
        gWin.windowLevel = UIWindowLevelAlert + 100;
        gWin.backgroundColor = [UIColor clearColor];
        gWin.rootViewController = [UIViewController new];
        gWin.hidden = NO;

        UIView *root = gWin.rootViewController.view;
        root.backgroundColor = [UIColor clearColor];

        CGFloat bw = 320, bh = 220;
        gBox = [[UIView alloc] initWithFrame:CGRectMake(8, 60, bw, bh)];
        gBox.backgroundColor = [UIColor colorWithRed:0 green:0 blue:0 alpha:0.82];
        gBox.layer.cornerRadius = 8;
        gBox.layer.masksToBounds = YES;
        gBox.userInteractionEnabled = YES;
        [root addSubview:gBox];

        UIView *bar = [[UIView alloc] initWithFrame:CGRectMake(0, 0, bw, 28)];
        bar.backgroundColor = [UIColor colorWithRed:0.15 green:0.15 blue:0.15 alpha:1];
        [gBox addSubview:bar];

        UILabel *title = [[UILabel alloc] initWithFrame:CGRectMake(8, 0, 60, 28)];
        title.text = @"Debug";
        title.textColor = [UIColor whiteColor];
        title.font = [UIFont boldSystemFontOfSize:12];
        [bar addSubview:title];

        NSArray *titles = @[@"Copy", @"Clear", @"-"];
        SEL sels[3] = { @selector(onCopy), @selector(onClear), @selector(onFold) };
        for (int i = 0; i < 3; i++) {
            UIButton *b = [UIButton buttonWithType:UIButtonTypeSystem];
            b.frame = CGRectMake(bw - 180 + i * 60, 0, 60, 28);
            [b setTitle:titles[i] forState:UIControlStateNormal];
            [b setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
            b.titleLabel.font = [UIFont systemFontOfSize:12];
            [b addTarget:self action:sels[i]
                forControlEvents:UIControlEventTouchUpInside];
            [bar addSubview:b];
        }

        gScroll = [[UIScrollView alloc] initWithFrame:
            CGRectMake(0, 28, bw, bh - 28)];
        [gBox addSubview:gScroll];

        gLabel = [[UILabel alloc] initWithFrame:CGRectMake(4, 4, bw - 8, 100)];
        gLabel.numberOfLines = 0;
        gLabel.textColor = [UIColor colorWithRed:0.6 green:1 blue:0.6 alpha:1];
        gLabel.font = [UIFont monospacedSystemFontOfSize:10
                                                  weight:UIFontWeightRegular];
        [gScroll addSubview:gLabel];

        UIPanGestureRecognizer *pan = [[UIPanGestureRecognizer alloc]
            initWithTarget:self action:@selector(onDragBox:)];
        pan.cancelsTouchesInView = NO;
        [bar addGestureRecognizer:pan];

        gLink = [CADisplayLink displayLinkWithTarget:self
                                            selector:@selector(flushTick)];
        [gLink addToRunLoop:[NSRunLoop mainRunLoop]
                    forMode:NSRunLoopCommonModes];

        DBG(@"=== DebugConsole ready ===");
    });
}

+ (void)flushTick {
    NSTimeInterval now = CACurrentMediaTime();
    if (now - gLastFlush < 0.15) return;

    BOOL dirty;
    NSArray *snap = nil;
    os_unfair_lock_lock(&gLk);
    dirty = gDirty;
    gDirty = NO;
    if (dirty) snap = [gBuf copy];
    os_unfair_lock_unlock(&gLk);

    if (!dirty || !gLabel) return;
    gLastFlush = now;

    NSMutableString *ms = [NSMutableString string];
    NSInteger start = MAX(0, (NSInteger)snap.count - 80);
    for (NSInteger i = start; i < (NSInteger)snap.count; i++) {
        [ms appendString:snap[i]];
        [ms appendString:@"\n"];
    }
    gLabel.text = ms;
    [gLabel sizeToFit];
    CGFloat bh = gLabel.bounds.size.height + 8;
    gLabel.frame = CGRectMake(4, 4, gScroll.bounds.size.width - 8, bh);
    gScroll.contentSize = CGSizeMake(gScroll.bounds.size.width, bh + 8);
    if (bh > gScroll.bounds.size.height) {
        [gScroll setContentOffset:
            CGPointMake(0, bh - gScroll.bounds.size.height + 8) animated:NO];
    }
}

+ (void)onDragBox:(UIPanGestureRecognizer *)g {
    if (!gBox) return;
    CGPoint t = [g translationInView:gBox.superview];
    if (g.state == UIGestureRecognizerStateBegan ||
        g.state == UIGestureRecognizerStateChanged) {
        gBox.center = CGPointMake(gBox.center.x + t.x, gBox.center.y + t.y);
        [g setTranslation:CGPointZero inView:gBox.superview];
    }
}

+ (void)onCopy {
    os_unfair_lock_lock(&gLk);
    NSArray *snap = [gBuf copy];
    os_unfair_lock_unlock(&gLk);
    NSString *all = [snap componentsJoinedByString:@"\n"];
    [UIPasteboard generalPasteboard].string = all;
    DBG(@"copied %lu lines", (unsigned long)snap.count);
}

+ (void)onClear {
    os_unfair_lock_lock(&gLk);
    [gBuf removeAllObjects];
    gDirty = YES;
    os_unfair_lock_unlock(&gLk);
}

+ (void)onFold {
    gCollapsed = !gCollapsed;
    CGFloat bh = gCollapsed ? 28 : 220;
    CGRect f = gBox.frame;
    f.size.height = bh;
    gBox.frame = f;
    gScroll.frame = CGRectMake(0, 28, f.size.width, bh - 28);
}

@end