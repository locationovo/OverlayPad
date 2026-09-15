#pragma once
#import <UIKit/UIKit.h>

void DBGInit(void);
void DBG(NSString *fmt, ...);

@interface DebugConsole : NSObject
+ (void)setup;
+ (void)log:(NSString *)line;
@end