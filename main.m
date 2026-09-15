#import <UIKit/UIKit.h>
#import "Common.h"
#import "HUD.h"
#import "Injector.h"
#import "Style.h"
#import "DebugConsole.h"

__attribute__((constructor))
static void boot(void) {
    DBGInit();
    DBG(@"boot: SkinRegAll start");
    SkinRegAll();
    DBG(@"boot: joyStyles=%lu btnStyles=%lu",
        (unsigned long)[Skin joyStyles].count,
        (unsigned long)[Skin btnStyles].count);
    dispatch_async(dispatch_get_main_queue(), ^{
        [DebugConsole setup];
        [Injector setup];
        [HUD setup];
        DBG(@"boot done");
    });
}