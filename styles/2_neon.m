#import "Style.h"

void SkinReg2(void) {
    [Skin registerJoy:2 en:@"Neon" zh:@"霓虹"
        block:^(UIView *base, UIView *thumb, UIColor *color, CGFloat alpha) {
            base.layer.masksToBounds = NO;
            base.backgroundColor = [UIColor colorWithWhite:0.05 alpha:alpha * 0.5];
            base.layer.borderWidth = 2;
            base.layer.borderColor = [color colorWithAlphaComponent:alpha].CGColor;
            base.layer.shadowColor = color.CGColor;
            base.layer.shadowRadius = 10;
            base.layer.shadowOpacity = alpha * 0.9;
            base.layer.shadowOffset = CGSizeZero;

            thumb.layer.masksToBounds = NO;
            thumb.layer.borderWidth = 0;
            thumb.backgroundColor = [color colorWithAlphaComponent:alpha];
            thumb.layer.shadowColor = color.CGColor;
            thumb.layer.shadowRadius = 8;
            thumb.layer.shadowOpacity = alpha;
            thumb.layer.shadowOffset = CGSizeZero;
        }];

    [Skin registerBtn:2 en:@"Neon" zh:@"霓虹"
        block:^(UIView *visual, UILabel *label, UIColor *color, CGFloat alpha) {
            visual.layer.masksToBounds = NO;
            visual.backgroundColor = [UIColor colorWithWhite:0.08 alpha:alpha * 0.7];
            visual.layer.borderWidth = 2;
            visual.layer.borderColor = [color colorWithAlphaComponent:alpha].CGColor;
            visual.layer.shadowColor = color.CGColor;
            visual.layer.shadowRadius = 10;
            visual.layer.shadowOpacity = alpha;
            visual.layer.shadowOffset = CGSizeZero;
            label.textColor = [UIColor whiteColor];
        }];
}