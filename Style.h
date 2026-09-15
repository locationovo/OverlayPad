#pragma once
#import <UIKit/UIKit.h>

typedef void (^JoyStyleBlock)(UIView *base, UIView *thumb, UIColor *color, CGFloat alpha);
typedef void (^BtnStyleBlock)(UIView *visual, UILabel *label, UIColor *color, CGFloat alpha);

@interface Skin : NSObject
@property (nonatomic, assign) NSInteger idx;
@property (nonatomic, copy)   NSString *en;
@property (nonatomic, copy)   NSString *zh;

+ (void)registerJoy:(NSInteger)idx en:(NSString *)en zh:(NSString *)zh block:(JoyStyleBlock)b;
+ (void)registerBtn:(NSInteger)idx en:(NSString *)en zh:(NSString *)zh block:(BtnStyleBlock)b;

+ (NSArray<Skin *> *)joyStyles;
+ (NSArray<Skin *> *)btnStyles;

+ (Skin *)joyStyleBy:(NSInteger)idx;
+ (Skin *)btnStyleBy:(NSInteger)idx;

+ (void)applyJoy:(NSInteger)idx base:(UIView *)base thumb:(UIView *)thumb
           color:(UIColor *)color alpha:(CGFloat)alpha;

+ (void)applyBtn:(NSInteger)idx visual:(UIView *)visual label:(UILabel *)label
           color:(UIColor *)color alpha:(CGFloat)alpha;
@end

void SkinRegAll(void);