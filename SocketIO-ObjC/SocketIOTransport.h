//
//  SocketIOTransport.h
//  SocketIO
//
//  Created by Desnos on 23/12/2014.
//  Copyright (c) 2014 Desnos. All rights reserved.
//

#import <Foundation/Foundation.h>

@protocol SocketIOTransportDelegate <NSObject>
- (void) onData:(id)message;
- (void) onConnect;
- (void) onDisconnect:(NSString*)error;
- (void) onError:(NSError*)error;
@end

@protocol SocketIOTransport <NSObject>
@required
-(id) initWithDelegate:(id<SocketIOTransportDelegate> )delegate
				  host:(NSString *)host
				  port:(NSInteger)port
			   secured:(BOOL)secured
				   sid:(NSString *)sid;
- (void) open;
- (void) close;
- (void) send:(id)request;
- (BOOL) isReady;
@end
