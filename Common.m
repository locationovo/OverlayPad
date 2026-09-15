#import "Common.h"
#import <os/lock.h>
#import <unistd.h>

NSArray<UIColor *> *Palette(void) {
    static NSArray *a;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        a = @[
            [UIColor colorWithRed:0.95 green:0.30 blue:0.35 alpha:1],
            [UIColor colorWithRed:0.98 green:0.60 blue:0.20 alpha:1],
            [UIColor colorWithRed:0.95 green:0.82 blue:0.25 alpha:1],
            [UIColor colorWithRed:0.35 green:0.78 blue:0.45 alpha:1],
            [UIColor colorWithRed:0.25 green:0.60 blue:0.95 alpha:1],
            [UIColor colorWithRed:0.65 green:0.42 blue:0.95 alpha:1],
            [UIColor colorWithWhite:0.92 alpha:1],
            [UIColor colorWithWhite:0.35 alpha:1],
        ];
    });
    return a;
}

NSArray<NSString *> *GamepadElements(void) {
    static NSArray *a;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        a = @[
            @"buttonA", @"buttonB", @"buttonX", @"buttonY",
            @"leftShoulder", @"rightShoulder",
            @"leftTrigger", @"rightTrigger",
            @"dpadUp", @"dpadDown", @"dpadLeft", @"dpadRight",
            @"buttonMenu", @"buttonOptions", @"buttonHome",
        ];
    });
    return a;
}

NSString *ElementLabel(NSString *eid) {
    if (![eid isKindOfClass:[NSString class]] || !eid.length) return @"?";
    static NSDictionary *m;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        m = @{
            @"buttonA": @"A", @"buttonB": @"B",
            @"buttonX": @"X", @"buttonY": @"Y",
            @"leftShoulder": @"LB", @"rightShoulder": @"RB",
            @"leftTrigger": @"LT", @"rightTrigger": @"RT",
            @"dpadUp": @"UP", @"dpadDown": @"DN",
            @"dpadLeft": @"LF", @"dpadRight": @"RT",
            @"buttonMenu": @"MN", @"buttonOptions": @"OP",
            @"buttonHome": @"HM",
        };
    });
    return m[eid] ?: eid;
}

UIColor *ColorFromHex(NSString *hex) {
    if (![hex isKindOfClass:[NSString class]]) return nil;
    NSString *s = [hex stringByTrimmingCharactersInSet:
        [NSCharacterSet whitespaceCharacterSet]];
    if ([s hasPrefix:@"#"]) s = [s substringFromIndex:1];
    if (s.length == 3) {
        unichar c0 = [s characterAtIndex:0];
        unichar c1 = [s characterAtIndex:1];
        unichar c2 = [s characterAtIndex:2];
        s = [NSString stringWithFormat:@"%c%c%c%c%c%c", c0, c0, c1, c1, c2, c2];
    }
    if (s.length != 6 && s.length != 8) return nil;
    unsigned int v = 0;
    NSScanner *sc = [NSScanner scannerWithString:s];
    if (![sc scanHexInt:&v]) return nil;
    CGFloat r, g, b, a = 1.0;
    if (s.length == 6) {
        r = ((v >> 16) & 0xFF) / 255.0;
        g = ((v >> 8) & 0xFF) / 255.0;
        b = (v & 0xFF) / 255.0;
    } else {
        r = ((v >> 24) & 0xFF) / 255.0;
        g = ((v >> 16) & 0xFF) / 255.0;
        b = ((v >> 8) & 0xFF) / 255.0;
        a = (v & 0xFF) / 255.0;
    }
    return [UIColor colorWithRed:r green:g blue:b alpha:a];
}

NSString *HexFromColor(UIColor *c) {
    if (!c) return @"#FFFFFF";
    CGFloat r, g, b, a;
    if (![c getRed:&r green:&g blue:&b alpha:&a]) {
        CGFloat w;
        if ([c getWhite:&w alpha:&a]) r = g = b = w;
        else return @"#FFFFFF";
    }
    return [NSString stringWithFormat:@"#%02X%02X%02X",
        (int)round(r * 255), (int)round(g * 255), (int)round(b * 255)];
}

UIColor *PanelBg(void) {
    if (@available(iOS 13.0, *)) return [UIColor secondarySystemBackgroundColor];
    return [UIColor colorWithWhite:0.96 alpha:1];
}
UIColor *PanelBarBg(void) {
    if (@available(iOS 13.0, *)) return [UIColor tertiarySystemBackgroundColor];
    return [UIColor colorWithWhite:0.90 alpha:1];
}
UIColor *PanelText(void) {
    if (@available(iOS 13.0, *)) return [UIColor labelColor];
    return [UIColor blackColor];
}
UIColor *PanelSubText(void) {
    if (@available(iOS 13.0, *)) return [UIColor secondaryLabelColor];
    return [UIColor darkGrayColor];
}
UIColor *PanelFieldBg(void) {
    if (@available(iOS 13.0, *)) return [UIColor systemGray5Color];
    return [UIColor colorWithWhite:0.90 alpha:1];
}
UIColor *PanelAccent(void) {
    if (@available(iOS 13.0, *)) return [UIColor systemBlueColor];
    return [UIColor colorWithRed:0.20 green:0.50 blue:1.0 alpha:1];
}
UIColor *PanelBorder(void) {
    if (@available(iOS 13.0, *)) return [UIColor separatorColor];
    return [UIColor colorWithWhite:0.5 alpha:0.3];
}

UIButton *PanelIconButton(NSString *sfName, NSString *fallback) {
    static UIImageSymbolConfiguration *symCfg = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        if (@available(iOS 13.0, *)) {
            symCfg = [UIImageSymbolConfiguration
                configurationWithPointSize:13
                                    weight:UIImageSymbolWeightSemibold];
        }
    });
    UIButton *b = [UIButton buttonWithType:UIButtonTypeSystem];
    if (@available(iOS 13.0, *)) {
        UIImage *img = sfName
            ? [UIImage systemImageNamed:sfName withConfiguration:symCfg]
            : nil;
        if (img) [b setImage:img forState:UIControlStateNormal];
        else if (fallback) [b setTitle:fallback forState:UIControlStateNormal];
    } else if (fallback) {
        [b setTitle:fallback forState:UIControlStateNormal];
    }
    b.tintColor = PanelSubText();
    [b setTitleColor:PanelSubText() forState:UIControlStateNormal];
    b.titleLabel.font = [UIFont boldSystemFontOfSize:14];
    b.backgroundColor = PanelFieldBg();
    b.layer.cornerRadius = 14;
    return b;
}

#if DEBUG
static NSString *gPath = nil;
static os_unfair_lock gLk = OS_UNFAIR_LOCK_INIT;

static void initPath(void) {
    if (gPath) return;
    gPath = @"/tmp/joystick.log";
    remove(gPath.UTF8String);
}

void JoyLog(NSString *fmt, ...) {
    os_unfair_lock_lock(&gLk);
    initPath();
    os_unfair_lock_unlock(&gLk);
    va_list ap;
    va_start(ap, fmt);
    NSString *s = [[NSString alloc] initWithFormat:fmt arguments:ap];
    va_end(ap);
    static NSDateFormatter *df;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        df = [NSDateFormatter new];
        df.dateFormat = @"HH:mm:ss.SSS";
    });
    NSString *line = [NSString stringWithFormat:@"%@ %@\n",
                      [df stringFromDate:[NSDate date]], s];
    os_unfair_lock_lock(&gLk);
    FILE *f = fopen(gPath.UTF8String, "a");
    if (f) { fputs(line.UTF8String, f); fclose(f); }
    os_unfair_lock_unlock(&gLk);
    NSLog(@"[joy] %@", s);
}
#endif