#pragma once
#import <Foundation/Foundation.h>
#import "Settings.h"

@interface Preset : NSObject
@property (nonatomic, copy)   NSString *pid;
@property (nonatomic, copy)   NSString *name;
@property (nonatomic, assign) NSTimeInterval created;
@property (nonatomic, assign) NSTimeInterval modified;
@property (nonatomic, strong) NSDictionary *data;

+ (instancetype)fromDict:(NSDictionary *)d;
- (NSDictionary *)toDict;
- (NSDictionary *)toExportDict;
+ (instancetype)fromExportDict:(NSDictionary *)d;
@end

@interface Presets : NSObject
+ (instancetype)shared;
- (NSArray<Preset *> *)all;
- (NSString *)activeId;
- (Preset *)active;
- (void)setActiveId:(NSString *)pid;
- (Preset *)createFromCurrent:(NSString *)name;
- (void)apply:(Preset *)p;
- (void)applyActive;
- (void)syncCurrent;
- (void)rename:(Preset *)p name:(NSString *)newName;
- (void)remove:(Preset *)p;
- (NSString *)exportString:(Preset *)p;
- (Preset *)importString:(NSString *)s error:(NSString **)err;
@end