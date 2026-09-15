#import "Style.h"

void SkinReg1(void) {
    [Skin registerJoy:1 en:@"Classic" zh:@"经典"
        block:^(UIView *base, UIView *thumb, UIColor *color, CGFloat alpha) {
            base.layer.masksToBounds = YES;
            base.backgroundColor = [color colorWithAlphaComponent:alpha * 0.15];
            base.layer.borderWidth = 1.5;
            base.layer.borderColor = [color colorWithAlphaComponent:alpha * 0.55].CGColor;
            base.layer.shadowOpacity = 0;

            thumb.layer.masksToBounds = YES;
            thumb.layer.borderWidth = 0;
            thumb.backgroundColor = [UIColor colorWithWhite:1.0 alpha:alpha];
            thumb.layer.shadowOpacity = 0;
        }];

    [Skin registerBtn:1 en:@"Classic" zh:@"经典"
        block:^(UIView *visual, UILabel *label, UIColor *color, CGFloat alpha) {
            visual.layer.masksToBounds = YES;
            visual.backgroundColor = [color colorWithAlphaComponent:alpha];
            visual.layer.borderWidth = 0;
            visual.layer.shadowOpacity = 0;
            label.textColor = [UIColor colorWithWhite:0.10 alpha:0.95];
        }];
}