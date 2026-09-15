#pragma once
#import <UIKit/UIKit.h>
#import "Settings.h"

@interface Pad : NSObject
+ (void)buildIn:(UIView *)host;
+ (void)rebuild;
+ (void)apply;
+ (void)setEditing:(BOOL)editing;
+ (void)setVisible:(BOOL)visible;
+ (void)resetPositions;
+ (BOOL)owns:(UIView *)v;
+ (BtnCfg *)cfgForButton:(UIButton *)btn;
@end