#import "Style.h"
#import "DebugConsole.h"

extern void SkinReg1(void);
extern void SkinReg2(void);

static NSMutableDictionary<NSNumber *, Skin *> *gJoy = nil;
static NSMutableDictionary<NSNumber *, Skin *> *gBtn = nil;
static NSMutableDictionary<NSNumber *, JoyStyleBlock> *gJoyBlock = nil;
static NSMutableDictionary<NSNumber *, BtnStyleBlock> *gBtnBlock = nil;

@implementation Skin

+ (void)ensureInit {
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        gJoy = [NSMutableDictionary dictionary];
        gBtn = [NSMutableDictionary dictionary];
        gJoyBlock = [NSMutableDictionary dictionary];
        gBtnBlock = [NSMutableDictionary dictionary];
    });
}

+ (void)registerJoy:(NSInteger)idx en:(NSString *)en zh:(NSString *)zh block:(JoyStyleBlock)b {
    [self ensureInit];
    Skin *s = [Skin new];
    s.idx = idx; s.en = en; s.zh = zh;
    gJoy[@(idx)] = s;
    if (b) gJoyBlock[@(idx)] = [b copy];
}

+ (void)registerBtn:(NSInteger)idx en:(NSString *)en zh:(NSString *)zh block:(BtnStyleBlock)b {
    [self ensureInit];
    Skin *s = [Skin new];
    s.idx = idx; s.en = en; s.zh = zh;
    gBtn[@(idx)] = s;
    if (b) gBtnBlock[@(idx)] = [b copy];
}

+ (NSArray<Skin *> *)sorted:(NSDictionary *)d {
    NSArray *keys = [[d allKeys] sortedArrayUsingSelector:@selector(compare:)];
    NSMutableArray *a = [NSMutableArray array];
    for (NSNumber *k in keys) [a addObject:d[k]];
    return a;
}

+ (NSArray<Skin *> *)joyStyles { [self ensureInit]; return [self sorted:gJoy]; }
+ (NSArray<Skin *> *)btnStyles { [self ensureInit]; return [self sorted:gBtn]; }

+ (Skin *)joyStyleBy:(NSInteger)idx {
    [self ensureInit];
    Skin *s = gJoy[@(idx)];
    if (s) return s;
    NSArray *keys = [[gJoy allKeys] sortedArrayUsingSelector:@selector(compare:)];
    if (keys.count) return gJoy[keys.firstObject];
    return nil;
}
+ (Skin *)btnStyleBy:(NSInteger)idx {
    [self ensureInit];
    Skin *s = gBtn[@(idx)];
    if (s) return s;
    NSArray *keys = [[gBtn allKeys] sortedArrayUsingSelector:@selector(compare:)];
    if (keys.count) return gBtn[keys.firstObject];
    return nil;
}

+ (void)applyJoy:(NSInteger)idx base:(UIView *)base thumb:(UIView *)thumb
           color:(UIColor *)color alpha:(CGFloat)alpha {
    if (!base || !thumb || !color) return;
    [self ensureInit];
    JoyStyleBlock b = gJoyBlock[@(idx)];
    if (!b) {
        NSArray *ks = [[gJoyBlock allKeys] sortedArrayUsingSelector:@selector(compare:)];
        if (ks.count) b = gJoyBlock[ks.firstObject];
    }
    if (b) b(base, thumb, color, alpha);
}

+ (void)applyBtn:(NSInteger)idx visual:(UIView *)visual label:(UILabel *)label
           color:(UIColor *)color alpha:(CGFloat)alpha {
    if (!visual || !color) return;
    [self ensureInit];
    BtnStyleBlock b = gBtnBlock[@(idx)];
    if (!b) {
        NSArray *ks = [[gBtnBlock allKeys] sortedArrayUsingSelector:@selector(compare:)];
        if (ks.count) b = gBtnBlock[ks.firstObject];
    }
    if (b) b(visual, label, color, alpha);
}

@end

void SkinRegAll(void) {
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        SkinReg1();
        SkinReg2();
    });
}