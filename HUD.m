#import "HUD.h"
#import "Common.h"
#import "Settings.h"
#import "Pad.h"
#import "About.h"
#import "Style.h"
#import "DebugConsole.h"
#import "Presets.h"
#import <objc/runtime.h>

static UIWindow *sWin;
static UIView *sBall, *sPanel, *sEditPanel;
static UIScrollView *sContent, *sEditContent;
static UILabel *sTitle, *sEditTitle;
static UIView *sDropBack = nil;
static UIView *sDropBox = nil;
static UILabel *sToast = nil;
static BOOL sEditing = NO;
static BOOL gHidden = NO;
static BtnCfg *gEditCfg = nil;
static BOOL gEditIsJoy = NO;
static BOOL gEditPressed = NO;
static CGPoint sEditPanelCenter = {0, 0};
static UIView *sPresetPanel = nil;
static UIScrollView *sPresetContent = nil;

@interface OverlayWindow : UIWindow
@end
@implementation OverlayWindow
- (UIView *)hitTest:(CGPoint)p withEvent:(UIEvent *)e {
    if (sWin.rootViewController.presentedViewController)
        return [super hitTest:p withEvent:e];
    UIView *hit = [super hitTest:p withEvent:e];
    if (!hit) return nil;
    if (hit == self.rootViewController.view) return nil;
    UIView *root = self.rootViewController.view;
    UIView *v = hit;
    UIView *panel = nil;
    while (v && v != root) {
        if (v == sPanel || v == sEditPanel || v == sPresetPanel || v.tag == 7777) {
            panel = v; break;
        }
        v = v.superview;
    }
    if (panel && panel.superview) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (panel.superview) [panel.superview bringSubviewToFront:panel];
        });
    }
    return hit;
}
@end

@implementation HUD

+ (BOOL)isEditing { return sEditing; }

+ (void)toast:(NSString *)msg {
    if (!sWin || !msg.length) return;
    [sToast removeFromSuperview];
    UIView *root = sWin.rootViewController.view;
    UILabel *l = [[UILabel alloc] init];
    l.text = msg;
    l.textColor = [UIColor whiteColor];
    l.font = [UIFont systemFontOfSize:13 weight:UIFontWeightMedium];
    l.textAlignment = NSTextAlignmentCenter;
    l.numberOfLines = 0;
    l.backgroundColor = [UIColor colorWithRed:0.15 green:0.62 blue:0.58 alpha:0.95];
    l.layer.cornerRadius = 10;
    l.layer.masksToBounds = YES;
    l.alpha = 0;
    [root addSubview:l];
    sToast = l;
    CGSize maxSz = CGSizeMake(root.bounds.size.width - 80, 200);
    CGRect rect = [msg boundingRectWithSize:maxSz
        options:NSStringDrawingUsesLineFragmentOrigin
        attributes:@{NSFontAttributeName: l.font} context:nil];
    CGFloat tw = MIN(maxSz.width, rect.size.width + 32);
    CGFloat th = MAX(36, rect.size.height + 20);
    l.bounds = CGRectMake(0, 0, tw, th);
    l.center = CGPointMake(root.bounds.size.width / 2,
                           root.bounds.size.height - 80);
    [UIView animateWithDuration:0.15 animations:^{ l.alpha = 1; }
        completion:^(BOOL ok) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW,
            (int64_t)(1.6 * NSEC_PER_SEC)),
            dispatch_get_main_queue(), ^{
            [UIView animateWithDuration:0.2 animations:^{ l.alpha = 0; }
                completion:^(BOOL ok2) {
                [l removeFromSuperview];
                if (sToast == l) sToast = nil;
            }];
        });
    }];
}

+ (void)shake:(UIView *)v {
    if (!v) return;
    CAKeyframeAnimation *a = [CAKeyframeAnimation animationWithKeyPath:@"transform.translation.x"];
    a.values = @[@0, @-8, @8, @-6, @6, @-3, @3, @0];
    a.duration = 0.4;
    [v.layer addAnimation:a forKey:@"shake"];
    UIColor *orig = v.backgroundColor;
    v.backgroundColor = [UIColor colorWithRed:1 green:0.6 blue:0.6 alpha:1];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW,
        (int64_t)(0.4 * NSEC_PER_SEC)),
        dispatch_get_main_queue(), ^{ v.backgroundColor = orig; });
}

+ (void)setup {
    Settings *st = [Settings shared];
    CGRect scr = [UIScreen mainScreen].bounds;
    sWin = [[OverlayWindow alloc] initWithFrame:scr];
    sWin.windowLevel = UIWindowLevelNormal + 1;
    sWin.backgroundColor = [UIColor clearColor];
    sWin.rootViewController = [UIViewController new];
    sWin.hidden = NO;
    UIView *root = sWin.rootViewController.view;
    root.multipleTouchEnabled = YES;
    root.exclusiveTouch = NO;

    [[Presets shared] applyActive];
    [Pad buildIn:root];
    [self buildPanel];
    [root addSubview:sPanel];

    sBall = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 56, 56)];
    sBall.backgroundColor = [UIColor colorWithWhite:0.10 alpha:0.92];
    sBall.layer.cornerRadius = 28;
    sBall.layer.shadowColor = [UIColor blackColor].CGColor;
    sBall.layer.shadowRadius = 8;
    sBall.layer.shadowOpacity = 0.4;
    sBall.layer.shadowOffset = CGSizeMake(0, 3);
    sBall.userInteractionEnabled = YES;
    [root addSubview:sBall];
    UIImageView *icon = [[UIImageView alloc] initWithFrame:sBall.bounds];
    if (@available(iOS 13.0, *))
        icon.image = [UIImage systemImageNamed:@"slider.horizontal.3"];
    icon.tintColor = [UIColor whiteColor];
    icon.contentMode = UIViewContentModeCenter;
    [sBall addSubview:icon];
    UIPanGestureRecognizer *bp = [[UIPanGestureRecognizer alloc]
        initWithTarget:self action:@selector(onBallPan:)];
    bp.cancelsTouchesInView = NO;
    [sBall addGestureRecognizer:bp];
    UITapGestureRecognizer *bt = [[UITapGestureRecognizer alloc]
        initWithTarget:self action:@selector(onBallTap:)];
    [sBall addGestureRecognizer:bt];
    UILongPressGestureRecognizer *bl = [[UILongPressGestureRecognizer alloc]
        initWithTarget:self action:@selector(onBallLong:)];
    bl.minimumPressDuration = 0.7;
    bl.allowableMovement = 15;
    bl.cancelsTouchesInView = NO;
    [sBall addGestureRecognizer:bl];
    sBall.center = st.ballPos;
    [self clampBall];
    gHidden = st.hidden;
    [[NSNotificationCenter defaultCenter] addObserver:self
        selector:@selector(onRotate)
        name:UIDeviceOrientationDidChangeNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
        selector:@selector(onEditButton:)
        name:@"JoyEditButton" object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
        selector:@selector(onEditJoy:)
        name:@"JoyEditJoy" object:nil];
    [self applyAll];
}

+ (void)buildPanel {
    sPanel = [[UIView alloc] init];
    sPanel.backgroundColor = PanelBg();
    sPanel.layer.cornerRadius = 18;
    sPanel.layer.masksToBounds = YES;
    sPanel.hidden = YES;
    UIView *bar = [[UIView alloc] init];
    bar.backgroundColor = PanelBarBg();
    bar.tag = 100;
    bar.userInteractionEnabled = YES;
    [sPanel addSubview:bar];
    UIPanGestureRecognizer *pd = [[UIPanGestureRecognizer alloc]
        initWithTarget:self action:@selector(onPanelDrag:)];
    pd.cancelsTouchesInView = NO;
    [bar addGestureRecognizer:pd];
    sTitle = [[UILabel alloc] init];
    sTitle.text = L(@"Settings", @"设置");
    sTitle.textColor = PanelText();
    sTitle.font = [UIFont boldSystemFontOfSize:16];
    [bar addSubview:sTitle];
    UIButton *minBtn = PanelIconButton(@"minus", @"-");
    minBtn.tag = 101;
    [bar addSubview:minBtn];
    UIButton *maxBtn = PanelIconButton(@"arrow.up.left.and.arrow.down.right", @"+");
    maxBtn.tag = 102;
    [bar addSubview:maxBtn];
    [minBtn addTarget:self action:@selector(onMin)
        forControlEvents:UIControlEventTouchUpInside];
    [maxBtn addTarget:self action:@selector(onMax)
        forControlEvents:UIControlEventTouchUpInside];
    sContent = [[UIScrollView alloc] init];
    sContent.tag = 200;
    sContent.alwaysBounceVertical = YES;
    sContent.showsVerticalScrollIndicator = NO;
    [sPanel addSubview:sContent];
    [self buildRows];
}

+ (NSArray *)menuSpec {
    return @[
        @{ @"title": L(@"Language", @"语言"), @"action": @"lang" },
        @{ @"title": L(@"Presets", @"预设"), @"action": @"presets" },
        @{ @"title": L(@"Add Button", @"添加按键"), @"action": @"addBtn" },
        @{ @"title": L(@"Reset Pos", @"重置位置"), @"action": @"resetPos" },
        @{ @"title": L(@"Reset All", @"重置全部"), @"action": @"resetAll" },
        @{ @"title": L(@"About", @"关于"), @"action": @"about" },
    ];
}

+ (void)buildRows {
    for (UIView *v in sContent.subviews) [v removeFromSuperview];
    Settings *st = [Settings shared];
    NSArray *spec = [self menuSpec];
    CGFloat y = 12;
    CGFloat w = sPanel.bounds.size.width;
    if (w < 100) w = 320;
    for (NSDictionary *item in spec) {
        UIView *row = [[UIView alloc] initWithFrame:CGRectMake(0, y, w, 56)];
        UILabel *title = [[UILabel alloc] init];
        title.text = item[@"title"];
        title.textColor = PanelSubText();
        title.font = [UIFont systemFontOfSize:13];
        title.tag = 301;
        [row addSubview:title];
        UIButton *btn = [UIButton buttonWithType:UIButtonTypeSystem];
        btn.tag = 306;
        NSString *act = item[@"action"];
        NSString *label = [act isEqualToString:@"lang"]
            ? LangName(st.langMode) : L(@"GO", @"执行");
        [btn setTitle:label forState:UIControlStateNormal];
        [btn setTitleColor:PanelText() forState:UIControlStateNormal];
        btn.backgroundColor = PanelFieldBg();
        btn.titleLabel.font = [UIFont systemFontOfSize:14];
        btn.layer.cornerRadius = 8;
        objc_setAssociatedObject(btn, "act", act, OBJC_ASSOCIATION_COPY);
        [btn addTarget:self action:@selector(onAction:)
            forControlEvents:UIControlEventTouchUpInside];
        [row addSubview:btn];
        [sContent addSubview:row];
        y += 60;
    }
    sContent.contentSize = CGSizeMake(w, y + 12);
}

+ (void)confirm:(NSString *)title action:(void (^)(void))action {
    UIAlertController *ac = [UIAlertController
        alertControllerWithTitle:title message:nil
        preferredStyle:UIAlertControllerStyleAlert];
    [ac addAction:[UIAlertAction actionWithTitle:L(@"Cancel", @"取消")
        style:UIAlertActionStyleCancel handler:nil]];
    [ac addAction:[UIAlertAction actionWithTitle:L(@"Confirm", @"确认")
        style:UIAlertActionStyleDestructive handler:^(UIAlertAction *a) {
            if (action) action();
        }]];
    ac.popoverPresentationController.sourceView = sPanel;
    ac.popoverPresentationController.sourceRect = sPanel.bounds;
    [sWin.rootViewController presentViewController:ac animated:YES completion:nil];
}

+ (void)onAction:(UIButton *)b {
    NSString *act = objc_getAssociatedObject(b, "act");
    Settings *st = [Settings shared];
    if ([act isEqualToString:@"lang"]) {
        [self showLangPicker];
    } else if ([act isEqualToString:@"presets"]) {
        [self showPresetPanel];
    } else if ([act isEqualToString:@"addBtn"]) {
        [st addButton];
        [st save];
        [[Presets shared] syncCurrent];
        [Pad rebuild];
        [self buildRows];
        [self layoutPanel];
        [self toast:L(@"Button added", @"已添加按键")];
    } else if ([act isEqualToString:@"resetPos"]) {
        [self confirm:L(@"Reset positions?", @"重置位置？") action:^{
            [st resetPositions];
            [st save];
            [[Presets shared] syncCurrent];
            [Pad resetPositions];
            [self toast:L(@"Positions reset", @"位置已重置")];
        }];
    } else if ([act isEqualToString:@"resetAll"]) {
        [self confirm:L(@"Reset all settings?", @"重置全部设置？") action:^{
            [st resetAll];
            [Pad rebuild];
            [Pad resetPositions];
            [self buildRows];
            [self layoutPanel];
            [[Presets shared] syncCurrent];
            [self toast:L(@"All reset", @"已恢复默认")];
        }];
    } else if ([act isEqualToString:@"about"]) {
        [About showIn:sWin.rootViewController.view];
    }
}

+ (void)showLangPicker {
    UIAlertController *ac = [UIAlertController
        alertControllerWithTitle:L(@"Language", @"语言")
        message:nil preferredStyle:UIAlertControllerStyleActionSheet];
    Settings *st = [Settings shared];
    for (NSInteger i = 0; i < 3; i++) {
        NSString *title = LangName(i);
        [ac addAction:[UIAlertAction actionWithTitle:title
            style:UIAlertActionStyleDefault handler:^(UIAlertAction *a) {
                st.langMode = (LangMode)i;
                [st save];
                [[Presets shared] syncCurrent];
                sTitle.text = L(@"Settings", @"设置");
                [self buildRows];
                [self layoutPanel];
                if (sEditPanel) [self closeEditPanel];
            }]];
    }
    [ac addAction:[UIAlertAction actionWithTitle:L(@"Cancel", @"取消")
        style:UIAlertActionStyleCancel handler:nil]];
    ac.popoverPresentationController.sourceView = sPanel;
    ac.popoverPresentationController.sourceRect = sPanel.bounds;
    [sWin.rootViewController presentViewController:ac animated:YES completion:nil];
}

+ (void)onPanelDrag:(UIPanGestureRecognizer *)g {
    UIView *panel = g.view.superview;
    if (!panel) return;
    CGPoint t = [g translationInView:panel.superview];
    if (g.state == UIGestureRecognizerStateBegan ||
        g.state == UIGestureRecognizerStateChanged) {
        panel.center = CGPointMake(panel.center.x + t.x, panel.center.y + t.y);
        [g setTranslation:CGPointZero inView:panel.superview];
    } else if (g.state == UIGestureRecognizerStateEnded) {
        Settings *st = [Settings shared];
        CGRect scr = [UIScreen mainScreen].bounds;
        st.panelPos = CGPointMake(panel.center.x - scr.size.width / 2,
                                  panel.center.y - scr.size.height / 2);
        [st save];
    }
}

+ (void)onEditButton:(NSNotification *)n {
    NSString *eid = n.userInfo[@"eid"];
    if (![eid isKindOfClass:[NSString class]]) return;
    BtnCfg *cfg = nil;
    for (BtnCfg *b in [Settings shared].buttons) {
        if ([b.eid isEqualToString:eid]) { cfg = b; break; }
    }
    if (!cfg) return;
    gEditCfg = cfg;
    gEditIsJoy = NO;
    gEditPressed = NO;
    [self showEditPanel];
}

+ (void)onEditJoy:(NSNotification *)n {
    gEditCfg = nil;
    gEditIsJoy = YES;
    gEditPressed = NO;
    [self showEditPanel];
}

+ (void)cleanupEditUI {
    [self hideDropdown];
    [sEditPanel removeFromSuperview];
    sEditPanel = nil;
    sEditContent = nil;
}

+ (void)closeEditPanel {
    [self cleanupEditUI];
    gEditCfg = nil;
    gEditIsJoy = NO;
    gEditPressed = NO;
    [[Presets shared] syncCurrent];
}

+ (void)showEditPanel {
    [self cleanupEditUI];
    CGRect scr = [UIScreen mainScreen].bounds;
    CGFloat w = MIN(360, scr.size.width - 40);
    CGFloat h = MIN(620, scr.size.height - 100);
    if (sEditPanelCenter.x == 0 && sEditPanelCenter.y == 0) {
        sEditPanelCenter = CGPointMake(scr.size.width / 2, scr.size.height / 2);
    }
    sEditPanel = [[UIView alloc] initWithFrame:CGRectMake(0, 0, w, h)];
    sEditPanel.center = sEditPanelCenter;
    sEditPanel.backgroundColor = PanelBg();
    sEditPanel.layer.cornerRadius = 18;
    sEditPanel.layer.masksToBounds = YES;
    [sWin.rootViewController.view addSubview:sEditPanel];
    UIView *bar = [[UIView alloc] initWithFrame:CGRectMake(0, 0, w, 44)];
    bar.backgroundColor = PanelBarBg();
    bar.tag = 901;
    bar.userInteractionEnabled = YES;
    [sEditPanel addSubview:bar];
    UIPanGestureRecognizer *ed = [[UIPanGestureRecognizer alloc]
        initWithTarget:self action:@selector(onEditPanelDrag:)];
    ed.cancelsTouchesInView = NO;
    [bar addGestureRecognizer:ed];
    sEditTitle = [[UILabel alloc] initWithFrame:CGRectMake(16, 0, w - 60, 44)];
    sEditTitle.tag = 902;
    sEditTitle.text = gEditIsJoy
        ? L(@"Joystick", @"摇杆") : L(@"Button Props", @"按键属性");
    sEditTitle.textColor = PanelText();
    sEditTitle.font = [UIFont boldSystemFontOfSize:16];
    [bar addSubview:sEditTitle];
    UIButton *close = PanelIconButton(@"xmark", @"X");
    close.tag = 903;
    close.frame = CGRectMake(w - 42, 8, 28, 28);
    [close addTarget:self action:@selector(closeEditPanel)
        forControlEvents:UIControlEventTouchUpInside];
    [bar addSubview:close];
    CGFloat topY = 44;
    if (!gEditIsJoy && gEditCfg) {
        UISegmentedControl *tab = [[UISegmentedControl alloc]
            initWithItems:@[L(@"Normal", @"正常"), L(@"Pressed", @"按下")]];
        tab.tag = 910;
        tab.frame = CGRectMake(16, 50, w - 32, 30);
        tab.selectedSegmentIndex = gEditPressed ? 1 : 0;
        [tab addTarget:self action:@selector(onEditTab:)
            forControlEvents:UIControlEventValueChanged];
        [sEditPanel addSubview:tab];
        topY = 88;
    }
    sEditContent = [[UIScrollView alloc] initWithFrame:
        CGRectMake(0, topY, w, h - topY)];
    sEditContent.tag = 904;
    sEditContent.alwaysBounceVertical = YES;
    sEditContent.showsVerticalScrollIndicator = NO;
    [sEditPanel addSubview:sEditContent];
    [self buildEditRows];
}

+ (void)onEditTab:(UISegmentedControl *)sg {
    if (gEditIsJoy || !gEditCfg) return;
    gEditPressed = (sg.selectedSegmentIndex == 1);
    if (gEditPressed && !gEditCfg.hasPressed) {
        gEditCfg.hasPressed = YES;
        gEditCfg.pSize = gEditCfg.size;
        gEditCfg.pAlpha = MAX(0.15, gEditCfg.alpha * 0.7);
        gEditCfg.pColor = gEditCfg.color;
        gEditCfg.pShape = gEditCfg.shape;
        gEditCfg.pText = gEditCfg.text;
        [[Settings shared] save];
    }
    [self buildEditRows];
}

+ (void)onEditPanelDrag:(UIPanGestureRecognizer *)g {
    if (!sEditPanel) return;
    CGPoint t = [g translationInView:sEditPanel.superview];
    if (g.state == UIGestureRecognizerStateBegan ||
        g.state == UIGestureRecognizerStateChanged) {
        sEditPanel.center = CGPointMake(sEditPanel.center.x + t.x,
                                        sEditPanel.center.y + t.y);
        [g setTranslation:CGPointZero inView:sEditPanel.superview];
    } else if (g.state == UIGestureRecognizerStateEnded) {
        sEditPanelCenter = sEditPanel.center;
    }
}

+ (void)showDropdownAt:(UIView *)anchor
                 items:(NSArray<NSString *> *)items
               current:(NSInteger)cur
                onPick:(void (^)(NSInteger))cb {
    [self hideDropdown];
    if (!anchor || !items.count) return;
    UIView *root = sWin.rootViewController.view;
    CGRect af = [anchor convertRect:anchor.bounds toView:root];
    UIButton *back = [UIButton buttonWithType:UIButtonTypeCustom];
    back.frame = root.bounds;
    back.backgroundColor = [UIColor clearColor];
    [back addTarget:self action:@selector(hideDropdown)
        forControlEvents:UIControlEventTouchUpInside];
    [root addSubview:back];
    sDropBack = back;
    CGFloat rowH = 40;
    CGFloat dw = MAX(160, af.size.width);
    CGFloat dh = rowH * items.count;
    CGFloat dx = af.origin.x;
    CGFloat dy = af.origin.y + af.size.height + 4;
    if (dy + dh > root.bounds.size.height - 20) dy = af.origin.y - dh - 4;
    if (dx + dw > root.bounds.size.width - 12) dx = root.bounds.size.width - 12 - dw;
    if (dx < 12) dx = 12;
    if (dy < 12) dy = 12;
    UIView *box = [[UIView alloc] initWithFrame:CGRectMake(dx, dy, dw, dh)];
    box.backgroundColor = PanelBg();
    box.layer.cornerRadius = 12;
    box.layer.borderWidth = 1;
    box.layer.borderColor = PanelBorder().CGColor;
    box.layer.shadowColor = [UIColor blackColor].CGColor;
    box.layer.shadowRadius = 14;
    box.layer.shadowOpacity = 0.28;
    box.layer.shadowOffset = CGSizeMake(0, 6);
    box.layer.masksToBounds = NO;
    [root addSubview:box];
    sDropBox = box;
    for (NSInteger i = 0; i < (NSInteger)items.count; i++) {
        UIButton *r = [UIButton buttonWithType:UIButtonTypeSystem];
        r.frame = CGRectMake(0, i * rowH, dw, rowH);
        NSString *t = [@"   " stringByAppendingString:items[i]];
        [r setTitle:t forState:UIControlStateNormal];
        UIColor *tc = (i == cur) ? PanelAccent() : PanelText();
        [r setTitleColor:tc forState:UIControlStateNormal];
        r.titleLabel.font = [UIFont systemFontOfSize:14];
        r.contentHorizontalAlignment = UIControlContentHorizontalAlignmentLeft;
        r.tag = i;
        objc_setAssociatedObject(r, "cb", cb, OBJC_ASSOCIATION_COPY);
        [r addTarget:self action:@selector(onDropdownPick:)
            forControlEvents:UIControlEventTouchUpInside];
        [box addSubview:r];
        if (i > 0) {
            UIView *sep = [[UIView alloc] initWithFrame:
                CGRectMake(8, i * rowH, dw - 16, 0.5)];
            sep.backgroundColor = PanelBorder();
            [box addSubview:sep];
        }
    }
}

+ (void)hideDropdown {
    [sDropBox removeFromSuperview];
    [sDropBack removeFromSuperview];
    sDropBox = nil;
    sDropBack = nil;
}

+ (void)onDropdownPick:(UIButton *)b {
    void (^cb)(NSInteger) = objc_getAssociatedObject(b, "cb");
    NSInteger idx = b.tag;
    [self hideDropdown];
    if (cb) cb(idx);
}

+ (UIView *)rowWithLabel:(NSString *)title y:(CGFloat)y h:(CGFloat)h w:(CGFloat)w {
    UIView *row = [[UIView alloc] initWithFrame:CGRectMake(0, y, w, h)];
    UILabel *lbl = [[UILabel alloc] init];
    lbl.frame = CGRectMake(16, 4, w - 32, 18);
    lbl.text = title;
    lbl.textColor = PanelSubText();
    lbl.font = [UIFont systemFontOfSize:13];
    [row addSubview:lbl];
    return row;
}

+ (UIView *)makeSliderRow:(NSString *)title
                      key:(NSString *)key
                        min:(CGFloat)mn
                        max:(CGFloat)mx
                      value:(CGFloat)v
                     vtag:(NSInteger)vtag
                        y:(CGFloat)y
                        w:(CGFloat)w
                      fmt:(NSString *)fmt {
    UIView *row = [self rowWithLabel:title y:y h:56 w:w];
    UISlider *sl = [[UISlider alloc] init];
    sl.tag = 910;
    sl.frame = CGRectMake(16, 26, w - 116, 24);
    sl.minimumValue = mn;
    sl.maximumValue = mx;
    sl.value = v;
    sl.tintColor = PanelAccent();
    objc_setAssociatedObject(sl, "k", key, OBJC_ASSOCIATION_COPY);
    objc_setAssociatedObject(sl, "vt", @(vtag), OBJC_ASSOCIATION_RETAIN);
    [sl addTarget:self action:@selector(onSliderMoved:)
        forControlEvents:UIControlEventValueChanged];
    [row addSubview:sl];
    UITextField *tf = [[UITextField alloc] init];
    tf.tag = vtag;
    tf.frame = CGRectMake(w - 92, 24, 76, 28);
    tf.text = [NSString stringWithFormat:fmt, v];
    tf.textColor = PanelText();
    tf.backgroundColor = PanelFieldBg();
    tf.layer.cornerRadius = 6;
    tf.font = [UIFont monospacedDigitSystemFontOfSize:13
                weight:UIFontWeightMedium];
    tf.textAlignment = NSTextAlignmentCenter;
    tf.keyboardType = UIKeyboardTypeDecimalPad;
    tf.returnKeyType = UIReturnKeyDone;
    objc_setAssociatedObject(tf, "k", key, OBJC_ASSOCIATION_COPY);
    objc_setAssociatedObject(tf, "mn", @(mn), OBJC_ASSOCIATION_RETAIN);
    objc_setAssociatedObject(tf, "mx", @(mx), OBJC_ASSOCIATION_RETAIN);
    objc_setAssociatedObject(tf, "fmt", fmt, OBJC_ASSOCIATION_COPY);
    [tf addTarget:self action:@selector(onFieldEnd:)
        forControlEvents:UIControlEventEditingDidEnd |
                         UIControlEventEditingDidEndOnExit];
    [row addSubview:tf];
    return row;
}

+ (void)onFieldEnd:(UITextField *)tf { [self applyField:tf]; }

+ (void)applyField:(UITextField *)tf {
    NSString *which = objc_getAssociatedObject(tf, "k");
    if (!which) return;
    CGFloat mn = [objc_getAssociatedObject(tf, "mn") floatValue];
    CGFloat mx = [objc_getAssociatedObject(tf, "mx") floatValue];
    NSString *fmt = objc_getAssociatedObject(tf, "fmt") ?: @"%.2f";
    Settings *st = [Settings shared];
    CGFloat cur = 0;
    if ([which isEqualToString:@"size"])
        cur = gEditIsJoy ? st.joySize : (gEditCfg ? gEditCfg.size : 64);
    else if ([which isEqualToString:@"alpha"])
        cur = gEditIsJoy ? st.joyAlpha : (gEditCfg ? gEditCfg.alpha : 0.85);
    else if ([which isEqualToString:@"deadzone"])
        cur = st.joyDeadzone;
    else if ([which isEqualToString:@"curve"])
        cur = st.joyCurve;
    else if ([which isEqualToString:@"interval"])
        cur = gEditCfg ? gEditCfg.rapidInterval : 0.10;
    else if ([which isEqualToString:@"psize"])
        cur = gEditCfg ? gEditCfg.pSize : 64;
    else if ([which isEqualToString:@"palpha"])
        cur = gEditCfg ? gEditCfg.pAlpha : 0.6;
    NSString *s = tf.text ?: @"";
    s = [s stringByTrimmingCharactersInSet:
        [NSCharacterSet whitespaceCharacterSet]];
    BOOL ok = s.length > 0 && ![s isEqualToString:@"."];
    NSInteger dots = 0;
    for (NSUInteger i = 0; ok && i < s.length; i++) {
        unichar c = [s characterAtIndex:i];
        if (c == '.') { if (++dots > 1) ok = NO; }
        else if (!(c >= '0' && c <= '9')) ok = NO;
    }
    CGFloat v = cur;
    BOOL clamped = NO;
    if (ok) {
        v = (CGFloat)[s doubleValue];
        if (v < mn) { v = mn; clamped = YES; }
        if (v > mx) { v = mx; clamped = YES; }
    }
    if (!ok) {
        NSString *m = [NSString stringWithFormat:
            L(@"Invalid, range %.2f-%.2f", @"数值非法，范围 %.2f-%.2f"),
            (double)mn, (double)mx];
        [self toast:m];
        [self shake:tf];
    } else if (clamped) {
        NSString *m = [NSString stringWithFormat:
            L(@"Clamped to %.2f", @"已限制为 %.2f"), (double)v];
        [self toast:m];
        [self shake:tf];
    }
    if ([which isEqualToString:@"size"]) {
        if (gEditIsJoy) st.joySize = v;
        else if (gEditCfg) gEditCfg.size = v;
    } else if ([which isEqualToString:@"alpha"]) {
        if (gEditIsJoy) st.joyAlpha = v;
        else if (gEditCfg) gEditCfg.alpha = v;
    } else if ([which isEqualToString:@"deadzone"]) {
        st.joyDeadzone = v;
    } else if ([which isEqualToString:@"curve"]) {
        st.joyCurve = v;
    } else if ([which isEqualToString:@"interval"]) {
        if (gEditCfg) gEditCfg.rapidInterval = v;
    } else if ([which isEqualToString:@"psize"]) {
        if (gEditCfg) gEditCfg.pSize = v;
    } else if ([which isEqualToString:@"palpha"]) {
        if (gEditCfg) gEditCfg.pAlpha = v;
    }
    tf.text = [NSString stringWithFormat:fmt, v];
    UIView *pv = tf.superview;
    UIView *sv = pv ? [pv viewWithTag:910] : nil;
    if ([sv isKindOfClass:[UISlider class]]) {
        UISlider *slider = (UISlider *)sv;
        slider.value = v;
    }
    [st save];
    [[Presets shared] syncCurrent];
    [Pad apply];
}

+ (void)onSliderMoved:(UISlider *)sl {
    NSString *which = objc_getAssociatedObject(sl, "k");
    NSNumber *vtag = objc_getAssociatedObject(sl, "vt");
    Settings *st = [Settings shared];
    if ([which isEqualToString:@"size"]) {
        if (gEditIsJoy) st.joySize = sl.value;
        else if (gEditCfg) gEditCfg.size = sl.value;
    } else if ([which isEqualToString:@"alpha"]) {
        if (gEditIsJoy) st.joyAlpha = sl.value;
        else if (gEditCfg) gEditCfg.alpha = sl.value;
    } else if ([which isEqualToString:@"deadzone"]) {
        st.joyDeadzone = sl.value;
    } else if ([which isEqualToString:@"curve"]) {
        st.joyCurve = sl.value;
    } else if ([which isEqualToString:@"interval"]) {
        if (gEditCfg) gEditCfg.rapidInterval = sl.value;
    } else if ([which isEqualToString:@"psize"]) {
        if (gEditCfg) gEditCfg.pSize = sl.value;
    } else if ([which isEqualToString:@"palpha"]) {
        if (gEditCfg) gEditCfg.pAlpha = sl.value;
    }
    UIView *pv = sl.superview;
    UIView *tv = (pv && vtag) ? [pv viewWithTag:vtag.integerValue] : nil;
    if ([tv isKindOfClass:[UITextField class]]) {
        UITextField *field = (UITextField *)tv;
        NSString *fmt = objc_getAssociatedObject(field, "fmt") ?: @"%.2f";
        field.text = [NSString stringWithFormat:fmt, sl.value];
    }
    [st save];
    [Pad apply];
}

+ (void)buildEditRows {
    for (UIView *v in sEditContent.subviews) [v removeFromSuperview];
    if (gEditPressed && !gEditIsJoy && gEditCfg) {
        [self buildPressedRows];
        return;
    }
    Settings *st = [Settings shared];
    CGFloat w = sEditPanel.bounds.size.width;
    CGFloat y = 8;

    if (!gEditIsJoy) {
        UIView *row = [self rowWithLabel:L(@"Elements (multi)", @"组合键（可多选）")
                                       y:y h:76 w:w];
        UIScrollView *hs = [[UIScrollView alloc] init];
        hs.frame = CGRectMake(16, 28, w - 32, 40);
        hs.showsHorizontalScrollIndicator = NO;
        hs.delaysContentTouches = NO;
        NSArray *els = GamepadElements();
        NSArray *cur = gEditCfg.elements ?: @[];
        CGFloat x = 0;
        for (NSInteger i = 0; i < (NSInteger)els.count; i++) {
            NSString *eid = els[i];
            BOOL sel = [cur containsObject:eid];
            UIButton *chip = [UIButton buttonWithType:UIButtonTypeSystem];
            chip.frame = CGRectMake(x, 4, 60, 32);
            [chip setTitle:ElementLabel(eid) forState:UIControlStateNormal];
            UIColor *cc = sel ? [UIColor blackColor] : PanelText();
            [chip setTitleColor:cc forState:UIControlStateNormal];
            chip.titleLabel.font = [UIFont boldSystemFontOfSize:13];
            chip.backgroundColor = sel ? [UIColor whiteColor] : PanelFieldBg();
            chip.layer.cornerRadius = 8;
            chip.tag = i;
            UITapGestureRecognizer *t = [[UITapGestureRecognizer alloc]
                initWithTarget:self action:@selector(onEditElementTap:)];
            [t requireGestureRecognizerToFail:hs.panGestureRecognizer];
            [chip addGestureRecognizer:t];
            [hs addSubview:chip];
            x += 64;
        }
        hs.contentSize = CGSizeMake(x, 40);
        [row addSubview:hs];
        [sEditContent addSubview:row];
        y += 80;
    }

    if (!gEditIsJoy) {
        UIView *row = [self rowWithLabel:L(@"Text (optional)", @"自定义文字（可空）")
                                       y:y h:56 w:w];
        UITextField *tf = [[UITextField alloc] init];
        tf.frame = CGRectMake(16, 26, w - 32, 26);
        tf.text = gEditCfg.text ?: @"";
        tf.placeholder = L(@"leave empty to auto", @"留空自动");
        tf.textColor = PanelText();
        tf.backgroundColor = PanelFieldBg();
        tf.layer.cornerRadius = 6;
        tf.font = [UIFont systemFontOfSize:13];
        tf.textAlignment = NSTextAlignmentCenter;
        tf.returnKeyType = UIReturnKeyDone;
        [tf addTarget:self action:@selector(onTextEnd:)
            forControlEvents:UIControlEventEditingDidEnd |
                             UIControlEventEditingDidEndOnExit];
        [row addSubview:tf];
        [sEditContent addSubview:row];
        y += 60;
    }

    {
        UIView *row = [self rowWithLabel:L(@"Color", @"颜色") y:y h:76 w:w];
        UIScrollView *hs = [[UIScrollView alloc] init];
        hs.frame = CGRectMake(16, 28, w - 32, 40);
        hs.showsHorizontalScrollIndicator = NO;
        hs.delaysContentTouches = NO;
        NSArray *colors = [st allColors];
        NSInteger cur = gEditIsJoy ? st.joyColor : gEditCfg.color;
        CGFloat x = 0;
        for (NSInteger i = 0; i < (NSInteger)colors.count; i++) {
            UIButton *dot = [UIButton buttonWithType:UIButtonTypeCustom];
            dot.frame = CGRectMake(x, 6, 28, 28);
            dot.backgroundColor = colors[i];
            dot.layer.cornerRadius = 14;
            dot.layer.borderWidth = (i == cur) ? 3 : 1;
            UIColor *bc = (i == cur) ? PanelAccent() : PanelBorder();
            dot.layer.borderColor = bc.CGColor;
            dot.tag = i;
            UITapGestureRecognizer *t = [[UITapGestureRecognizer alloc]
                initWithTarget:self action:@selector(onEditColorTap:)];
            [t requireGestureRecognizerToFail:hs.panGestureRecognizer];
            [dot addGestureRecognizer:t];
            [hs addSubview:dot];
            x += 36;
        }
        UIButton *add = [UIButton buttonWithType:UIButtonTypeSystem];
        add.frame = CGRectMake(x, 6, 28, 28);
        [add setTitle:@"+" forState:UIControlStateNormal];
        [add setTitleColor:PanelText() forState:UIControlStateNormal];
        add.titleLabel.font = [UIFont boldSystemFontOfSize:20];
        add.backgroundColor = PanelFieldBg();
        add.layer.cornerRadius = 14;
        UITapGestureRecognizer *ta = [[UITapGestureRecognizer alloc]
            initWithTarget:self action:@selector(onEditAddColorTap:)];
        [ta requireGestureRecognizerToFail:hs.panGestureRecognizer];
        [add addGestureRecognizer:ta];
        [hs addSubview:add];
        hs.contentSize = CGSizeMake(x + 36, 40);
        [row addSubview:hs];
        [sEditContent addSubview:row];
        y += 80;
    }

    {
        CGFloat mnS = gEditIsJoy ? 60 : 40;
        CGFloat mxS = gEditIsJoy ? 260 : 140;
        CGFloat vS = gEditIsJoy ? st.joySize : gEditCfg.size;
        UIView *row = [self makeSliderRow:L(@"Size", @"大小")
            key:@"size" min:mnS max:mxS value:vS
            vtag:911 y:y w:w fmt:@"%.0f"];
        [sEditContent addSubview:row];
        y += 60;
    }

    {
        CGFloat vA = gEditIsJoy ? st.joyAlpha : gEditCfg.alpha;
        UIView *row = [self makeSliderRow:L(@"Opacity", @"透明度")
            key:@"alpha" min:0.15 max:1.0 value:vA
            vtag:912 y:y w:w fmt:@"%.2f"];
        [sEditContent addSubview:row];
        y += 60;
    }

    if (gEditIsJoy) {
        UIView *row = [self makeSliderRow:L(@"Deadzone", @"死区")
            key:@"deadzone" min:0.0 max:0.40 value:st.joyDeadzone
            vtag:913 y:y w:w fmt:@"%.2f"];
        [sEditContent addSubview:row];
        y += 60;
        UIView *row2 = [self makeSliderRow:L(@"Response Curve", @"响应曲线")
            key:@"curve" min:0.5 max:2.5 value:st.joyCurve
            vtag:914 y:y w:w fmt:@"%.2f"];
        [sEditContent addSubview:row2];
        y += 60;
    }

    {
        UIView *row = [self rowWithLabel:L(@"Style", @"样式") y:y h:56 w:w];
        UIButton *dd = [UIButton buttonWithType:UIButtonTypeSystem];
        dd.frame = CGRectMake(16, 26, w - 32, 26);
        NSString *curName = L(@"Default", @"默认");
        if (gEditIsJoy) {
            Skin *s = [Skin joyStyleBy:st.joyStyle];
            if (s) curName = L(s.en, s.zh);
        } else {
            Skin *s = [Skin btnStyleBy:gEditCfg.style];
            if (s) curName = L(s.en, s.zh);
        }
        NSString *dt = [NSString stringWithFormat:@"   %@   ▼", curName];
        [dd setTitle:dt forState:UIControlStateNormal];
        [dd setTitleColor:PanelText() forState:UIControlStateNormal];
        dd.titleLabel.font = [UIFont systemFontOfSize:13];
        dd.contentHorizontalAlignment = UIControlContentHorizontalAlignmentLeft;
        dd.backgroundColor = PanelFieldBg();
        dd.layer.cornerRadius = 6;
        objc_setAssociatedObject(dd, "kind", gEditIsJoy ? @"joy" : @"btn",
            OBJC_ASSOCIATION_COPY);
        [dd addTarget:self action:@selector(onStyleDropdown:)
            forControlEvents:UIControlEventTouchUpInside];
        [row addSubview:dd];
        [sEditContent addSubview:row];
        y += 60;
    }

    if (!gEditIsJoy) {
        UIView *row = [self rowWithLabel:L(@"Shape", @"形状") y:y h:62 w:w];
        UISegmentedControl *sg = [[UISegmentedControl alloc]
            initWithItems:@[L(@"Square", @"方形"), L(@"Circle", @"圆形")]];
        sg.frame = CGRectMake(16, 26, w - 32, 28);
        sg.selectedSegmentIndex = gEditCfg.shape;
        [sg addTarget:self action:@selector(onEditShape:)
            forControlEvents:UIControlEventValueChanged];
        [row addSubview:sg];
        [sEditContent addSubview:row];
        y += 66;
        UIView *r1 = [[UIView alloc] initWithFrame:CGRectMake(0, y, w, 48)];
        UILabel *l1 = [[UILabel alloc] initWithFrame:CGRectMake(16, 0, w - 80, 48)];
        l1.text = L(@"Auto Hold (toggle)", @"自动保持按住（切换）");
        l1.textColor = PanelSubText();
        l1.font = [UIFont systemFontOfSize:14];
        [r1 addSubview:l1];
        UISwitch *sw1 = [[UISwitch alloc] init];
        sw1.frame = CGRectMake(w - 66, 8, 51, 31);
        sw1.on = gEditCfg.turbo;
        [sw1 addTarget:self action:@selector(onEditTurbo:)
            forControlEvents:UIControlEventValueChanged];
        [r1 addSubview:sw1];
        [sEditContent addSubview:r1];
        y += 52;
        UIView *r2 = [[UIView alloc] initWithFrame:CGRectMake(0, y, w, 48)];
        UILabel *l2 = [[UILabel alloc] initWithFrame:CGRectMake(16, 0, w - 80, 48)];
        l2.text = L(@"Rapid Fire", @"自动连点");
        l2.textColor = PanelSubText();
        l2.font = [UIFont systemFontOfSize:14];
        [r2 addSubview:l2];
        UISwitch *sw2 = [[UISwitch alloc] init];
        sw2.frame = CGRectMake(w - 66, 8, 51, 31);
        sw2.on = gEditCfg.rapidFire;
        [sw2 addTarget:self action:@selector(onEditRapid:)
            forControlEvents:UIControlEventValueChanged];
        [r2 addSubview:sw2];
        [sEditContent addSubview:r2];
        y += 52;
    }

    if (!gEditIsJoy && gEditCfg.rapidFire) {
        UIView *row = [self makeSliderRow:L(@"Rapid Interval (s)", @"连点间隔（秒）")
            key:@"interval" min:0.02 max:1.0 value:gEditCfg.rapidInterval
            vtag:915 y:y w:w fmt:@"%.2f"];
        [sEditContent addSubview:row];
        y += 60;
        UIView *rk = [self rowWithLabel:L(@"Rapid Keys", @"连点键（默认同主键）")
                                     y:y h:76 w:w];
        UIScrollView *hs = [[UIScrollView alloc] init];
        hs.frame = CGRectMake(16, 28, w - 32, 40);
        hs.showsHorizontalScrollIndicator = NO;
        hs.delaysContentTouches = NO;
        NSArray *els = GamepadElements();
        NSArray *cur = gEditCfg.rapidKeys ?: @[];
        CGFloat x = 0;
        for (NSInteger i = 0; i < (NSInteger)els.count; i++) {
            NSString *eid = els[i];
            BOOL sel = [cur containsObject:eid];
            UIButton *chip = [UIButton buttonWithType:UIButtonTypeSystem];
            chip.frame = CGRectMake(x, 4, 60, 32);
            [chip setTitle:ElementLabel(eid) forState:UIControlStateNormal];
            UIColor *cc = sel ? [UIColor blackColor] : PanelText();
            [chip setTitleColor:cc forState:UIControlStateNormal];
            chip.titleLabel.font = [UIFont boldSystemFontOfSize:13];
            chip.backgroundColor = sel ? [UIColor whiteColor] : PanelFieldBg();
            chip.layer.cornerRadius = 8;
            chip.tag = i;
            UITapGestureRecognizer *t = [[UITapGestureRecognizer alloc]
                initWithTarget:self action:@selector(onEditRapidKeyTap:)];
            [t requireGestureRecognizerToFail:hs.panGestureRecognizer];
            [chip addGestureRecognizer:t];
            [hs addSubview:chip];
            x += 64;
        }
        hs.contentSize = CGSizeMake(x, 40);
        [rk addSubview:hs];
        [sEditContent addSubview:rk];
        y += 80;
    }

    if (!gEditIsJoy) {
        CGFloat dw = 160;
        UIButton *del = [UIButton buttonWithType:UIButtonTypeSystem];
        del.frame = CGRectMake((w - dw) / 2, y, dw, 40);
        [del setTitle:L(@"Delete Button", @"删除按键")
            forState:UIControlStateNormal];
        [del setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
        del.backgroundColor = [UIColor systemRedColor];
        del.layer.cornerRadius = 8;
        [del addTarget:self action:@selector(onEditDelete:)
            forControlEvents:UIControlEventTouchUpInside];
        [sEditContent addSubview:del];
        y += 48;
    }
    sEditContent.contentSize = CGSizeMake(w, y + 8);
}

+ (void)buildPressedRows {
    Settings *st = [Settings shared];
    CGFloat w = sEditPanel.bounds.size.width;
    CGFloat y = 8;

    {
        UIView *row = [self rowWithLabel:L(@"Pressed Text (empty=inherit)", @"按下文字（空=继承）")
                                       y:y h:56 w:w];
        UITextField *tf = [[UITextField alloc] init];
        tf.frame = CGRectMake(16, 26, w - 32, 26);
        tf.text = gEditCfg.pText ?: @"";
        tf.placeholder = L(@"leave empty to inherit", @"留空继承正常态");
        tf.textColor = PanelText();
        tf.backgroundColor = PanelFieldBg();
        tf.layer.cornerRadius = 6;
        tf.font = [UIFont systemFontOfSize:13];
        tf.textAlignment = NSTextAlignmentCenter;
        tf.returnKeyType = UIReturnKeyDone;
        [tf addTarget:self action:@selector(onPTextEnd:)
            forControlEvents:UIControlEventEditingDidEnd |
                             UIControlEventEditingDidEndOnExit];
        [row addSubview:tf];
        [sEditContent addSubview:row];
        y += 60;
    }

    {
        UIView *row = [self rowWithLabel:L(@"Pressed Color", @"按下颜色") y:y h:76 w:w];
        UIScrollView *hs = [[UIScrollView alloc] init];
        hs.frame = CGRectMake(16, 28, w - 32, 40);
        hs.showsHorizontalScrollIndicator = NO;
        hs.delaysContentTouches = NO;
        NSArray *colors = [st allColors];
        NSInteger cur = gEditCfg.pColor;
        CGFloat x = 0;
        for (NSInteger i = 0; i < (NSInteger)colors.count; i++) {
            UIButton *dot = [UIButton buttonWithType:UIButtonTypeCustom];
            dot.frame = CGRectMake(x, 6, 28, 28);
            dot.backgroundColor = colors[i];
            dot.layer.cornerRadius = 14;
            dot.layer.borderWidth = (i == cur) ? 3 : 1;
            UIColor *bc = (i == cur) ? PanelAccent() : PanelBorder();
            dot.layer.borderColor = bc.CGColor;
            dot.tag = i;
            UITapGestureRecognizer *t = [[UITapGestureRecognizer alloc]
                initWithTarget:self action:@selector(onPColorTap:)];
            [t requireGestureRecognizerToFail:hs.panGestureRecognizer];
            [dot addGestureRecognizer:t];
            [hs addSubview:dot];
            x += 36;
        }
        hs.contentSize = CGSizeMake(x, 40);
        [row addSubview:hs];
        [sEditContent addSubview:row];
        y += 80;
    }

    {
        UIView *row = [self makeSliderRow:L(@"Pressed Size", @"按下大小")
            key:@"psize" min:40 max:140 value:gEditCfg.pSize
            vtag:921 y:y w:w fmt:@"%.0f"];
        [sEditContent addSubview:row];
        y += 60;
    }

    {
        UIView *row = [self makeSliderRow:L(@"Pressed Opacity", @"按下透明度")
            key:@"palpha" min:0.15 max:1.0 value:gEditCfg.pAlpha
            vtag:922 y:y w:w fmt:@"%.2f"];
        [sEditContent addSubview:row];
        y += 60;
    }

    {
        UIView *row = [self rowWithLabel:L(@"Pressed Shape", @"按下形状") y:y h:62 w:w];
        UISegmentedControl *sg = [[UISegmentedControl alloc]
            initWithItems:@[L(@"Square", @"方形"), L(@"Circle", @"圆形")]];
        sg.frame = CGRectMake(16, 26, w - 32, 28);
        sg.selectedSegmentIndex = gEditCfg.pShape;
        [sg addTarget:self action:@selector(onPShape:)
            forControlEvents:UIControlEventValueChanged];
        [row addSubview:sg];
        [sEditContent addSubview:row];
        y += 66;
    }

    {
        UIButton *del = [UIButton buttonWithType:UIButtonTypeSystem];
        del.frame = CGRectMake(16, y, w - 32, 40);
        [del setTitle:L(@"Disable Pressed Style", @"禁用按下态")
            forState:UIControlStateNormal];
        [del setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
        del.backgroundColor = [UIColor systemRedColor];
        del.layer.cornerRadius = 8;
        [del addTarget:self action:@selector(onPDisable:)
            forControlEvents:UIControlEventTouchUpInside];
        [sEditContent addSubview:del];
        y += 48;
    }
    sEditContent.contentSize = CGSizeMake(w, y + 8);
}

+ (void)onStyleDropdown:(UIButton *)b {
    BOOL isJoy = [objc_getAssociatedObject(b, "kind") isEqualToString:@"joy"];
    NSArray<Skin *> *list = isJoy ? [Skin joyStyles] : [Skin btnStyles];
    if (list.count == 0) {
        [self toast:L(@"No styles registered", @"没有注册的样式")];
        return;
    }
    Settings *st = [Settings shared];
    NSInteger curIdx = isJoy ? st.joyStyle : (gEditCfg ? gEditCfg.style : 1);
    NSMutableArray *names = [NSMutableArray array];
    NSInteger cur = 0;
    for (NSInteger i = 0; i < (NSInteger)list.count; i++) {
        Skin *s = list[i];
        [names addObject:L(s.en, s.zh)];
        if (s.idx == curIdx) cur = i;
    }
    __weak typeof(self) weakSelf = self;
    [self showDropdownAt:b items:names current:cur onPick:^(NSInteger i) {
        if (i < 0 || i >= (NSInteger)list.count) return;
        Skin *picked = list[i];
        if (isJoy) st.joyStyle = picked.idx;
        else if (gEditCfg) gEditCfg.style = picked.idx;
        [st save];
        [[Presets shared] syncCurrent];
        [Pad apply];
        [weakSelf buildEditRows];
    }];
}

+ (void)onEditElementTap:(UITapGestureRecognizer *)g {
    [self onEditElement:(UIButton *)g.view];
}

+ (void)onEditRapidKeyTap:(UITapGestureRecognizer *)g {
    [self onEditRapidKey:(UIButton *)g.view];
}

+ (void)onEditColorTap:(UITapGestureRecognizer *)g {
    [self onEditColor:(UIButton *)g.view];
}

+ (void)onEditAddColorTap:(UITapGestureRecognizer *)g {
    [self onEditAddColor:(UIButton *)g.view];
}

+ (void)onPColorTap:(UITapGestureRecognizer *)g {
    if (!gEditCfg) return;
    gEditCfg.pColor = g.view.tag;
    [[Settings shared] save];
    [[Presets shared] syncCurrent];
    [self buildEditRows];
}

+ (void)onEditElement:(UIButton *)b {
    if (gEditIsJoy || !gEditCfg) return;
    NSArray *els = GamepadElements();
    if (b.tag < 0 || b.tag >= (NSInteger)els.count) return;
    NSString *e = els[b.tag];
    NSMutableArray *cur = [NSMutableArray arrayWithArray:gEditCfg.elements ?: @[]];
    if ([cur containsObject:e]) {
        if (cur.count <= 1) {
            [self toast:L(@"At least one element required", @"至少保留一个键位")];
            return;
        }
        [cur removeObject:e];
    } else {
        [cur addObject:e];
    }
    gEditCfg.elements = cur;
    [[Settings shared] save];
    [[Presets shared] syncCurrent];
    [Pad apply];
    [self buildEditRows];
}

+ (void)onEditRapidKey:(UIButton *)b {
    if (gEditIsJoy || !gEditCfg) return;
    NSArray *els = GamepadElements();
    if (b.tag < 0 || b.tag >= (NSInteger)els.count) return;
    NSString *e = els[b.tag];
    NSMutableArray *cur = [NSMutableArray arrayWithArray:gEditCfg.rapidKeys ?: @[]];
    if ([cur containsObject:e]) [cur removeObject:e];
    else [cur addObject:e];
    gEditCfg.rapidKeys = cur;
    [[Settings shared] save];
    [[Presets shared] syncCurrent];
    [self buildEditRows];
}

+ (void)onTextEnd:(UITextField *)tf {
    if (gEditIsJoy || !gEditCfg) return;
    gEditCfg.text = tf.text ?: @"";
    [[Settings shared] save];
    [[Presets shared] syncCurrent];
    [Pad apply];
}

+ (void)onPTextEnd:(UITextField *)tf {
    if (!gEditCfg) return;
    gEditCfg.pText = tf.text ?: @"";
    [[Settings shared] save];
    [[Presets shared] syncCurrent];
}

+ (void)onEditColor:(UIButton *)b {
    Settings *st = [Settings shared];
    if (gEditIsJoy) st.joyColor = b.tag;
    else if (gEditCfg) gEditCfg.color = b.tag;
    [st save];
    [[Presets shared] syncCurrent];
    [Pad apply];
    [self buildEditRows];
}

+ (void)onPShape:(UISegmentedControl *)sg {
    if (!gEditCfg) return;
    gEditCfg.pShape = (BtnShape)sg.selectedSegmentIndex;
    [[Settings shared] save];
    [[Presets shared] syncCurrent];
}

+ (void)onPDisable:(UIButton *)b {
    if (!gEditCfg) return;
    gEditCfg.hasPressed = NO;
    gEditPressed = NO;
    [[Settings shared] save];
    [[Presets shared] syncCurrent];
    UISegmentedControl *tab = [sEditPanel viewWithTag:910];
    if (tab) tab.selectedSegmentIndex = 0;
    [self buildEditRows];
}

+ (void)onEditAddColor:(UIButton *)b {
    UIAlertController *ac = [UIAlertController
        alertControllerWithTitle:L(@"Custom Color", @"自定义颜色")
        message:L(@"Enter hex like #FF8800 or #F80",
                  @"输入 hex，如 #FF8800 或 #F80")
        preferredStyle:UIAlertControllerStyleAlert];
    [ac addTextFieldWithConfigurationHandler:^(UITextField *tf) {
        tf.placeholder = @"#FF8800";
        tf.autocapitalizationType = UITextAutocapitalizationTypeAllCharacters;
        tf.keyboardType = UIKeyboardTypeASCIICapable;
    }];
    __weak typeof(self) weakSelf = self;
    [ac addAction:[UIAlertAction actionWithTitle:L(@"Cancel", @"取消")
        style:UIAlertActionStyleCancel handler:nil]];
    [ac addAction:[UIAlertAction actionWithTitle:L(@"Add", @"添加")
        style:UIAlertActionStyleDefault handler:^(UIAlertAction *a) {
            UITextField *tf = ac.textFields.firstObject;
            NSString *hex = tf.text;
            Settings *st = [Settings shared];
            NSInteger idx = [st addCustomColor:hex];
            if (idx < 0) {
                NSString *m = [NSString stringWithFormat:
                    L(@"Invalid hex: %@", @"颜色格式非法：%@"), hex ?: @""];
                [weakSelf toast:m];
                return;
            }
            if (gEditIsJoy) st.joyColor = idx;
            else if (gEditCfg) gEditCfg.color = idx;
            [st save];
            [[Presets shared] syncCurrent];
            [Pad apply];
            [weakSelf buildEditRows];
            [weakSelf toast:L(@"Color added", @"颜色已添加")];
        }]];
    [sWin.rootViewController presentViewController:ac animated:YES completion:nil];
}

+ (void)onEditShape:(UISegmentedControl *)sg {
    if (gEditIsJoy || !gEditCfg) return;
    gEditCfg.shape = (BtnShape)sg.selectedSegmentIndex;
    [[Settings shared] save];
    [[Presets shared] syncCurrent];
    [Pad apply];
}

+ (void)onEditTurbo:(UISwitch *)sw {
    if (gEditIsJoy || !gEditCfg) return;
    gEditCfg.turbo = sw.on;
    [[Settings shared] save];
    [[Presets shared] syncCurrent];
}

+ (void)onEditRapid:(UISwitch *)sw {
    if (gEditIsJoy || !gEditCfg) return;
    gEditCfg.rapidFire = sw.on;
    [[Settings shared] save];
    [[Presets shared] syncCurrent];
    [self buildEditRows];
}

+ (void)onEditDelete:(UIButton *)b {
    if (gEditIsJoy || !gEditCfg) return;
    BtnCfg *cfg = gEditCfg;
    __weak typeof(self) weakSelf = self;
    [self confirm:L(@"Delete this button?", @"删除这个按键？") action:^{
        [[Settings shared] removeButton:cfg];
        [[Settings shared] save];
        [[Presets shared] syncCurrent];
        [Pad rebuild];
        [weakSelf closeEditPanel];
        [weakSelf toast:L(@"Button removed", @"按键已删除")];
    }];
}

+ (void)layoutPanel {
    if (!sPanel || !sWin) return;
    Settings *st = [Settings shared];
    CGRect scr = [UIScreen mainScreen].bounds;
    UIEdgeInsets safe = UIEdgeInsetsZero;
    if (@available(iOS 11.0, *)) safe = sWin.safeAreaInsets;
    const CGFloat barH = 44;
    CGSize sz;
    CGPoint ctr;
    if (st.hudState == HUDStateFull) {
        sz = scr.size;
        ctr = CGPointMake(scr.size.width / 2, scr.size.height / 2);
        sPanel.layer.cornerRadius = 0;
    } else {
        CGFloat contentH = [self menuSpec].count * 60 + 24;
        CGFloat maxW = scr.size.width - 40;
        CGFloat maxH = scr.size.height - safe.top - safe.bottom - 60;
        CGFloat pw = MIN(340, maxW);
        CGFloat ph = MIN(contentH + barH, maxH);
        sz = CGSizeMake(pw, ph);
        if (st.panelPos.x == 0 && st.panelPos.y == 0)
            ctr = CGPointMake(scr.size.width - pw / 2 - 16, scr.size.height / 2);
        else
            ctr = CGPointMake(scr.size.width / 2 + st.panelPos.x,
                              scr.size.height / 2 + st.panelPos.y);
        sPanel.layer.cornerRadius = 18;
    }
    sPanel.bounds = CGRectMake(0, 0, sz.width, sz.height);
    sPanel.center = ctr;
    UIView *bar = [sPanel viewWithTag:100];
    bar.frame = CGRectMake(0, 0, sz.width, barH);
    sTitle.frame = CGRectMake(16, 0, sz.width - 100, barH);
    UIButton *minBtn = (UIButton *)[bar viewWithTag:101];
    minBtn.frame = CGRectMake(sz.width - 76, 8, 28, 28);
    UIButton *maxBtn = (UIButton *)[bar viewWithTag:102];
    maxBtn.frame = CGRectMake(sz.width - 42, 8, 28, 28);
    sContent.frame = CGRectMake(0, barH, sz.width, sz.height - barH);
    CGFloat y = 12;
    for (UIView *row in sContent.subviews) {
        row.frame = CGRectMake(0, y, sz.width, 56);
        UILabel *title = [row viewWithTag:301];
        title.frame = CGRectMake(16, 4, sz.width - 32, 18);
        UIButton *btn = (UIButton *)[row viewWithTag:306];
        if (btn) btn.frame = CGRectMake(16, 22, 130, 30);
        y += 60;
    }
    sContent.contentSize = CGSizeMake(sz.width, y + 12);
}

+ (void)applyAll {
    if (!sPanel || !sBall) return;
    Settings *st = [Settings shared];
    HUDState state = st.hudState;
    if (gHidden) {
        sBall.hidden = NO;
        sPanel.hidden = YES;
        [Pad setVisible:NO];
        sEditing = NO;
        [Pad setEditing:NO];
        [self closeEditPanel];
        return;
    }
    [Pad setVisible:YES];
    if (state == HUDStateBall) {
        sBall.hidden = NO;
        sPanel.hidden = YES;
        sEditing = NO;
        [Pad setEditing:NO];
        [self closeEditPanel];
    } else {
        sBall.hidden = YES;
        sPanel.hidden = NO;
        sEditing = YES;
        [Pad setEditing:YES];
        [self layoutPanel];
    }
}

+ (void)applyState:(HUDState)state {
    Settings *st = [Settings shared];
    st.hudState = state;
    [st save];
    [self applyAll];
}

+ (void)onBallTap:(UITapGestureRecognizer *)g {
    if (gHidden) return;
    [self applyState:HUDStateMedium];
}

+ (void)onBallLong:(UILongPressGestureRecognizer *)g {
    if (g.state != UIGestureRecognizerStateBegan) return;
    gHidden = !gHidden;
    Settings *st = [Settings shared];
    st.hidden = gHidden;
    [st save];
    [[Presets shared] syncCurrent];
    [self applyAll];
    [self toast:gHidden
        ? L(@"Hidden (long-press to show)", @"已隐藏（长按恢复）")
        : L(@"Shown", @"已恢复")];
}

+ (void)onBallPan:(UIPanGestureRecognizer *)g {
    CGPoint t = [g translationInView:sBall.superview];
    if (g.state == UIGestureRecognizerStateBegan ||
        g.state == UIGestureRecognizerStateChanged) {
        sBall.center = CGPointMake(sBall.center.x + t.x, sBall.center.y + t.y);
        [g setTranslation:CGPointZero inView:sBall.superview];
    } else if (g.state == UIGestureRecognizerStateEnded) {
        [self clampBall];
        Settings *st = [Settings shared];
        st.ballPos = sBall.center;
        [st save];
    }
}

+ (void)clampBall {
    if (!sBall) return;
    CGRect scr = [UIScreen mainScreen].bounds;
    CGFloat r = sBall.bounds.size.width / 2;
    CGFloat x = MAX(r + 8, MIN(scr.size.width - r - 8, sBall.center.x));
    CGFloat y = MAX(r + 8, MIN(scr.size.height - r - 8, sBall.center.y));
    sBall.center = CGPointMake(x, y);
}

+ (void)onMin { [self applyState:HUDStateBall]; }

+ (void)onMax {
    Settings *st = [Settings shared];
    HUDState next = (st.hudState == HUDStateFull) ? HUDStateMedium : HUDStateFull;
    [self applyState:next];
}

+ (void)showPresetPanel {
    [self hidePresetPanel];
    CGRect scr = [UIScreen mainScreen].bounds;
    CGFloat w = MIN(360, scr.size.width - 40);
    CGFloat h = MIN(560, scr.size.height - 100);

    sPresetPanel = [[UIView alloc] initWithFrame:CGRectMake(0, 0, w, h)];
    sPresetPanel.center = CGPointMake(scr.size.width / 2, scr.size.height / 2);
    sPresetPanel.backgroundColor = PanelBg();
    sPresetPanel.layer.cornerRadius = 18;
    sPresetPanel.layer.masksToBounds = YES;
    [sWin.rootViewController.view addSubview:sPresetPanel];

    UIView *bar = [[UIView alloc] initWithFrame:CGRectMake(0, 0, w, 44)];
    bar.backgroundColor = PanelBarBg();
    bar.userInteractionEnabled = YES;
    [sPresetPanel addSubview:bar];
    [bar addGestureRecognizer:[[UIPanGestureRecognizer alloc]
        initWithTarget:self action:@selector(onPresetDrag:)]];

    UILabel *title = [[UILabel alloc] initWithFrame:CGRectMake(16, 0, w - 60, 44)];
    title.text = L(@"Presets", @"预设");
    title.textColor = PanelText();
    title.font = [UIFont boldSystemFontOfSize:16];
    [bar addSubview:title];

    UIButton *close = PanelIconButton(@"xmark", @"X");
    close.frame = CGRectMake(w - 42, 8, 28, 28);
    [close addTarget:self action:@selector(hidePresetPanel)
        forControlEvents:UIControlEventTouchUpInside];
    [bar addSubview:close];

    CGFloat footH = 48;
    UIView *foot = [[UIView alloc] initWithFrame:CGRectMake(0, h - footH, w, footH)];
    foot.backgroundColor = PanelBarBg();
    [sPresetPanel addSubview:foot];

    CGFloat bw = (w - 24) / 2;
    UIButton *newBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    newBtn.frame = CGRectMake(8, 8, bw, 32);
    [newBtn setTitle:L(@"New", @"新建") forState:UIControlStateNormal];
    [newBtn setTitleColor:PanelText() forState:UIControlStateNormal];
    newBtn.backgroundColor = PanelFieldBg();
    newBtn.layer.cornerRadius = 8;
    [newBtn addTarget:self action:@selector(onPresetNew)
        forControlEvents:UIControlEventTouchUpInside];
    [foot addSubview:newBtn];

    UIButton *impBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    impBtn.frame = CGRectMake(w / 2 + 4, 8, bw, 32);
    [impBtn setTitle:L(@"Paste", @"粘贴导入") forState:UIControlStateNormal];
    [impBtn setTitleColor:PanelText() forState:UIControlStateNormal];
    impBtn.backgroundColor = PanelFieldBg();
    impBtn.layer.cornerRadius = 8;
    [impBtn addTarget:self action:@selector(onPresetPaste)
        forControlEvents:UIControlEventTouchUpInside];
    [foot addSubview:impBtn];

    sPresetContent = [[UIScrollView alloc] initWithFrame:
        CGRectMake(0, 44, w, h - 44 - footH)];
    sPresetContent.alwaysBounceVertical = YES;
    [sPresetPanel addSubview:sPresetContent];

    [self buildPresetRows];
}

+ (void)hidePresetPanel {
    [sPresetPanel removeFromSuperview];
    sPresetPanel = nil;
    sPresetContent = nil;
}

+ (void)onPresetDrag:(UIPanGestureRecognizer *)g {
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

+ (void)buildPresetRows {
    for (UIView *v in sPresetContent.subviews) [v removeFromSuperview];
    Presets *ps = [Presets shared];
    NSArray *list = [ps all];
    CGFloat w = sPresetContent.bounds.size.width;
    CGFloat rowH = 56;
    CGFloat y = 8;

    for (NSInteger i = 0; i < (NSInteger)list.count; i++) {
        Preset *p = list[i];
        BOOL active = [p.pid isEqualToString:[ps activeId]];

        UIView *row = [[UIView alloc] initWithFrame:
            CGRectMake(8, y, w - 16, rowH - 4)];
        row.backgroundColor = active ? PanelFieldBg() : [UIColor clearColor];
        row.layer.cornerRadius = 8;
        row.tag = i;
        [row addGestureRecognizer:[[UITapGestureRecognizer alloc]
            initWithTarget:self action:@selector(onPresetRowTap:)]];

        UILabel *name = [[UILabel alloc] initWithFrame:
            CGRectMake(12, 6, w - 100, 20)];
        name.text = p.name;
        name.textColor = PanelText();
        name.font = [UIFont systemFontOfSize:15 weight:UIFontWeightMedium];
        [row addSubview:name];

        NSArray *btns = p.data[@"buttons"];
        NSInteger cnt = [btns isKindOfClass:[NSArray class]] ? btns.count : 0;
        UILabel *meta = [[UILabel alloc] initWithFrame:
            CGRectMake(12, rowH - 26, w - 100, 14)];
        meta.text = [NSString stringWithFormat:@"%ld %@", (long)cnt,
                     L(@"buttons", @"个按键")];
        meta.textColor = PanelSubText();
        meta.font = [UIFont systemFontOfSize:11];
        [row addSubview:meta];

        if (active) {
            UILabel *mark = [[UILabel alloc] initWithFrame:
                CGRectMake(w - 96, 6, 60, 18)];
            mark.text = @"✓";
            mark.textColor = PanelAccent();
            mark.font = [UIFont boldSystemFontOfSize:16];
            mark.textAlignment = NSTextAlignmentRight;
            [row addSubview:mark];
        }

        UIButton *more = [UIButton buttonWithType:UIButtonTypeSystem];
        more.frame = CGRectMake(w - 16 - 44, 10, 36, 32);
        [more setTitle:@"···" forState:UIControlStateNormal];
        [more setTitleColor:PanelText() forState:UIControlStateNormal];
        more.titleLabel.font = [UIFont boldSystemFontOfSize:16];
        more.backgroundColor = PanelFieldBg();
        more.layer.cornerRadius = 8;
        more.tag = i;
        [more addTarget:self action:@selector(onPresetMore:)
            forControlEvents:UIControlEventTouchUpInside];
        [row addSubview:more];

        [sPresetContent addSubview:row];
        y += rowH;
    }
    sPresetContent.contentSize = CGSizeMake(w, y + 8);
}

+ (void)onPresetRowTap:(UITapGestureRecognizer *)g {
    NSInteger i = g.view.tag;
    Presets *ps = [Presets shared];
    NSArray *list = [ps all];
    if (i < 0 || i >= (NSInteger)list.count) return;
    [ps apply:list[i]];
    [Pad rebuild];
    [Pad apply];
    [self buildPresetRows];
    [self toast:L(@"Preset applied", @"已切换预设")];
}

+ (void)onPresetMore:(UIButton *)b {
    NSInteger i = b.tag;
    Presets *ps = [Presets shared];
    NSArray *list = [ps all];
    if (i < 0 || i >= (NSInteger)list.count) return;
    Preset *p = list[i];

    UIAlertController *ac = [UIAlertController
        alertControllerWithTitle:p.name message:nil
        preferredStyle:UIAlertControllerStyleActionSheet];

    [ac addAction:[UIAlertAction actionWithTitle:L(@"Rename", @"重命名")
        style:UIAlertActionStyleDefault handler:^(UIAlertAction *a) {
            [self presetRename:p];
        }]];
    [ac addAction:[UIAlertAction actionWithTitle:
        L(@"Copy to clipboard", @"复制到剪贴板")
        style:UIAlertActionStyleDefault handler:^(UIAlertAction *a) {
            [ps syncCurrent];
            NSString *s = [ps exportString:p];
            if (s) {
                [UIPasteboard generalPasteboard].string = s;
                [self toast:L(@"Copied to clipboard", @"已复制到剪贴板")];
            }
        }]];
    if ([list count] > 1) {
        [ac addAction:[UIAlertAction actionWithTitle:L(@"Delete", @"删除")
            style:UIAlertActionStyleDestructive handler:^(UIAlertAction *a) {
                [ps remove:p];
                [Pad rebuild];
                [Pad apply];
                [self buildPresetRows];
            }]];
    }
    [ac addAction:[UIAlertAction actionWithTitle:L(@"Cancel", @"取消")
        style:UIAlertActionStyleCancel handler:nil]];
    ac.popoverPresentationController.sourceView = b;
    ac.popoverPresentationController.sourceRect = b.bounds;
    [sWin.rootViewController presentViewController:ac animated:YES completion:nil];
}

+ (void)presetRename:(Preset *)p {
    UIAlertController *ac = [UIAlertController
        alertControllerWithTitle:L(@"Rename", @"重命名")
        message:nil preferredStyle:UIAlertControllerStyleAlert];
    [ac addTextFieldWithConfigurationHandler:^(UITextField *tf) {
        tf.text = p.name;
    }];
    [ac addAction:[UIAlertAction actionWithTitle:L(@"Cancel", @"取消")
        style:UIAlertActionStyleCancel handler:nil]];
    [ac addAction:[UIAlertAction actionWithTitle:L(@"OK", @"确定")
        style:UIAlertActionStyleDefault handler:^(UIAlertAction *a) {
            [[Presets shared] rename:p
                                name:ac.textFields.firstObject.text];
            [self buildPresetRows];
        }]];
    [sWin.rootViewController presentViewController:ac animated:YES completion:nil];
}

+ (void)onPresetNew {
    UIAlertController *ac = [UIAlertController
        alertControllerWithTitle:L(@"New preset", @"新建预设")
        message:L(@"Copy current settings", @"复制当前设置")
        preferredStyle:UIAlertControllerStyleAlert];
    [ac addTextFieldWithConfigurationHandler:^(UITextField *tf) {
        tf.placeholder = L(@"Preset name", @"预设名称");
    }];
    [ac addAction:[UIAlertAction actionWithTitle:L(@"Cancel", @"取消")
        style:UIAlertActionStyleCancel handler:nil]];
    [ac addAction:[UIAlertAction actionWithTitle:L(@"OK", @"确定")
        style:UIAlertActionStyleDefault handler:^(UIAlertAction *a) {
            [[Presets shared] createFromCurrent:
                ac.textFields.firstObject.text];
            [self buildPresetRows];
        }]];
    [sWin.rootViewController presentViewController:ac animated:YES completion:nil];
}

+ (void)onPresetPaste {
    NSString *s = [UIPasteboard generalPasteboard].string;
    NSString *err = nil;
    Preset *p = [[Presets shared] importString:s error:&err];
    if (p) {
        [self buildPresetRows];
        [self toast:L(@"Imported", @"已导入")];
    } else {
        [self toast:err ?: L(@"Import failed", @"导入失败")];
    }
}

+ (void)onRotate {
    dispatch_async(dispatch_get_main_queue(), ^{
        if (!sWin) return;
        sWin.frame = [UIScreen mainScreen].bounds;
        Settings *st = [Settings shared];
        if (!gHidden && st.hudState != HUDStateBall) [self layoutPanel];
        if (sEditPanel) {
            CGFloat w = MIN(360, sWin.bounds.size.width - 40);
            CGFloat h = MIN(620, sWin.bounds.size.height - 100);
            sEditPanel.bounds = CGRectMake(0, 0, w, h);
            sEditPanel.center = CGPointMake(sWin.bounds.size.width / 2,
                                            sWin.bounds.size.height / 2);
            sEditPanelCenter = sEditPanel.center;
            UIView *bar = [sEditPanel viewWithTag:901];
            bar.frame = CGRectMake(0, 0, w, 44);
            sEditTitle.frame = CGRectMake(16, 0, w - 60, 44);
            UIButton *close = (UIButton *)[bar viewWithTag:903];
            close.frame = CGRectMake(w - 42, 8, 28, 28);
            UISegmentedControl *tab = [sEditPanel viewWithTag:910];
            CGFloat topY = 44;
            if (tab) {
                tab.frame = CGRectMake(16, 50, w - 32, 30);
                topY = 88;
            }
            sEditContent.frame = CGRectMake(0, topY, w, h - topY);
            [self buildEditRows];
        }
        [self clampBall];
    });
}

@end