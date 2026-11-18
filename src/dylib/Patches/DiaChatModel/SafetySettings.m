#import "Providers.h"

extern DPPatch DPDiaChatModel, DPDiaChatSafety;
void DPApplyDiaChatModel(DPPatch *);

NSDictionary *DPSelectedSafetyProvider(void) { return @{ @"api": DPDiaChatSafety.on ? @"enabled" : @"disabled" }; }
static void DPSafetyChanged(DPPatch *patch) { DPApplyDiaChatModel(&DPDiaChatModel); }

DP_PATCH(DPDiaChatSafety) {
    .key = @"diaChatSafety", .order = 105, .defaultOn = YES,
    .title = @"Safety Check",
    .detail = @"Automatically review tool calls before they run.",
    .symbol = @"checkmark.shield", .tint = @"systemPurpleColor", .requires = @"diaChatModel", .apply = DPSafetyChanged,
};
