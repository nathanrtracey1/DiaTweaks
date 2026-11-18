#import <Foundation/Foundation.h>

// The responder sends a newline-delimited frame back to the peer that sent the input.
// Returning nil consumes the input frame. Filters can safely respond after returning.
typedef void (^DPAgentReply)(NSDictionary *message);
typedef NSData * (^DPAgentFilter)(NSData *line, DPAgentReply reply);

void DPSetAgentFilters(NSString *key, DPAgentFilter requests, DPAgentFilter responses);

void DPInstallAgentTransport(void);

// Launch-only configuration belongs to the tweak; the transport keeps its socket private.
typedef NSDictionary<NSString *, NSString *> * (^DPAgentEnvironment)(NSString *directory, NSDictionary<NSString *, NSString *> *original);
typedef void (^DPAgentConnected)(NSString *directory);
void DPSetAgentEnvironment(DPAgentEnvironment configure);
void DPSetAgentConnected(DPAgentConnected connected);
