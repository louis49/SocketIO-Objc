//
//  SocketIO.h
//  SocketIO
//
//  Created by Desnos on 22/12/2014.
//  Copyright (c) 2014 Desnos. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "SocketIOTransport.h"

typedef void(^SocketIOCallback)(id argsData);

@class SocketIO;

@protocol SocketIODelegate <NSObject>
- (void) socketIODidConnect:(SocketIO *)socket;
- (void) socketIODidDisconnect:(SocketIO *)socket;
- (void) socketIO:(SocketIO *)socket didReceiveMessage:(id)data ack:(SocketIOCallback)function;
- (void) socketIO:(SocketIO *)socket didReceiveEvent:(NSString *)eventName data:(id)data ack:(SocketIOCallback)function;
- (void) socketIO:(SocketIO *)socket didReceiveError:(NSString *)error;
@end



@interface SocketIO : NSObject<SocketIOTransportDelegate>
-(id) initWithDelegate:(id<SocketIODelegate> )delegate
				  host:(NSString *)host
				  port:(NSInteger)port
			 namespace:(NSString *)nsp
			   timeout:(NSTimeInterval)connectionTimeout
			   secured:(BOOL)secured;
- (void) connect;
- (void) connectWithParams:(NSDictionary *)params;
- (void) disconnect;
- (void) sendMessage:(id)data;
- (void) sendMessage:(id)data ack:(SocketIOCallback)function;
- (void) sendEvent:(NSString *)eventName data:(id)data;
- (void) sendEvent:(NSString *)eventName data:(id)data ack:(SocketIOCallback)function;
- (BOOL) isConnected;
- (BOOL) isConnecting;
- (NSString *) nsp;
@end
