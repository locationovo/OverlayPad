#pragma once
#import <GameController/GameController.h>

@interface InputState : NSObject
+ (instancetype)shared;
- (void)setStickX:(float)x y:(float)y;
- (void)snapshotStickX:(float *)x y:(float *)y;
- (void)effectiveStickX:(float *)x y:(float *)y;
- (void)setElement:(NSString *)eid pressed:(BOOL)pressed;
- (BOOL)isElementPressed:(NSString *)eid;
- (void)toggleElement:(NSString *)eid;
- (void)reset;
@end

@interface Input : NSObject
+ (void)installHook;
+ (void)bindPad:(GCExtendedGamepad *)pad;
@end