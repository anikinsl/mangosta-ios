//
//  XMPPMUCLight.h
//  Mangosta
//
//  Created by Andres on 5/30/16.
//  Copyright © 2016 Inaka. All rights reserved.
//

#import <XMPPFramework/XMPPFramework.h>

@interface XMPPMUCLight : XMPPModule {
	XMPPIDTracker *xmppIDTracker;
	NSMutableSet *rooms;
}

- (BOOL)discoverRoomsForServiceNamed:(NSString *)serviceName;

@end

@protocol XMPPMUCLightDelegate

- (void)xmppMUCLight:(XMPPMUCLight *)sender didDiscoverRooms:(NSArray *)rooms forServiceNamed:(NSString *)serviceName;
- (void)xmppMUCLight:(XMPPMUCLight *)sender failedToDiscoverRoomsForServiceNamed:(NSString *)serviceName withError:(NSError *)error;

@end
