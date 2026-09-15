#pragma once
#import "Common.h"

@interface BtnCfg : NSObject
@property (nonatomic, copy)   NSString *eid;
@property (nonatomic, assign) CGPoint   pos;
@property (nonatomic, assign) CGFloat   size;
@property (nonatomic, assign) CGFloat   alpha;
@property (nonatomic, assign) NSInteger color;
@property (nonatomic, assign) BtnShape  shape;

@property (nonatomic, copy)   NSString *text;
@property (nonatomic, strong) NSArray<NSString *> *elements;

@property (nonatomic, assign) BOOL      turbo;
@property (nonatomic, assign) BOOL      rapidFire;
@property (nonatomic, assign) CGFloat   rapidInterval;
@property (nonatomic, strong) NSArray<NSString *> *rapidKeys;

@property (nonatomic, assign) NSInteger style;

@property (nonatomic, assign) BOOL      hasPressed;
@property (nonatomic, assign) CGFloat   pSize;
@property (nonatomic, assign) CGFloat   pAlpha;
@property (nonatomic, assign) NSInteger pColor;
@property (nonatomic, assign) BtnShape  pShape;
@property (nonatomic, copy)   NSString *pText;

+ (instancetype)fromDict:(NSDictionary *)d;
- (NSDictionary *)toDict;
- (NSString *)displayText;
- (NSString *)pressedText;
@end

@interface Settings : NSObject
@property (nonatomic, assign) CGFloat joySize;
@property (nonatomic, assign) CGFloat joyAlpha;
@property (nonatomic, assign) NSInteger joyColor;
@property (nonatomic, assign) CGPoint joyPos;
@property (nonatomic, assign) CGFloat joyDeadzone;
@property (nonatomic, assign) CGFloat joyCurve;
@property (nonatomic, assign) NSInteger joyStyle;

@property (nonatomic, assign) CGPoint ballPos;
@property (nonatomic, assign) CGPoint panelPos;
@property (nonatomic, assign) HUDState hudState;
@property (nonatomic, assign) BOOL hidden;

@property (nonatomic, assign) LangMode langMode;
@property (nonatomic, strong) NSMutableArray<NSString *> *customColors;
@property (nonatomic, strong) NSMutableArray<BtnCfg *> *buttons;

+ (instancetype)shared;
- (void)load;
- (void)save;
- (UIColor *)joyUIColor;
- (UIColor *)btnUIColorFor:(NSInteger)idx;
- (NSArray<UIColor *> *)allColors;
- (NSInteger)addCustomColor:(NSString *)hex;
- (BtnCfg *)addButton;
- (void)removeButton:(BtnCfg *)b;
- (void)resetPositions;
- (void)resetAll;

- (NSDictionary *)exportDict;
- (BOOL)importDict:(NSDictionary *)d;
@end