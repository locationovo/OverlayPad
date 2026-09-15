#import "Localization.h"

static LangMode gMode = LangAuto;

static BOOL sysZh(void) {
    static BOOL zh;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        NSString *lang = [NSLocale preferredLanguages].firstObject ?: @"en";
        zh = [lang hasPrefix:@"zh"];
    });
    return zh;
}

void LangSetMode(LangMode m) { gMode = m; }
LangMode LangGetMode(void) { return gMode; }

NSString *L(NSString *en, NSString *zh) {
    if (gMode == LangEn) return en ?: @"";
    if (gMode == LangZh) return zh ?: en ?: @"";
    return sysZh() ? (zh ?: en ?: @"") : (en ?: @"");
}

NSString *LangName(LangMode m) {
    if (m == LangEn) return @"English";
    if (m == LangZh) return @"中文";
    return L(@"Auto", @"跟随系统");
}