//
//  SocketIOTransportWebsocket.m
//  SocketIO
//
//  Created by Desnos on 23/12/2014.
//  Copyright (c) 2014 Desnos. All rights reserved.
//

#import "SocketIOTransportWebsocket.h"

static NSString* kTransportURL = @"%@://%@:%i/socket.io/1/websocket/?EIO=2&transport=websocket&sid=%@";
//ws://localhost:8080/socket.io/1/websocket/?EIO=2&transport=websocket&sid=gRao3w-VFGF2mhMAAAAB

@interface SocketIOTransportWebsocket ()
{
	id <SocketIOTransportDelegate> _delegate;
	SRWebSocket *_webSocket;
	
	NSString * _host;
	NSInteger _port;
	BOOL _secured;
	NSString * _sid;
}
@end

@implementation SocketIOTransportWebsocket

-(id) initWithDelegate:(id<SocketIOTransportDelegate> )delegate
				  host:(NSString *)host
				  port:(NSInteger)port
			   secured:(BOOL)secured
				   sid:(NSString *)sid
{
	self = [super init];
	if (self) {
		_delegate = delegate;
		_host = host;
		_port = port;
		_secured = secured;
		_sid = sid;
	}
	return self;
}

- (void) close
{
	[_webSocket close];
}
- (void) open
{
	//static NSString* kTransportURL = @"%@://%@:%@/socket.io/1/websocket/?EIO=2&transport=websocket&sid=%@";
	//ws://localhost:8080/socket.io/1/websocket/?EIO=2&transport=websocket&sid=gRao3w-VFGF2mhMAAAAB
	
	NSString * url = [NSString stringWithFormat:kTransportURL,_secured?@"wss":@"ws", _host, _port, _sid];
	_webSocket = [[SRWebSocket alloc] initWithURL:[NSURL URLWithString:url]];
	
	[_webSocket setDelegate:self];
	
	[_webSocket open];
}

- (void) send:(id)request
{
	[_webSocket send:request];
}

- (BOOL) isReady
{
	return _webSocket.readyState == SR_OPEN;
}

#pragma mark SRWebSocketDelegate

- (void)webSocket:(SRWebSocket *)webSocket didReceiveMessage:(id)message
{
	//NSLog(@"didReceiveMessage : %@", message);
	
	[_delegate onData:message];
}

- (void)webSocketDidOpen:(SRWebSocket *)webSocket
{
	//NSLog(@"webSocketDidOpen");
	
	[webSocket send:@"5"];
}

- (void)webSocket:(SRWebSocket *)webSocket didFailWithError:(NSError *)error
{
	NSLog(@"didFailWithError : %@", error);
	[_delegate onDisconnect:@"erreur"];
}

- (void)webSocket:(SRWebSocket *)webSocket didCloseWithCode:(NSInteger)code reason:(NSString *)reason wasClean:(BOOL)wasClean
{
	NSLog(@"didCloseWithCode : %@", reason);
	
	[_delegate onDisconnect:reason];
}




@end
