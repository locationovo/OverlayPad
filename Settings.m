#import "Settings.h"

static NSArray<NSString *> *strArr(id v) {
    if ([v isKindOfClass:[NSArray class]]) {
        NSMutableArray *a = [NSMutableArray array];
        for (id x in v) if ([x isKindOfClass:[NSString class]]) [a addObject:x];
        if (a.count) return a;
    }
    if ([v isKindOfClass:[NSString class]] && [v length]) return @[v];
    return nil;
}

static CGFloat cl(CGFloat v, CGFloat lo, CGFloat hi) {
    return v < lo ? lo : (v > hi ? hi : v);
}

static NSInteger idxMod(NSInteger i, NSInteger n) {
    if (n <= 0) return 0;
    return ((i % n) + n) % n;
}

@implementation BtnCfg

+ (instancetype)fromDict:(NSDictionary *)d {
    BtnCfg *b = [BtnCfg new];
    if (![d isKindOfClass:[NSDictionary class]]) {
        b.eid = [[NSUUID UUID] UUIDString];
        b.pos = CGPointMake(240, 560);
        b.size = 64; b.alpha = 0.85; b.color = 6; b.shape = 0;
        b.text = @""; b.elements = @[@"buttonA"];
        b.turbo = NO; b.rapidFire = NO;
        b.rapidInterval = 0.10; b.rapidKeys = @[];
        b.style = 1;
        b.hasPressed = NO;
        b.pSize = 64; b.pAlpha = 0.6; b.pColor = 6;
        b.pShape = 1; b.pText = @"";
        return b;
    }

    b.eid = [d[@"eid"] isKindOfClass:[NSString class]]
        ? d[@"eid"] : [[NSUUID UUID] UUIDString];

    NSString *ps = d[@"pos"];
    b.pos = [ps isKindOfClass:[NSString class]]
        ? CGPointFromString(ps) : CGPointMake(240, 560);

    NSNumber *n;
    n = d[@"size"];  b.size  = [n isKindOfClass:[NSNumber class]] ? cl(n.floatValue, 40, 140) : 64;
    n = d[@"alpha"]; b.alpha = [n isKindOfClass:[NSNumber class]] ? cl(n.floatValue, 0.15, 1.0) : 0.85;
    n = d[@"color"]; b.color = [n isKindOfClass:[NSNumber class]] ? MAX(0, n.integerValue) : 6;
    n = d[@"shape"]; b.shape = [n isKindOfClass:[NSNumber class]] ? n.integerValue : 0;
    n = d[@"style"]; b.style = [n isKindOfClass:[NSNumber class]] ? MAX(1, n.integerValue) : 1;
    n = d[@"rapidInterval"];
    b.rapidInterval = [n isKindOfClass:[NSNumber class]] ? cl(n.floatValue, 0.02, 1.0) : 0.10;

    b.text = [d[@"text"] isKindOfClass:[NSString class]] ? d[@"text"] : @"";
    b.turbo = [d[@"turbo"] boolValue];
    b.rapidFire = [d[@"rapidFire"] boolValue];

    NSArray *es = strArr(d[@"elements"]) ?: strArr(d[@"element"]);
    b.elements = es ?: @[@"buttonA"];

    NSArray *rk = strArr(d[@"rapidKeys"]);
    b.rapidKeys = rk ?: @[];

    b.hasPressed = [d[@"hasPressed"] boolValue];
    n = d[@"pSize"];  b.pSize  = [n isKindOfClass:[NSNumber class]] ? cl(n.floatValue, 40, 140) : b.size;
    n = d[@"pAlpha"]; b.pAlpha = [n isKindOfClass:[NSNumber class]] ? cl(n.floatValue, 0.15, 1.0) : 0.6;
    n = d[@"pColor"]; b.pColor = [n isKindOfClass:[NSNumber class]] ? MAX(0, n.integerValue) : b.color;
    n = d[@"pShape"]; b.pShape = [n isKindOfClass:[NSNumber class]] ? n.integerValue : b.shape;
    b.pText = [d[@"pText"] isKindOfClass:[NSString class]] ? d[@"pText"] : @"";

    return b;
}

- (NSDictionary *)toDict {
    return @{
        @"eid": self.eid ?: @"",
        @"pos": NSStringFromCGPoint(self.pos),
        @"size": @(self.size),
        @"alpha": @(self.alpha),
        @"color": @(self.color),
        @"shape": @(self.shape),
        @"text": self.text ?: @"",
        @"elements": self.elements ?: @[],
        @"turbo": @(self.turbo),
        @"rapidFire": @(self.rapidFire),
        @"rapidInterval": @(self.rapidInterval),
        @"rapidKeys": self.rapidKeys ?: @[],
        @"style": @(self.style),
        @"hasPressed": @(self.hasPressed),
        @"pSize": @(self.pSize),
        @"pAlpha": @(self.pAlpha),
        @"pColor": @(self.pColor),
        @"pShape": @(self.pShape),
        @"pText": self.pText ?: @"",
    };
}

- (NSString *)displayText {
    if (self.text.length) return self.text;
    if (self.elements.count) {
        NSMutableArray *p = [NSMutableArray array];
        for (NSString *e in self.elements) [p addObject:ElementLabel(e)];
        return [p componentsJoinedByString:@"+"];
    }
    return @"?";
}

- (NSString *)pressedText {
    if (self.pText.length) return self.pText;
    return self.displayText;
}

@end

@implementation Settings

+ (instancetype)shared {
    static Settings *s;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ s = [Settings new]; [s load]; });
    return s;
}

- (instancetype)init {
    if (self = [super init]) {
        _joySize = 140; _joyAlpha = 0.85; _joyColor = 7;
        _joyPos = CGPointMake(120, 460);
        _joyDeadzone = 0.10;
        _joyCurve = 1.15;
        _joyStyle = 1;
        _ballPos = CGPointMake(60, 160);
        _panelPos = CGPointMake(0, 0);
        _hudState = HUDStateBall;
        _hidden = NO;
        _langMode = LangAuto;
        _customColors = [NSMutableArray array];
        _buttons = [NSMutableArray array];

        NSArray *elems = @[@"buttonA", @"buttonB", @"buttonX"];
        CGFloat x = 240;
        for (NSString *e in elems) {
            BtnCfg *b = [BtnCfg new];
            b.eid = [[NSUUID UUID] UUIDString];
            b.pos = CGPointMake(x, 560); x += 80;
            b.size = 64; b.alpha = 0.85;
            b.color = 6; b.shape = BtnShapeCircle;
            b.text = @"";
            b.elements = @[e];
            b.turbo = NO; b.rapidFire = NO;
            b.rapidInterval = 0.10; b.rapidKeys = @[];
            b.style = 1;
            b.hasPressed = NO;
            b.pSize = 64; b.pAlpha = 0.6; b.pColor = 6;
            b.pShape = BtnShapeCircle; b.pText = @"";
            [_buttons addObject:b];
        }
    }
    return self;
}

- (void)setLangMode:(LangMode)m { _langMode = m; LangSetMode(m); }

- (void)load {
    NSUserDefaults *d = [NSUserDefaults standardUserDefaults];

#define LN(n, key, get) { NSNumber *v = [d objectForKey:key]; \
    if ([v isKindOfClass:[NSNumber class]]) _##n = [v get]; }
    LN(joySize, @"joySize", floatValue);
    LN(joyAlpha, @"joyAlpha", floatValue);
    LN(joyColor, @"joyColor", integerValue);
    LN(joyDeadzone, @"joyDeadzone", floatValue);
    LN(joyCurve, @"joyCurve", floatValue);
    LN(joyStyle, @"joyStyle", integerValue);
    LN(hudState, @"hudState", integerValue);
    LN(hidden, @"hidden", boolValue);
    LN(langMode, @"langMode", integerValue);
#undef LN

#define LP(n, key) { NSString *s = [d objectForKey:key]; \
    if ([s isKindOfClass:[NSString class]]) _##n = CGPointFromString(s); }
    LP(joyPos, @"joyPos");
    LP(ballPos, @"ballPos");
    LP(panelPos, @"panelPos");
#undef LP

    _joyDeadzone = cl(_joyDeadzone, 0, 0.5);
    _joyCurve = cl(_joyCurve, 0.3, 3.0);
    if (_joyStyle < 1) _joyStyle = 1;
    if (_joyColor < 0) _joyColor = 0;

    NSArray *cc = [d objectForKey:@"customColors"];
    if ([cc isKindOfClass:[NSArray class]]) {
        _customColors = [NSMutableArray array];
        for (id x in cc) if ([x isKindOfClass:[NSString class]])
            [_customColors addObject:x];
    }

    NSArray *arr = [d objectForKey:@"buttons"];
    if ([arr isKindOfClass:[NSArray class]] && arr.count > 0) {
        _buttons = [NSMutableArray array];
        for (NSDictionary *dd in arr) {
            BtnCfg *b = [BtnCfg fromDict:dd];
            if (b) [_buttons addObject:b];
        }
    }

    LangSetMode(_langMode);
}

- (void)save {
    NSUserDefaults *d = [NSUserDefaults standardUserDefaults];
    @try {
        [d setObject:@(_joySize) forKey:@"joySize"];
        [d setObject:@(_joyAlpha) forKey:@"joyAlpha"];
        [d setObject:@(_joyColor) forKey:@"joyColor"];
        [d setObject:@(_joyDeadzone) forKey:@"joyDeadzone"];
        [d setObject:@(_joyCurve) forKey:@"joyCurve"];
        [d setObject:@(_joyStyle) forKey:@"joyStyle"];
        [d setObject:@(_hudState) forKey:@"hudState"];
        [d setObject:@(_hidden) forKey:@"hidden"];
        [d setObject:@(_langMode) forKey:@"langMode"];
        [d setObject:NSStringFromCGPoint(_joyPos) forKey:@"joyPos"];
        [d setObject:NSStringFromCGPoint(_ballPos) forKey:@"ballPos"];
        [d setObject:NSStringFromCGPoint(_panelPos) forKey:@"panelPos"];
        [d setObject:_customColors forKey:@"customColors"];

        NSMutableArray *arr = [NSMutableArray array];
        for (BtnCfg *b in _buttons) [arr addObject:[b toDict]];
        [d setObject:arr forKey:@"buttons"];
    } @catch (NSException *e) { LOG(@"save EX: %@", e); }
}

- (UIColor *)joyUIColor {
    NSArray *p = [self allColors];
    return p[idxMod(_joyColor, p.count)];
}
- (UIColor *)btnUIColorFor:(NSInteger)idx {
    NSArray *p = [self allColors];
    return p[idxMod(idx, p.count)];
}
- (NSArray<UIColor *> *)allColors {
    NSMutableArray *a = [NSMutableArray arrayWithArray:Palette()];
    for (NSString *hex in _customColors) {
        UIColor *c = ColorFromHex(hex);
        [a addObject:c ?: [UIColor grayColor]];
    }
    return a;
}
- (NSInteger)addCustomColor:(NSString *)hex {
    if (!hex) return -1;
    UIColor *c = ColorFromHex(hex);
    if (!c) return -1;
    [_customColors addObject:HexFromColor(c)];
    return Palette().count + _customColors.count - 1;
}

- (BtnCfg *)addButton {
    BtnCfg *b = [BtnCfg new];
    b.eid = [[NSUUID UUID] UUIDString];
    b.pos = CGPointMake(240 + arc4random_uniform(100),
                        460 + arc4random_uniform(80));
    b.size = 64; b.alpha = 0.85; b.color = 6;
    b.shape = BtnShapeCircle;
    b.text = @"";
    b.elements = @[@"buttonA"];
    b.turbo = NO; b.rapidFire = NO;
    b.rapidInterval = 0.10; b.rapidKeys = @[];
    b.style = 1;
    b.hasPressed = NO;
    b.pSize = 64; b.pAlpha = 0.6; b.pColor = 6;
    b.pShape = BtnShapeCircle; b.pText = @"";
    [_buttons addObject:b];
    return b;
}
- (void)removeButton:(BtnCfg *)b {
    if (b) [_buttons removeObject:b];
}

- (void)resetPositions {
    _joyPos = CGPointMake(120, 460);
    _ballPos = CGPointMake(60, 160);
    _panelPos = CGPointMake(0, 0);
    CGFloat x = 240;
    for (BtnCfg *b in _buttons) { b.pos = CGPointMake(x, 560); x += 80; }
}

- (void)resetAll {
    NSUserDefaults *d = [NSUserDefaults standardUserDefaults];
    for (NSString *k in @[@"joySize",@"joyAlpha",@"joyColor",@"joyPos",
                          @"joyDeadzone",@"joyCurve",@"joyStyle",
                          @"ballPos",@"panelPos",@"hudState",@"hidden",
                          @"buttons",@"langMode",@"customColors"]) {
        [d removeObjectForKey:k];
    }
    [d synchronize];

    Settings *def = [Settings new];
    _joySize = def.joySize; _joyAlpha = def.joyAlpha; _joyColor = def.joyColor;
    _joyDeadzone = def.joyDeadzone; _joyCurve = def.joyCurve;
    _joyStyle = def.joyStyle;
    _joyPos = def.joyPos; _ballPos = def.ballPos; _panelPos = def.panelPos;
    _hudState = def.hudState;
    _hidden = def.hidden;
    _langMode = def.langMode; LangSetMode(_langMode);
    _customColors = def.customColors;
    _buttons = def.buttons;
}

- (NSDictionary *)exportDict {
    NSMutableArray *arr = [NSMutableArray array];
    for (BtnCfg *b in _buttons) [arr addObject:[b toDict]];
    return @{
        @"joySize":     @(_joySize),
        @"joyAlpha":    @(_joyAlpha),
        @"joyColor":    @(_joyColor),
        @"joyDeadzone": @(_joyDeadzone),
        @"joyCurve":    @(_joyCurve),
        @"joyStyle":    @(_joyStyle),
        @"joyPos":      NSStringFromCGPoint(_joyPos),
        @"ballPos":     NSStringFromCGPoint(_ballPos),
        @"panelPos":    NSStringFromCGPoint(_panelPos),
        @"hudState":    @(_hudState),
        @"hidden":      @(_hidden),
        @"langMode":    @(_langMode),
        @"customColors": _customColors ?: @[],
        @"buttons":     arr,
    };
}

- (BOOL)importDict:(NSDictionary *)d {
    if (![d isKindOfClass:[NSDictionary class]]) return NO;

    NSNumber *n;
    n = d[@"joySize"];  if ([n isKindOfClass:[NSNumber class]]) _joySize  = cl(n.floatValue, 60, 260);
    n = d[@"joyAlpha"]; if ([n isKindOfClass:[NSNumber class]]) _joyAlpha = cl(n.floatValue, 0.15, 1.0);
    n = d[@"joyColor"]; if ([n isKindOfClass:[NSNumber class]]) _joyColor = MAX(0, n.integerValue);
    n = d[@"joyDeadzone"]; if ([n isKindOfClass:[NSNumber class]]) _joyDeadzone = cl(n.floatValue, 0, 0.5);
    n = d[@"joyCurve"];    if ([n isKindOfClass:[NSNumber class]]) _joyCurve    = cl(n.floatValue, 0.3, 3.0);
    n = d[@"joyStyle"];    if ([n isKindOfClass:[NSNumber class]]) _joyStyle    = MAX(1, n.integerValue);
    n = d[@"hudState"];    if ([n isKindOfClass:[NSNumber class]]) _hudState    = n.integerValue;
    n = d[@"hidden"];      if ([n isKindOfClass:[NSNumber class]]) _hidden      = n.boolValue;
    n = d[@"langMode"];    if ([n isKindOfClass:[NSNumber class]]) _langMode    = n.integerValue;

    NSString *s;
    s = d[@"joyPos"];   if ([s isKindOfClass:[NSString class]]) _joyPos   = CGPointFromString(s);
    s = d[@"ballPos"];  if ([s isKindOfClass:[NSString class]]) _ballPos  = CGPointFromString(s);
    s = d[@"panelPos"]; if ([s isKindOfClass:[NSString class]]) _panelPos = CGPointFromString(s);

    NSArray *cc = d[@"customColors"];
    if ([cc isKindOfClass:[NSArray class]]) {
        NSMutableArray *out = [NSMutableArray array];
        for (id x in cc)
            if ([x isKindOfClass:[NSString class]]) [out addObject:x];
        _customColors = out;
    }

    NSArray *arr = d[@"buttons"];
    if ([arr isKindOfClass:[NSArray class]] && arr.count > 0) {
        NSMutableArray *out = [NSMutableArray array];
        for (NSDictionary *dd in arr) {
            BtnCfg *b = [BtnCfg fromDict:dd];
            if (b) [out addObject:b];
        }
        if (out.count > 0) _buttons = out;
    }

    LangSetMode(_langMode);
    return YES;
}

@end