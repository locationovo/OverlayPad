#import "About.h"
#import "AboutContent.h"
#import "Common.h"

#ifdef JOY_HAS_AVATAR
#include "avatar_data.h"
#endif

@implementation About

+ (void)showIn:(UIView *)host {
    if (!host) return;
    if ([host viewWithTag:7777]) return;

    NSArray *lines = AboutLines();
    if (![lines isKindOfClass:[NSArray class]]) lines = @[];

    CGFloat w = MIN(340, host.bounds.size.width - 40);
    CGFloat barH = 44;
    CGFloat avSize = 90;
    CGFloat nameH = 30;
    CGFloat lineH = 44;
    CGFloat verH = 30;
    CGFloat padTop = 16;
    CGFloat padBottom = 24;

    CGFloat h = barH + padTop + avSize + nameH
              + lines.count * lineH + verH + padBottom;
    h = MIN(h, host.bounds.size.height - 100);
    h = MAX(h, barH + 60);

    UIView *p = [[UIView alloc] initWithFrame:CGRectMake(0, 0, w, h)];
    p.tag = 7777;
    p.center = CGPointMake(host.bounds.size.width / 2,
                           host.bounds.size.height / 2);
    p.backgroundColor = PanelBg();
    p.layer.cornerRadius = 18;
    p.layer.masksToBounds = YES;

    UIView *bar = [[UIView alloc] initWithFrame:CGRectMake(0, 0, w, barH)];
    bar.backgroundColor = PanelBarBg();
    bar.userInteractionEnabled = YES;
    [p addSubview:bar];

    UIPanGestureRecognizer *drag = [[UIPanGestureRecognizer alloc]
        initWithTarget:self action:@selector(onDrag:)];
    drag.cancelsTouchesInView = NO;
    [bar addGestureRecognizer:drag];

    UILabel *t = [[UILabel alloc] initWithFrame:
        CGRectMake(16, 0, w - 60, barH)];
    t.text = L(@"About", @"关于");
    t.textColor = PanelText();
    t.font = [UIFont boldSystemFontOfSize:16];
    [bar addSubview:t];

    UIButton *close = PanelIconButton(@"xmark", @"X");
    close.frame = CGRectMake(w - 42, 8, 28, 28);
    [close addTarget:self action:@selector(closePanel:)
        forControlEvents:UIControlEventTouchUpInside];
    [bar addSubview:close];

    CGFloat y = barH + padTop;

    UIView *avatar = [[UIView alloc] initWithFrame:
        CGRectMake((w - avSize) / 2, y, avSize, avSize)];
    avatar.layer.cornerRadius = avSize / 2;
    avatar.layer.masksToBounds = YES;
    avatar.backgroundColor = PanelFieldBg();
    avatar.layer.borderWidth = 1;
    avatar.layer.borderColor = PanelBorder().CGColor;

    UIImage *img = nil;
#ifdef JOY_HAS_AVATAR
    NSData *data = [[NSData alloc] initWithBase64EncodedString:
        [NSString stringWithUTF8String:g_avatar_b64]
        options:NSDataBase64DecodingIgnoreUnknownCharacters];
    if (data) img = [UIImage imageWithData:data];
#endif
    if (img) {
        UIImageView *iv = [[UIImageView alloc] initWithFrame:avatar.bounds];
        iv.image = img;
        iv.contentMode = UIViewContentModeScaleAspectFill;
        [avatar addSubview:iv];
    } else {
        UILabel *ph = [[UILabel alloc] initWithFrame:avatar.bounds];
        ph.text = @"?";
        ph.textAlignment = NSTextAlignmentCenter;
        ph.font = [UIFont boldSystemFontOfSize:44];
        ph.textColor = PanelSubText();
        [avatar addSubview:ph];
    }
    [p addSubview:avatar];
    y += avSize;

    UILabel *name = [[UILabel alloc] initWithFrame:
        CGRectMake(16, y, w - 32, nameH)];
    NSString *n = AboutName();
    name.text = [NSString stringWithFormat:@"@%@",
                 (n.length ? n : @"unknown")];
    name.textAlignment = NSTextAlignmentCenter;
    name.textColor = PanelText();
    name.font = [UIFont boldSystemFontOfSize:17];
    [p addSubview:name];
    y += nameH;

    for (NSDictionary *line in lines) {
        if (![line isKindOfClass:[NSDictionary class]]) continue;
        UILabel *lbl = [[UILabel alloc] initWithFrame:
            CGRectMake(20, y, w - 40, lineH - 4)];
        NSString *en = line[@"en"];
        NSString *zh = line[@"zh"];
        if (![en isKindOfClass:[NSString class]]) en = @"";
        if (![zh isKindOfClass:[NSString class]]) zh = en;
        lbl.text = L(en, zh);
        lbl.textAlignment = NSTextAlignmentCenter;
        lbl.numberOfLines = 0;
        lbl.textColor = PanelSubText();
        lbl.font = [UIFont systemFontOfSize:13];
        [p addSubview:lbl];
        y += lineH;
    }

    UILabel *ver = [[UILabel alloc] initWithFrame:
        CGRectMake(16, y, w - 32, verH)];
    ver.text = AboutVersion();
    ver.textAlignment = NSTextAlignmentCenter;
    ver.textColor = PanelSubText();
    ver.font = [UIFont monospacedDigitSystemFontOfSize:11
                weight:UIFontWeightMedium];
    ver.adjustsFontSizeToFitWidth = YES;
    ver.minimumScaleFactor = 0.6;
    [p addSubview:ver];

    [host addSubview:p];
}

+ (void)onDrag:(UIPanGestureRecognizer *)g {
    UIView *bar = g.view;
    UIView *p = bar.superview;
    if (!p) return;
    CGPoint t = [g translationInView:p.superview];
    if (g.state == UIGestureRecognizerStateBegan ||
        g.state == UIGestureRecognizerStateChanged) {
        p.center = CGPointMake(p.center.x + t.x, p.center.y + t.y);
        [g setTranslation:CGPointZero inView:p.superview];
    }
}

+ (void)closePanel:(UIButton *)b {
    if (!b) return;
    UIView *p = b.superview;
    while (p && p.tag != 7777) p = p.superview;
    [p removeFromSuperview];
}

@end