#import "Input.h"
#import "Common.h"
#import <objc/runtime.h>
#import <os/lock.h>

@implementation InputState {
    os_unfair_lock _lk;
    float _x, _y;
    NSMutableDictionary<NSString *, NSNumber *> *_pressed;
}

+ (instancetype)shared {
    static InputState *s;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ s = [InputState new]; });
    return s;
}
- (instancetype)init {
    if (self = [super init]) {
        _lk = OS_UNFAIR_LOCK_INIT;
        _pressed = [NSMutableDictionary dictionary];
    }
    return self;
}

- (void)setStickX:(float)x y:(float)y {
    os_unfair_lock_lock(&_lk);
    _x = x; _y = y;
    os_unfair_lock_unlock(&_lk);
}

- (void)snapshotStickX:(float *)x y:(float *)y {
    os_unfair_lock_lock(&_lk);
    if (x) *x = _x;
    if (y) *y = _y;
    os_unfair_lock_unlock(&_lk);
}

- (void)effectiveStickX:(float *)x y:(float *)y {
    os_unfair_lock_lock(&_lk);
    float bx = _x;
    float by = _y;
    if ([_pressed[@"dpadUp"] boolValue])    by += 1.0f;
    if ([_pressed[@"dpadDown"] boolValue])  by -= 1.0f;
    if ([_pressed[@"dpadLeft"] boolValue])  bx -= 1.0f;
    if ([_pressed[@"dpadRight"] boolValue]) bx += 1.0f;
    os_unfair_lock_unlock(&_lk);

    if (bx >  1.0f) bx =  1.0f;
    if (bx < -1.0f) bx = -1.0f;
    if (by >  1.0f) by =  1.0f;
    if (by < -1.0f) by = -1.0f;

    if (x) *x = bx;
    if (y) *y = by;
}

- (void)setElement:(NSString *)eid pressed:(BOOL)pressed {
    if (![eid isKindOfClass:[NSString class]] || !eid.length) return;
    os_unfair_lock_lock(&_lk);
    _pressed[eid] = @(pressed);
    os_unfair_lock_unlock(&_lk);
}
- (BOOL)isElementPressed:(NSString *)eid {
    if (![eid isKindOfClass:[NSString class]] || !eid.length) return NO;
    os_unfair_lock_lock(&_lk);
    BOOL p = [_pressed[eid] boolValue];
    os_unfair_lock_unlock(&_lk);
    return p;
}
- (void)toggleElement:(NSString *)eid {
    if (![eid isKindOfClass:[NSString class]] || !eid.length) return;
    os_unfair_lock_lock(&_lk);
    BOOL cur = [_pressed[eid] boolValue];
    _pressed[eid] = @(!cur);
    os_unfair_lock_unlock(&_lk);
}
- (void)reset {
    os_unfair_lock_lock(&_lk);
    _x = _y = 0;
    [_pressed removeAllObjects];
    os_unfair_lock_unlock(&_lk);
}
@end

static GCExtendedGamepad *g_pad = nil;
static NSMapTable *g_map = nil;
static float (*g_origBtn)(id, SEL) = NULL;
static float (*g_origAxis)(id, SEL) = NULL;

static float hookBtn(id self, SEL _cmd) {
    if (!g_pad || !g_map || !g_origBtn)
        return g_origBtn ? g_origBtn(self, _cmd) : 0.0f;
    NSString *n = [g_map objectForKey:self];
    if (!n) return g_origBtn(self, _cmd);
    return [[InputState shared] isElementPressed:n] ? 1.0f : 0.0f;
}
static float hookAxis(id self, SEL _cmd) {
    if (!g_pad || !g_pad.leftThumbstick || !g_origAxis)
        return g_origAxis ? g_origAxis(self, _cmd) : 0.0f;
    float x, y;
    [[InputState shared] effectiveStickX:&x y:&y];
    if (self == g_pad.leftThumbstick.xAxis) return x;
    if (self == g_pad.leftThumbstick.yAxis) return y;
    return g_origAxis(self, _cmd);
}

@implementation Input

+ (void)installHook {
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        Method m1 = class_getInstanceMethod([GCControllerButtonInput class], @selector(value));
        if (m1) {
            IMP cur = method_getImplementation(m1);
            if (cur != (IMP)hookBtn) {
                g_origBtn = (float(*)(id,SEL))cur;
                method_setImplementation(m1, (IMP)hookBtn);
            }
        }
        Method m2 = class_getInstanceMethod([GCControllerAxisInput class], @selector(value));
        if (m2) {
            IMP cur = method_getImplementation(m2);
            if (cur != (IMP)hookAxis) {
                g_origAxis = (float(*)(id,SEL))cur;
                method_setImplementation(m2, (IMP)hookAxis);
            }
        }
    });
}

+ (void)bindPad:(GCExtendedGamepad *)pad {
    g_pad = pad;
    if (!pad) { g_map = nil; return; }
    NSMapTable *m = [NSMapTable strongToStrongObjectsMapTable];
#define MAP(key, btn) if (btn) [m setObject:key forKey:(id)btn]
    MAP(@"buttonA", pad.buttonA);
    MAP(@"buttonB", pad.buttonB);
    MAP(@"buttonX", pad.buttonX);
    MAP(@"buttonY", pad.buttonY);
    MAP(@"leftShoulder", pad.leftShoulder);
    MAP(@"rightShoulder", pad.rightShoulder);
    MAP(@"leftTrigger", pad.leftTrigger);
    MAP(@"rightTrigger", pad.rightTrigger);
    MAP(@"buttonMenu", pad.buttonMenu);
    MAP(@"buttonOptions", pad.buttonOptions);
    if (@available(iOS 13.0, *)) MAP(@"buttonHome", pad.buttonHome);
    if (pad.dpad) {
        MAP(@"dpadUp", pad.dpad.up);
        MAP(@"dpadDown", pad.dpad.down);
        MAP(@"dpadLeft", pad.dpad.left);
        MAP(@"dpadRight", pad.dpad.right);
    }
#undef MAP
    g_map = m;
}

@end