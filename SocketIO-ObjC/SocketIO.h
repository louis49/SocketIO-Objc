//
//  SocketIO.h
//  SocketIO
//
//  Created by Desnos on 22/12/2014.
//  Copyright (c) 2014 Desnos. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "SocketIOTransport.h"
#import "SocketIOInputStream.h"
#import "SocketIOOutputStream.h"

typedef void(^SocketIOCallback)(id argsData);

@class SocketIO, SocketIOInputStream;

@protocol SocketIODelegate <NSObject>
- (void) socketIODidConnect:(SocketIO *)socket;
- (void) socketIODidDisconnect:(SocketIO *)socket;
- (void) socketIO:(SocketIO *)socket didReceiveMessage:(id)data ack:(SocketIOCallback)function;
- (void) socketIO:(SocketIO *)socket didReceiveEvent:(NSString *)eventName data:(id)data extradata:(id)extradata ack:(SocketIOCallback)function;
- (void) socketIO:(SocketIO *)socket didReceiveStream:(SocketIOInputStream *)stream;
- (void) socketIO:(SocketIO *)socket didReceiveError:(NSString *)error;
@end


@class SocketIOOutputStream;
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
- (void) sendStream:(SocketIOOutputStream*)stream name:(NSString *)eventName extradata:(id)extradata;
- (void) sendStreams:(NSArray*)streams name:(NSString *)eventName extradata:(id)extradata;
- (BOOL) isConnected;
- (BOOL) isConnecting;
- (NSString *) nsp;
- (void) streamAskForData:(NSString *)key length:(NSUInteger)len withCallback:(SocketIOCallback)function;
- (void) stream:(NSString *)key sendData:(NSData *)data withCallback:(SocketIOCallback)function;
- (void) streamDidEnd:(NSString *)key;
@end
