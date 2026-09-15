#pragma once
#import <Foundation/Foundation.h>

typedef NS_ENUM(NSInteger, LangMode) { LangAuto = 0, LangEn = 1, LangZh = 2 };

void LangSetMode(LangMode m);
LangMode LangGetMode(void);
NSString *L(NSString *en, NSString *zh);
NSString *LangName(LangMode m);