#pragma once
#import <UIKit/UIKit.h>
#import "Localization.h"

typedef NS_ENUM(NSInteger, BtnShape) { BtnShapeSquare, BtnShapeCircle };
typedef NS_ENUM(NSInteger, HUDState) { HUDStateBall, HUDStateMedium, HUDStateFull };

NSArray<UIColor *> *Palette(void);
NSArray<NSString *> *GamepadElements(void);
NSString *ElementLabel(NSString *eid);
UIColor *ColorFromHex(NSString *hex);
NSString *HexFromColor(UIColor *c);

UIColor *PanelBg(void);
UIColor *PanelBarBg(void);
UIColor *PanelText(void);
UIColor *PanelSubText(void);
UIColor *PanelFieldBg(void);
UIColor *PanelAccent(void);
UIColor *PanelBorder(void);

UIButton *PanelIconButton(NSString *sfName, NSString *fallback);

#ifndef DEBUG
#define DEBUG 0
#endif

#if DEBUG
void JoyLog(NSString *fmt, ...);
#define LOG(fmt, ...) JoyLog(fmt, ##__VA_ARGS__)
#else
#define LOG(fmt, ...) do {} while (0)
#endif