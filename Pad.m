#import "Pad.h"
#import "Common.h"
#import "Input.h"
#import "Style.h"
#import "DebugConsole.h"
#import <math.h>

static CGFloat cl(CGFloat v, CGFloat lo, CGFloat hi) {
    return v < lo ? lo : (v > hi ? hi : v);
}
static NSInteger idxMod(NSInteger i, NSInteger n) {
    if (n <= 0) return 0;
    return ((i % n) + n) % n;
}

static UIView *sHost = nil;
static UIView *sJoy, *sThumb;
static NSMutableDictionary<NSString *, UIButton *> *sBtnMap;
static BOOL sEditing = NO;

static CADisplayLink *sRapidLink = nil;
static NSMutableArray<NSString *> *sRapidOrder = nil;
static NSMutableDictionary<NSString *, NSNumber *> *sRapidNext = nil;
static NSMutableDictionary<NSString *, NSNumber *> *sRapidPeriod = nil;

@implementation Pad

+ (void)buildIn:(UIView *)host {
    sHost = host;
    sBtnMap = [NSMutableDictionary dictionary];
    sRapidOrder = [NSMutableArray array];
    sRapidNext = [NSMutableDictionary dictionary];
    sRapidPeriod = [NSMutableDictionary dictionary];
    Settings *st = [Settings shared];
    host.multipleTouchEnabled = YES;
    host.exclusiveTouch = NO;
    sJoy = [[UIView alloc] initWithFrame:CGRectMake(0, 0, st.joySize, st.joySize)];
    sJoy.userInteractionEnabled = YES;
    sJoy.multipleTouchEnabled = YES;
    sJoy.exclusiveTouch = NO;
    [host addSubview:sJoy];
    sThumb = [[UIView alloc] init];
    sThumb.userInteractionEnabled = NO;
    [sJoy addSubview:sThumb];
    UIPanGestureRecognizer *jPan = [[UIPanGestureRecognizer alloc]
        initWithTarget:self action:@selector(onJoy:)];
    jPan.cancelsTouchesInView = NO;
    [sJoy addGestureRecognizer:jPan];
    UILongPressGestureRecognizer *jLp = [[UILongPressGestureRecognizer alloc]
        initWithTarget:self action:@selector(onJoyLongPress:)];
    jLp.minimumPressDuration = 0.6;
    jLp.allowableMovement = 12;
    jLp.cancelsTouchesInView = NO;
    [sJoy addGestureRecognizer:jLp];
    [self rebuild];
}

+ (void)rebuild {
    [self stopAllRapid];
    for (UIButton *b in sBtnMap.allValues) [b removeFromSuperview];
    [sBtnMap removeAllObjects];
    for (BtnCfg *cfg in [Settings shared].buttons) {
        UIButton *b = [self makeButton:cfg];
        sBtnMap[cfg.eid] = b;
        [sHost addSubview:b];
    }
    [self apply];
}

+ (UIButton *)makeButton:(BtnCfg *)cfg {
    UIButton *b = [UIButton buttonWithType:UIButtonTypeCustom];
    b.accessibilityIdentifier = cfg.eid;
    b.userInteractionEnabled = YES;
    b.multipleTouchEnabled = YES;
    b.exclusiveTouch = NO;
    b.clipsToBounds = NO;
    b.backgroundColor = [UIColor clearColor];

    UIView *visual = [[UIView alloc] init];
    visual.tag = 9001;
    visual.userInteractionEnabled = NO;
    visual.clipsToBounds = NO;
    [b addSubview:visual];

    UILabel *label = [[UILabel alloc] init];
    label.tag = 9002;
    label.textAlignment = NSTextAlignmentCenter;
    label.font = [UIFont boldSystemFontOfSize:16];
    label.adjustsFontSizeToFitWidth = YES;
    label.minimumScaleFactor = 0.5;
    label.userInteractionEnabled = NO;
    [visual addSubview:label];

    UIPanGestureRecognizer *pan = [[UIPanGestureRecognizer alloc]
        initWithTarget:self action:@selector(onDrag:)];
    pan.enabled = sEditing;
    pan.cancelsTouchesInView = NO;
    [b addGestureRecognizer:pan];

    UILongPressGestureRecognizer *lp = [[UILongPressGestureRecognizer alloc]
        initWithTarget:self action:@selector(onLongPress:)];
    lp.minimumPressDuration = 0.6;
    lp.allowableMovement = 12;
    lp.cancelsTouchesInView = NO;
    [b addGestureRecognizer:lp];

    [b addTarget:self action:@selector(onDown:) forControlEvents:UIControlEventTouchDown];
    [b addTarget:self action:@selector(onUp:) forControlEvents:
        UIControlEventTouchUpInside | UIControlEventTouchUpOutside | UIControlEventTouchCancel];
    return b;
}

+ (BtnCfg *)cfgForButton:(UIButton *)btn {
    if (!btn) return nil;
    NSString *eid = btn.accessibilityIdentifier;
    if (!eid) return nil;
    for (BtnCfg *b in [Settings shared].buttons) {
        if ([b.eid isEqualToString:eid]) return b;
    }
    return nil;
}

+ (void)apply {
    Settings *st = [Settings shared];
    if (!st) return;
    UIColor *jc = [st joyUIColor];
    NSArray<UIColor *> *pal = [st allColors];

    [CATransaction begin];
    [CATransaction setDisableActions:YES];

    sJoy.bounds = CGRectMake(0, 0, st.joySize, st.joySize);
    sJoy.center = st.joyPos;
    sJoy.layer.cornerRadius = st.joySize / 2;
    CGFloat tr = st.joySize * 0.45;
    sThumb.bounds = CGRectMake(0, 0, tr, tr);
    sThumb.center = CGPointMake(st.joySize / 2, st.joySize / 2);
    sThumb.layer.cornerRadius = tr / 2;
    [Skin applyJoy:st.joyStyle base:sJoy thumb:sThumb color:jc alpha:st.joyAlpha];

    for (BtnCfg *cfg in st.buttons) {
        UIButton *b = sBtnMap[cfg.eid];
        if (!b) continue;
        UIView *visual = [b viewWithTag:9001];
        UILabel *label = (UILabel *)[b viewWithTag:9002];
        if (!visual || !label) continue;

        UIColor *bc = pal[idxMod(cfg.color, pal.count)];

        b.bounds = CGRectMake(0, 0, cfg.size, cfg.size);
        b.center = cfg.pos;
        b.layer.transform = CATransform3DIdentity;

        visual.transform = CGAffineTransformIdentity;
        visual.frame = b.bounds;
        visual.layer.cornerRadius = (cfg.shape == BtnShapeCircle) ? cfg.size / 2 : 12;
        label.frame = visual.bounds;
        label.text = cfg.displayText;

        [Skin applyBtn:cfg.style visual:visual label:label color:bc alpha:cfg.alpha];
    }

    [CATransaction commit];
}

+ (void)applyStyle:(BtnCfg *)cfg btn:(UIButton *)b pressed:(BOOL)pressed {
    UIView *visual = [b viewWithTag:9001];
    UILabel *label = (UILabel *)[b viewWithTag:9002];
    if (!visual || !label) return;

    Settings *st = [Settings shared];
    NSArray *pal = [st allColors];

    UIColor *bc;
    CGAffineTransform xf;
    CGFloat corner;
    NSString *title;
    CGFloat alpha;

    if (pressed) {
        CGFloat scale = 1.0;
        if (cfg.size > 1.0) scale = cfg.pSize / cfg.size;
        if (scale > 1.4) scale = 1.4;
        if (scale < 0.5) scale = 0.5;
        xf = CGAffineTransformMakeScale(scale, scale);
        corner = (cfg.pShape == BtnShapeCircle) ? cfg.size / 2 : 12;
        title = cfg.pressedText;
        bc = pal[idxMod(cfg.pColor, pal.count)];
        alpha = cfg.pAlpha;
    } else {
        xf = CGAffineTransformIdentity;
        corner = (cfg.shape == BtnShapeCircle) ? cfg.size / 2 : 12;
        title = cfg.displayText;
        bc = pal[idxMod(cfg.color, pal.count)];
        alpha = cfg.alpha;
    }

    [UIView animateWithDuration:0.08
                          delay:0
                        options:UIViewAnimationOptionBeginFromCurrentState |
                                UIViewAnimationOptionAllowUserInteraction |
                                UIViewAnimationOptionCurveEaseOut
                     animations:^{
        visual.transform = xf;
        visual.layer.cornerRadius = corner;
        label.text = title;
        [Skin applyBtn:cfg.style visual:visual label:label color:bc alpha:alpha];
    } completion:nil];
}

+ (void)setEditing:(BOOL)editing {
    sEditing = editing;
    for (UIButton *b in sBtnMap.allValues) {
        for (UIGestureRecognizer *g in b.gestureRecognizers) {
            if ([g isKindOfClass:[UIPanGestureRecognizer class]]) g.enabled = editing;
        }
    }
    if (!editing) {
        Settings *st = [Settings shared];
        st.joyPos = sJoy.center;
        for (BtnCfg *cfg in st.buttons) {
            UIButton *b = sBtnMap[cfg.eid];
            if (b) cfg.pos = b.center;
        }
        [st save];
    }
}

+ (void)setVisible:(BOOL)visible {
    sJoy.hidden = !visible;
    for (UIButton *b in sBtnMap.allValues) b.hidden = !visible;
}

+ (void)resetPositions {
    Settings *st = [Settings shared];
    [st resetPositions];
    [st save];
    sJoy.center = st.joyPos;
    for (BtnCfg *cfg in st.buttons) {
        UIButton *b = sBtnMap[cfg.eid];
        if (b) b.center = cfg.pos;
    }
}

+ (BOOL)owns:(UIView *)v {
    if (!v) return NO;
    if ([v isDescendantOfView:sJoy]) return YES;
    for (UIButton *b in sBtnMap.allValues)
        if ([v isDescendantOfView:b]) return YES;
    return NO;
}

+ (void)onJoyLongPress:(UILongPressGestureRecognizer *)g {
    if (!sEditing || g.state != UIGestureRecognizerStateBegan) return;
    [[NSNotificationCenter defaultCenter]
        postNotificationName:@"JoyEditJoy" object:nil];
}

+ (void)onJoy:(UIPanGestureRecognizer *)g {
    Settings *st = [Settings shared];
    CGFloat r = st.joySize / 2;

    if (sEditing) {
        CGPoint t = [g translationInView:sJoy.superview];
        if (g.state == UIGestureRecognizerStateBegan ||
            g.state == UIGestureRecognizerStateChanged) {
            sJoy.center = CGPointMake(sJoy.center.x + t.x, sJoy.center.y + t.y);
            [g setTranslation:CGPointZero inView:sJoy.superview];
        } else if (g.state == UIGestureRecognizerStateEnded) {
            [self clamp:sJoy];
            st.joyPos = sJoy.center;
            [st save];
        }
        return;
    }

    CGPoint loc = [g locationInView:sJoy];
    CGFloat maxR = r * 0.72;
    if (g.state == UIGestureRecognizerStateBegan ||
        g.state == UIGestureRecognizerStateChanged) {
        CGFloat dx = loc.x - r, dy = loc.y - r;
        CGFloat d = sqrt(dx*dx + dy*dy);
        if (d > maxR && d > 0.01) { CGFloat s = maxR / d; dx *= s; dy *= s; }
        sThumb.center = CGPointMake(r + dx, r + dy);
        CGFloat nx = dx / maxR, ny = -dy / maxR;
        CGFloat mag = sqrt(nx*nx + ny*ny);
        CGFloat dead = cl(st.joyDeadzone, 0, 0.5);
        CGFloat curve = cl(st.joyCurve, 0.3, 3.0);
        if (mag < dead) {
            nx = ny = 0;
        } else {
            CGFloat t = (mag - dead) / (1.0 - dead);
            if (t > 1) t = 1;
            t = pow(t, curve);
            nx = (nx / mag) * t;
            ny = (ny / mag) * t;
        }
        [[InputState shared] setStickX:(float)nx y:(float)ny];
    } else if (g.state == UIGestureRecognizerStateEnded ||
               g.state == UIGestureRecognizerStateCancelled) {
        [UIView animateWithDuration:0.12 animations:^{
            sThumb.center = CGPointMake(r, r);
        }];
        [[InputState shared] setStickX:0 y:0];
    }
}

+ (void)onDrag:(UIPanGestureRecognizer *)g {
    if (!sEditing) return;
    UIView *v = g.view;
    CGPoint t = [g translationInView:v.superview];
    if (g.state == UIGestureRecognizerStateBegan ||
        g.state == UIGestureRecognizerStateChanged) {
        v.center = CGPointMake(v.center.x + t.x, v.center.y + t.y);
        [g setTranslation:CGPointZero inView:v.superview];
    } else if (g.state == UIGestureRecognizerStateEnded) {
        [self clamp:v];
        BtnCfg *cfg = [self cfgForButton:(UIButton *)v];
        if (cfg) { cfg.pos = v.center; [[Settings shared] save]; }
    }
}

+ (void)onLongPress:(UILongPressGestureRecognizer *)g {
    if (!sEditing || g.state != UIGestureRecognizerStateBegan) return;
    BtnCfg *cfg = [self cfgForButton:(UIButton *)g.view];
    if (!cfg) return;
    [[NSNotificationCenter defaultCenter]
        postNotificationName:@"JoyEditButton"
        object:nil userInfo:@{@"eid": cfg.eid}];
}

+ (void)clamp:(UIView *)v {
    if (!v) return;
    CGRect sc = [UIScreen mainScreen].bounds;
    CGRect f = v.frame;
    CGFloat m = 8;
    if (f.origin.x < m) f.origin.x = m;
    if (f.origin.y < m) f.origin.y = m;
    if (CGRectGetMaxX(f) > sc.size.width - m)
        f.origin.x = sc.size.width - m - f.size.width;
    if (CGRectGetMaxY(f) > sc.size.height - m)
        f.origin.y = sc.size.height - m - f.size.height;
    v.frame = f;
}

+ (NSArray *)rapidKeys:(BtnCfg *)cfg {
    return cfg.rapidKeys.count ? cfg.rapidKeys : cfg.elements;
}

+ (void)startRapid:(BtnCfg *)cfg {
    if (!cfg) return;
    if (!sRapidNext) {
        sRapidOrder = [NSMutableArray array];
        sRapidNext = [NSMutableDictionary dictionary];
        sRapidPeriod = [NSMutableDictionary dictionary];
    }
    if (sRapidNext[cfg.eid]) return;
    NSArray *keys = [self rapidKeys:cfg];
    if (!keys.count) return;
    CGFloat half = MAX(0.01, cfg.rapidInterval / 2.0);
    sRapidPeriod[cfg.eid] = @(half);
    sRapidNext[cfg.eid] = @(CACurrentMediaTime() + half);
    if (![sRapidOrder containsObject:cfg.eid])
        [sRapidOrder addObject:cfg.eid];
    if (!sRapidLink) {
        sRapidLink = [CADisplayLink displayLinkWithTarget:self
                                                 selector:@selector(rapidTick)];
        [sRapidLink addToRunLoop:[NSRunLoop mainRunLoop]
                        forMode:NSRunLoopCommonModes];
    }
}

+ (void)rapidTick {
    if (!sRapidOrder.count) {
        if (sRapidLink) { [sRapidLink invalidate]; sRapidLink = nil; }
        return;
    }
    NSTimeInterval now = CACurrentMediaTime();
    NSArray *order = [sRapidOrder copy];
    Settings *st = [Settings shared];
    for (NSString *eid in order) {
        NSNumber *next = sRapidNext[eid];
        NSNumber *period = sRapidPeriod[eid];
        if (!next || !period) continue;
        if (now < next.doubleValue) continue;
        BtnCfg *cfg = nil;
        for (BtnCfg *b in st.buttons) {
            if ([b.eid isEqualToString:eid]) { cfg = b; break; }
        }
        if (!cfg) {
            [sRapidNext removeObjectForKey:eid];
            [sRapidPeriod removeObjectForKey:eid];
            [sRapidOrder removeObject:eid];
            continue;
        }
        for (NSString *k in [self rapidKeys:cfg])
            [[InputState shared] toggleElement:k];
        sRapidNext[eid] = @(next.doubleValue + period.doubleValue);
    }
}

+ (void)stopRapid:(BtnCfg *)cfg {
    if (!cfg || !sRapidNext) return;
    [sRapidNext removeObjectForKey:cfg.eid];
    [sRapidPeriod removeObjectForKey:cfg.eid];
    [sRapidOrder removeObject:cfg.eid];
    for (NSString *k in [self rapidKeys:cfg])
        [[InputState shared] setElement:k pressed:NO];
    if (!sRapidOrder.count && sRapidLink) {
        [sRapidLink invalidate];
        sRapidLink = nil;
    }
}

+ (void)stopAllRapid {
    if (!sRapidOrder) return;
    NSArray *order = [sRapidOrder copy];
    for (NSString *eid in order) {
        BtnCfg *cfg = nil;
        for (BtnCfg *b in [Settings shared].buttons) {
            if ([b.eid isEqualToString:eid]) { cfg = b; break; }
        }
        if (cfg) {
            for (NSString *k in [self rapidKeys:cfg])
                [[InputState shared] setElement:k pressed:NO];
        }
    }
    [sRapidOrder removeAllObjects];
    [sRapidNext removeAllObjects];
    [sRapidPeriod removeAllObjects];
    if (sRapidLink) { [sRapidLink invalidate]; sRapidLink = nil; }
}

+ (void)onDown:(UIButton *)b {
    if (sEditing) return;
    BtnCfg *cfg = [self cfgForButton:b];
    if (!cfg) return;

    NSArray *elems = cfg.elements.count ? cfg.elements : @[@"buttonA"];

    if (cfg.rapidFire) {
        for (NSString *e in elems)
            [[InputState shared] setElement:e pressed:YES];
        [self startRapid:cfg];
    } else if (cfg.turbo) {
        for (NSString *e in elems) [[InputState shared] toggleElement:e];
    } else {
        for (NSString *e in elems) [[InputState shared] setElement:e pressed:YES];
    }

    if (cfg.hasPressed) {
        [self applyStyle:cfg btn:b pressed:YES];
    } else {
        UIView *visual = [b viewWithTag:9001];
        if (visual) {
            [UIView animateWithDuration:0.08
                                  delay:0
                                options:UIViewAnimationOptionBeginFromCurrentState |
                                        UIViewAnimationOptionAllowUserInteraction
                             animations:^{ visual.alpha = 0.75; }
                             completion:nil];
        }
    }
}

+ (void)onUp:(UIButton *)b {
    if (sEditing) return;
    BtnCfg *cfg = [self cfgForButton:b];
    if (!cfg) return;

    if (cfg.rapidFire) {
        [self stopRapid:cfg];
    } else if (!cfg.turbo) {
        NSArray *elems = cfg.elements.count ? cfg.elements : @[@"buttonA"];
        for (NSString *e in elems) [[InputState shared] setElement:e pressed:NO];
    }

    if (cfg.hasPressed) {
        [self applyStyle:cfg btn:b pressed:NO];
    } else {
        UIView *visual = [b viewWithTag:9001];
        if (visual) {
            [UIView animateWithDuration:0.08
                                  delay:0
                                options:UIViewAnimationOptionBeginFromCurrentState |
                                        UIViewAnimationOptionAllowUserInteraction
                             animations:^{ visual.alpha = 1.0; }
                             completion:nil];
        }
    }
}

@end