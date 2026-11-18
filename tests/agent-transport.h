#import <Foundation/Foundation.h>
#include <stdatomic.h>

extern atomic_bool DPTestConnected;
NSTask *DPTestAgentTask(NSString *path);
void DPTestAgentRoundtrip(NSString *path, BOOL enabled);
