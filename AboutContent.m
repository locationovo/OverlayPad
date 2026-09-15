#import "AboutContent.h"

#ifndef APP_VERSION
#define APP_VERSION "v0.0.0-unknown"
#endif

NSString *AboutName(void) { return @"locationovo"; }

NSString *AboutVersion(void) {
    return @APP_VERSION;
}

NSArray *AboutLines(void) {
    return @[
        @{ @"en": @"Add a virtual gamepad to your game or app",
           @"zh": @"为你的游戏或应用添加虚拟手柄" },
        @{ @"en": @"github.com/locationovo/OverlayPad",
           @"zh": @"项目地址:github.com/locationovo/OverlayPad" },
        @{ @"en": @"Feedback and contributions welcome",
           @"zh": @"欢迎反馈与贡献" },
    ];
}