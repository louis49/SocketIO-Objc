//
//  SocketIO.m
//  SocketIO
//
//  Created by Desnos on 22/12/2014.
//  Copyright (c) 2014 Desnos. All rights reserved.
//

#import "SocketIO.h"

#import <AFNetworking.h>

#import "SocketIOTransportWebsocket.h"

#import "SocketIOPacket.h"

#import <objc/runtime.h>

static NSString* kResourceName = @"socket.io";
static NSString* kTransportPolling = @"polling";
static NSString* kHandshakeURL = @"%@://%@%@/%@/1/?EIO=2&transport=%@&t=%.0f%@";

@interface SocketIO ()
{
	NSString * _host;
	NSInteger _port;
	BOOL _secured;
	
	NSString * _nsp;
	
	NSDictionary * _params;
	id<SocketIODelegate> _delegate;
	
	NSURLConnection *_handshake;
	NSString * _sid;
	
	NSTimeInterval _connectionTimeout;
	
	NSTimeInterval _pingInterval;
	NSTimeInterval _pingTimeout;
	
	id<SocketIOTransport> _transport;
	
	NSMutableDictionary *_acks;
	NSInteger _ackCount;
	
	NSInvocation * _dataInvocation;
	SocketIOPacket * _dataAckPacket;
	
	id _ackObject;
	SocketIOCallback _ackFunction;
	
	BOOL _connected;
	BOOL _connecting;
	
	NSMutableDictionary *_inputStreams;
	NSMutableDictionary *_outputStreams;
	
	NSMutableArray *_queue;
	
	dispatch_source_t _ping;
}
@end

@implementation SocketIO

-(id) initWithDelegate:(id<SocketIODelegate> )delegate
				  host:(NSString *)host
				  port:(NSInteger)port
			 namespace:(NSString *)nsp
			   timeout:(NSTimeInterval)connectionTimeout
			   secured:(BOOL)secured
{
	self = [super init];
	if (self)
		{
			_delegate = delegate;
			_acks = [[NSMutableDictionary alloc] init];
			_inputStreams = [[NSMutableDictionary alloc] init];
			_outputStreams = [[NSMutableDictionary alloc] init];
			_queue = [[NSMutableArray alloc] init];
			_connected = NO;
			_connecting = NO;
			_host = host;
			_port = port;
			_nsp = nsp;
			_connectionTimeout = connectionTimeout;
			_secured = secured;
			_ackCount = -1;
			_pingTimeout = 20;
		}
	return self;
}

- (void) connect
{
	[self connectWithParams:nil];
}

- (void) disconnect
{
	[_transport close];
}

- (void) connectWithParams:(NSDictionary *)params;
{
	_connecting = YES;
	_params = params;
	
	// On créé la query à partir des paramètres
	NSMutableString *query = [[NSMutableString alloc] initWithString:@""];
	[params enumerateKeysAndObjectsUsingBlock: ^(id key, id value, BOOL *stop) {
		[query appendFormat:@"&%@=%@", key, value];
	}];
	
	// On créé le protocole
	NSString *protocol = _secured ? @"https" : @"http";
	
	// L'heure à envoyer ???
	NSTimeInterval time = [[NSDate date] timeIntervalSince1970] * 1000;
	
	NSString *handshakeUrl = [NSString stringWithFormat:kHandshakeURL, protocol, _host, _port ? [NSString stringWithFormat:@":%li", (long)_port] : @"", kResourceName,kTransportPolling, time, query];
	
	AFHTTPRequestOperationManager * manager = [AFHTTPRequestOperationManager manager];
	
	[manager setResponseSerializer:[AFHTTPResponseSerializer serializer]];
	
	[manager GET:handshakeUrl
	  parameters:nil
		 success:^(AFHTTPRequestOperation *operation, id responseObject)
		{
			NSString *responseString = [[NSString alloc] initWithData:responseObject encoding:NSASCIIStringEncoding];
		
			responseString = [responseString substringFromIndex:[responseString rangeOfString:@"{"].location];
		
			[self parseHandshakeResponse:responseString];
		
			//NSLog(@"Success :%@", responseString);
		}
		 failure:^(AFHTTPRequestOperation *operation, NSError *error)
		{
			NSLog(@"Failure : %@", error);
		}];
}

- (void) parseHandshakeResponse:(NSString *)response
{
	NSDictionary *json = [NSJSONSerialization JSONObjectWithData:[response dataUsingEncoding:NSUTF8StringEncoding] options:NSJSONReadingAllowFragments error:nil];
	
	if([json valueForKey:@"sid"] != nil && [json valueForKey:@"upgrades"] != nil && [json valueForKey:@"pingInterval"] != nil && [json valueForKey:@"pingTimeout"] != nil)
	{
		_sid = [json objectForKey:@"sid"];
		_pingInterval = [[json objectForKey:@"pingInterval"] floatValue] / 1000;
		_pingTimeout = [[json objectForKey:@"pingTimeout"] floatValue] / 1000 ;
	
		NSArray *transports = [json objectForKey:@"upgrades"];
	
		if([transports indexOfObject:@"websocket"] != NSNotFound)
		{
			_transport = [[SocketIOTransportWebsocket alloc]initWithDelegate:self
																		host:_host
																		port:_port
																	 secured:_secured
																		 sid:_sid];
		
			[_transport open];
		}
	}
	
	
}

- (BOOL) isConnected
{
	return _connected;
}

- (BOOL) isConnecting
{
	return _connecting;
}

- (void) doQueue
{
	while ([_queue count] > 0)
	{
		if([[_queue objectAtIndex:0]isKindOfClass:SocketIOPacket.class])
		{
			SocketIOPacket *packet = [_queue objectAtIndex:0];
			[self sendPacket:packet];
			[_queue removeObject:packet];
		}
		else
		{
			NSData * data = [_queue objectAtIndex:0];
			[self sendData:data];
			[_queue removeObject:data];
		}

	}
}

#pragma mark NSData "Transform"

-(NSData *)eventToSend:(EngineIOType)type withData:(NSData *)data
{
	NSMutableData * out_data = [[NSMutableData alloc]init] ;
	
	UInt8 type_bytes[1];
	type_bytes[0] = (UInt8)type;
	
	UInt8 zero_bytes[1];
	zero_bytes[0] = (UInt8)0;
	
	NSData * type_data = [NSData dataWithBytes:type_bytes length:1];
	[out_data appendData:type_data];
	
	for(int i=0 ; i< data.length ; i++)
	{
		[out_data appendData:[data subdataWithRange:NSMakeRange(i, 1)]];
		[out_data appendData:[NSData dataWithBytes:zero_bytes length:1]];
	}
	
	return out_data;
}

-(NSData *)streamToSend:(EngineIOType)type withData:(NSData *)data
{
	NSMutableData * out_data = [[NSMutableData alloc]init] ;
	
	UInt8 type_bytes[1];
	type_bytes[0] = (UInt8)type;
	
	UInt8 zero_bytes[1];
	zero_bytes[0] = (UInt8)0;
	
	NSData * type_data = [NSData dataWithBytes:type_bytes length:1];
	[out_data appendData:type_data];
	
	for(int i=0 ; i< data.length ; i++)
		{
		[out_data appendData:[data subdataWithRange:NSMakeRange(i, 1)]];
		//[out_data appendData:[NSData dataWithBytes:zero_bytes length:1]];
		}
	
	return out_data;
}

# pragma mark Acknowledge methods

-(void)doDataAckPacket
{
	if([[_dataAckPacket eventTitle]isEqualToString:@"message"])
	{
		id data = [_dataAckPacket binary];
		NSInteger ack;
		if([_dataAckPacket packetId])
			ack =[[_dataAckPacket packetId] integerValue];
		else
			ack = -1;
		NSString * nsp = [_dataAckPacket nsp];
		_dataAckPacket = nil;
	
		if (ack>0)
		{
			[_delegate socketIO:self didReceiveMessage:data ack:^(id argsData)
			 {
				[self sendAck:ack andData:argsData onNSP:nsp];
			 }];
		}
		else
		{
			[_delegate socketIO:self didReceiveMessage:data ack:nil];
		}
	}
	else
	{
		NSString * title = [_dataAckPacket eventTitle];
		id data = [_dataAckPacket binary];
		id extra = [_dataAckPacket extra];
		NSInteger ack;
		if([_dataAckPacket packetId])
			ack =[[_dataAckPacket packetId] integerValue];
		else
			ack = -1;
		NSString * nsp = [_dataAckPacket nsp];
	
		_dataAckPacket = nil;
	
		if (ack >= 0)
		{
			[self didReceive:title content:data extraContent:extra ackFunction:^(id argsData) {
				[self sendAck:ack andData:argsData onNSP:nsp];
			}];
		}
		else
		{
			[self didReceive:title content:data extraContent:extra ackFunction:nil];
		}
	}
}

-(void)sendAck:(NSInteger)ack andData:(id)data onNSP:(NSString *)nsp
{
	if(data && [data isKindOfClass:NSData.class])
	{
		SocketIOPacket * packet = [[SocketIOPacket alloc]initWithEngineType:EngineIOTypeMessage socketType:SocketIOTypeBinaryAck];
		NSMutableArray *array = [NSMutableArray arrayWithObject:@{@"_placeholder": @"true", @"num":@0}];
		NSData * jsondata = [NSJSONSerialization dataWithJSONObject:array options:0 error:nil];
		NSMutableString * jsonString = [[NSMutableString alloc] initWithData:jsondata encoding:NSUTF8StringEncoding];

		//[jsonString replaceOccurrencesOfString:@"\"true\"" withString:@"true" options:0 range:NSMakeRange(0, jsonString.length)];
	
		[packet setPacketId:[NSString stringWithFormat:@"%i", ack]];
		[packet setData:jsonString];
		[packet setNsp:nsp];
		[packet setSocketType:SocketIOTypeBinaryAck];
		[self sendPacket:packet];
		[self sendData:[self eventToSend:EngineIOTypeMessage withData:data]];
	}
	else if ([data isKindOfClass:NSNull.class] )
	{
		SocketIOPacket * packet = [[SocketIOPacket alloc]initWithEngineType:EngineIOTypeMessage socketType:SocketIOTypeAck];
		[packet setPacketId:[NSString stringWithFormat:@"%i", ack]];
		[packet setNsp:self.nsp];
		[packet setData:@"[]"];
		[self sendPacket:packet];
	}
	else
	{
		SocketIOPacket * packet = [[SocketIOPacket alloc]initWithEngineType:EngineIOTypeMessage socketType:SocketIOTypeAck];
		[packet setNsp:nsp];
		[packet setPacketId:[NSString stringWithFormat:@"%i", ack]];
		NSData * jsondata = [NSJSONSerialization dataWithJSONObject:@[data] options:0 error:nil];
		NSString * jsonString = [[NSString alloc] initWithData:jsondata encoding:NSUTF8StringEncoding];
		[packet setData:jsonString];
		[self sendPacket:packet];
	}
}



- (NSString *) addAcknowledge:(SocketIOCallback)function
{
	if (function) {
		++_ackCount;
		NSString *ac = [NSString stringWithFormat:@"%ld", (long)_ackCount];
		[_acks setObject:[function copy] forKey:ac];
		return ac;
	}
	return nil;
}

- (void) removeAcknowledgeForKey:(NSString *)key
{
	[_acks removeObjectForKey:key];
}

#pragma mark SocketIOTransportDelegate

- (void) onConnect
{
	_connecting = NO;
	[self runPing];
	[self doQueue];
	[_delegate socketIODidConnect:self];
}

- (void) onData:(id)message
{
	
	
	
	if([message isKindOfClass:NSData.class])
	{
		NSLog(@"RECEIVING DATA FRAME");
		NSData * type = [message subdataWithRange:NSMakeRange(0, 1)];
		UInt8 * array = (UInt8 *) [type bytes];
		//NSInteger type_int = (NSInteger)array[0];
	
		//NSLog(@"TYPE : %i", type_int);
	
		NSData * data = [message subdataWithRange:NSMakeRange(1, [message length]-1)];
	
		if(_ackFunction != nil)
		{
			_ackFunction(data);
			_ackFunction = nil;
		}
		else
		{
			// Si on a pas déjà reçu l'entête de packet
			if(!_dataAckPacket)
			{
				// Mais on ne connait pas son type de contenu
				_dataAckPacket = [[SocketIOPacket alloc] initWithEngineType:EngineIOTypeMessage socketType:SocketIOTypeNone];
			
				// on lui affecte les données binaires qu'on vient de recevoir
				[_dataAckPacket setBinary:data];
			}
			else
			{
				[_dataAckPacket setBinary:data];
				[self doDataAckPacket];
			
			}
		}
	}
	else
	{
		NSLog(@"RECEIVING : %@", message);
		// Engine.io protocol
		// https://github.com/Automattic/engine.io-protocol
	
		//NSLog(@"Message : %@", message);
	
		NSUInteger type = [[NSString stringWithFormat:@"%c",[message characterAtIndex:0]] integerValue];
	
		NSString * data = [message substringFromIndex:1];
	
		switch (type)
		{
			case 0:
			//NSLog(@"Engine.io - OPEN : %@", data);
			[self parseEngineOPEN:data];
			break;
			case 1:
			//NSLog(@"Engine.io - CLOSE : %@", data);
			[self parseEngineCLOSE:data];
			break;
			case 2:
			//NSLog(@"Engine.io - PING : %@", data);
			[self parseEnginePING:data];
			break;
			case 3:
			//NSLog(@"Engine.io - PONG : %@", data);
			[self parseEnginePONG:data];
			break;
			case 4:
			//NSLog(@"Engine.io - MESSAGE : %@", data);
			[self parseEngineMESSAGE:data];
			break;
			case 5:
			//NSLog(@"Engine.io - UPGRADE : %@", data);
			[self parseEngineUPGRADE:data];
			break;
			case 6:
			//NSLog(@"Engine.io - NOOP : %@", data);
			[self parseEngineNOOP:data];
			break;
			default:
			break;
		}

	}
	
	
	
}

- (void) onDisconnect:(NSError*)error
{
	NSLog(@"TRANSPORT DISCONNECT");
	
	if(_connected == YES)
	{
		_connected = NO;
		_connecting = NO;
		[_delegate socketIODidDisconnect:self];
	}

}

- (void) onError:(NSError*)error
{
	NSLog(@"%@", error);
}

#pragma mark Engine.IO protocol

-(void) parseEngineOPEN:(NSString *)data
{
	NSLog(@"ENGINE.IO OPEN");
}

-(void) parseEngineCLOSE:(NSString *)data
{
	NSLog(@"ENGINE.IO DISCONNECT");
}

-(void) parseEnginePING:(NSString *)data
{
	NSLog(@"ENGINE.IO PING");
	SocketIOPacket *packet = [[SocketIOPacket alloc] initWithEngineType:EngineIOTypePong socketType:SocketIOTypeNone];
	[self sendPacket:packet];
}

-(void) parseEnginePONG:(NSString *)data
{
	//NSLog(@"ENGINE.IO PONG");
}

-(void) parseEngineMESSAGE:(NSString *)data
{
	_connecting = NO;
	// Socket.io protocol
	//https://github.com/automattic/socket.io-protocol
	
	NSUInteger type = [[NSString stringWithFormat:@"%c",[data characterAtIndex:0]] integerValue];
	
	NSString * newdata = [data substringFromIndex:1];
	
	switch (type)
	{
		case 0:
			//NSLog(@"Socket.io - CONNECT : %@", newdata);
			[self parseSocketCONNECT:newdata];
			break;
		case 1:
			//NSLog(@"Socket.io - DISCONNECT : %@", newdata);
			[self parseSocketDISCONNECT:newdata];
			break;
		case 2:
			//NSLog(@"Socket.io - EVENT : %@", newdata);
			[self parseSocketEVENT:newdata];
			break;
		case 3:
			//NSLog(@"Socket.io - ACK : %@", newdata);
			[self parseSocketACK:newdata];
			break;
		case 4:
			//NSLog(@"Socket.io - ERROR : %@", newdata);
			[self parseSocketERROR:newdata];
			break;
		case 5:
			//NSLog(@"Socket.io - BINARY_EVENT : %@", newdata);
			[self parseSocketBINARYEVENT:newdata];
			break;
		case 6:
			//NSLog(@"Socket.io - BINARY_ACK : %@", newdata);
			[self parseSocketBINARYACK:newdata];
			break;
		default:
			break;
	}
}

-(void) parseEngineUPGRADE:(NSString *)data
{
	
}

-(void) parseEngineNOOP:(NSString *)data
{
	
}

#pragma mark Socket.IO protocol

-(void) parseSocketCONNECT:(NSString *)data
{
	SocketIOPacket * packet = [[SocketIOPacket alloc]initWithEngineType:EngineIOTypeMessage socketType:SocketIOTypeConnect rawData:data];
	
	if(_nsp && ![[packet nsp] isEqualToString:_nsp])
		[self sendConnect];
	else
	{
		_connected = YES;
		_connecting = NO;
		[self onConnect];
	}
}

-(void) parseSocketDISCONNECT:(NSString *)data
{
	_connected = NO;
	_connecting = NO;
	NSLog(@"SOCKET.IO DISCONNECT");
	
	[_delegate socketIODidDisconnect:self];
}


-(void) parseSocketEVENT:(NSString *)data
{
	// Recherche du message
	NSString * message;
	NSRange start_message = [data rangeOfString:@"["];
	NSRange end_message = [data rangeOfString:@"]" options:NSBackwardsSearch];
	
	if (start_message.location != NSNotFound &&
		end_message.location != NSNotFound)
	{
		NSRange range_message = NSMakeRange(start_message.location, end_message.location - start_message.location + 1);
		
		message = [data substringWithRange:range_message];
	
		data = [data substringToIndex:start_message.location];
	}
	
	// Recherche du endpoint
	NSString * nsp;
	NSRange start_nsp = [data rangeOfString:@"/"];
	NSRange end_nsp = [data rangeOfString:@"," options:NSBackwardsSearch];
	
	if (start_nsp.location != NSNotFound &&
		end_nsp.location != NSNotFound)
	{
		NSRange range_message = NSMakeRange(start_nsp.location, end_nsp.location - start_nsp.location);
		
		nsp = [data substringWithRange:range_message];
		
		data = [data substringFromIndex:end_nsp.location+1];
	}
	
	// Recherche du ack
	NSInteger ack=-1;
	if(data.length>0)
		ack = [data integerValue];
	
	NSData * jsondata = [message dataUsingEncoding:NSUTF8StringEncoding];
	NSArray * array = [NSJSONSerialization JSONObjectWithData:jsondata options:NSJSONReadingMutableContainers error:nil];
	
	id title=nil;
	id content=nil;

	title = [array objectAtIndex:0];
	
	if([array count] == 2)
		content = [array objectAtIndex:1];
	else
	{
		NSMutableArray * arrayMut = [NSMutableArray arrayWithArray:array];
		[arrayMut removeObjectAtIndex:0];
		content = arrayMut;
	}
	
	if(ack >= 0)
		[self didReceive:title content:content extraContent:nil ackFunction:^(id argsData) {
			[self sendAck:ack andData:argsData onNSP:nsp];
		}];
	else
		[self didReceive:title content:content extraContent:nil ackFunction:nil];
	
}



-(void) parseSocketACK:(NSString *)data
{
	// Recherche du message
	NSString * message;
	NSRange start_message = [data rangeOfString:@"["];
	NSRange end_message = [data rangeOfString:@"]" options:NSBackwardsSearch];
	
	if (start_message.location != NSNotFound &&
		end_message.location != NSNotFound)
	{
		NSRange range_message = NSMakeRange(start_message.location, end_message.location - start_message.location + 1);
		
		message = [data substringWithRange:range_message];
		
		data = [data substringToIndex:start_message.location];
	}
	
	// Recherche du endpoint
	NSString * nsp;
	NSRange start_nsp = [data rangeOfString:@"/"];
	NSRange end_nsp = [data rangeOfString:@"," options:NSBackwardsSearch];
	if (start_nsp.location != NSNotFound &&
		end_nsp.location != NSNotFound)
	{
		NSRange range_message = NSMakeRange(start_nsp.location, end_nsp.location - start_nsp.location);
		
		nsp = [data substringWithRange:range_message];
		
		data = [data substringFromIndex:end_nsp.location+1];
	}
	
	// Recherche du ack
	NSInteger ack=-1;
	if(data.length>0)
		ack = [data integerValue];
	
	NSData * jsondata = [message dataUsingEncoding:NSUTF8StringEncoding];
	NSArray * array = [NSJSONSerialization JSONObjectWithData:jsondata options:NSJSONReadingMutableContainers error:nil];
	
	if(ack >= 0)
	{
		NSString *key = [NSString stringWithFormat:@"%i",ack];
	
		SocketIOCallback callbackFunction = [_acks objectForKey:key];
		if (callbackFunction != nil)
		{
			if([array count]>0)
				callbackFunction([array objectAtIndex:0]);
			else
				callbackFunction([NSNull null]);
			
			[self removeAcknowledgeForKey:key];
		}

	}
}

-(void) parseSocketERROR:(NSString *)data
{
	// Recherche du message
	NSString * message;
	NSRange start_message = [data rangeOfString:@"\""];
	NSRange end_message = [data rangeOfString:@"\"" options:NSBackwardsSearch];
	
	if (start_message.location != NSNotFound &&
		end_message.location != NSNotFound)
	{
		NSRange range_message = NSMakeRange(start_message.location+1, end_message.location - start_message.location - 1);
		
		message = [data substringWithRange:range_message];
		
		data = [data substringToIndex:start_message.location];
	}
	
	// Recherche du endpoint
	NSString * nsp;
	NSRange start_nsp = [data rangeOfString:@"/"];
	NSRange end_nsp = [data rangeOfString:@"," options:NSBackwardsSearch];
	if (start_nsp.location != NSNotFound &&
		end_nsp.location != NSNotFound)
	{
		NSRange range_message = NSMakeRange(start_nsp.location, end_nsp.location - start_nsp.location);
		
		nsp = [data substringWithRange:range_message];
		
		data = [data substringFromIndex:end_nsp.location+1];
	}

	[_delegate socketIO:self didReceiveError:message];
}

-(void) parseSocketBINARYEVENT:(NSString *)data
{
	data = [data substringFromIndex:1];
	
	// Recherche du message
	NSString * message;
	NSRange start_message = [data rangeOfString:@"["];
	NSRange end_message = [data rangeOfString:@"]" options:NSBackwardsSearch];
	
	if (start_message.location != NSNotFound &&
		end_message.location != NSNotFound)
	{
		NSRange range_message = NSMakeRange(start_message.location, end_message.location - start_message.location + 1);
		
		message = [data substringWithRange:range_message];
		
		data = [data substringToIndex:start_message.location];
	}
	
	// Recherche du endpoint
	NSString * nsp;
	NSRange start_nsp = [data rangeOfString:@"/"];
	NSRange end_nsp = [data rangeOfString:@"," options:NSBackwardsSearch];
	if (start_nsp.location != NSNotFound &&
		end_nsp.location != NSNotFound)
	{
		NSRange range_message = NSMakeRange(start_nsp.location, end_nsp.location - start_nsp.location);
		
		nsp = [data substringWithRange:range_message];
		
		data = [data substringFromIndex:end_nsp.location+1];
	}
	
	NSRange start_ack = [data rangeOfString:@"-"];
	
	if(start_ack.location != NSNotFound)
		data = [data substringFromIndex:start_ack.location + 1];
	
	// Recherche du ack
	NSInteger ack=-1;
	if(data.length>0)
		ack = [data integerValue];
	
	NSData * jsondata = [message dataUsingEncoding:NSUTF8StringEncoding];
	NSArray * array = [NSJSONSerialization JSONObjectWithData:jsondata options:NSJSONReadingAllowFragments error:nil];
	
	NSMutableArray * arrayMut = [NSMutableArray arrayWithArray:array];
	if([arrayMut count]>0)
		[arrayMut removeObjectAtIndex:0];
	
	
	// Si on a pas déjà reçu les binary du packet
	if(!_dataAckPacket)
	{
		// Mais on ne connait pas son type de contenu
		_dataAckPacket = [[SocketIOPacket alloc] initWithEngineType:EngineIOTypeMessage socketType:SocketIOTypeNone];
	
		[_dataAckPacket setNsp:nsp];
	
	
		if([array count] == 1)
			[_dataAckPacket setEventTitle:@"message"];
		else
			[_dataAckPacket setEventTitle:[array objectAtIndex:0]];
	
		[_dataAckPacket setExtra:arrayMut];
		// on lui affecte l'id de ack
		if(ack >= 0)
			[_dataAckPacket setPacketId:[NSString stringWithFormat:@"%i", ack]];
	}
	else
	{
		if([array count] == 1)
			[_dataAckPacket setEventTitle:@"message"];
		else
			[_dataAckPacket setEventTitle:[array objectAtIndex:0]];
	
		[_dataAckPacket setExtra:arrayMut];
	
		[_dataAckPacket setNsp:nsp];
	
		if(ack >= 0)
			[_dataAckPacket setPacketId:[NSString stringWithFormat:@"%i", ack]];
	
		[self doDataAckPacket];
	}
	//}
}

-(void) parseSocketBINARYACK:(NSString *)data
{
	//NSLog(@"%@", data);
	
	// Recherche du message
	NSString * message;
	NSRange start_message = [data rangeOfString:@"["];
	NSRange end_message = [data rangeOfString:@"]" options:NSBackwardsSearch];
	
	if (start_message.location != NSNotFound &&
		end_message.location != NSNotFound)
	{
		NSRange range_message = NSMakeRange(start_message.location, end_message.location - start_message.location + 1);
		
		message = [data substringWithRange:range_message];
		
		data = [data substringToIndex:start_message.location];
	}
	
	// Recherche du endpoint
	NSString * nsp;
	NSRange start_nsp = [data rangeOfString:@"/"];
	NSRange end_nsp = [data rangeOfString:@"," options:NSBackwardsSearch];
	if (start_nsp.location != NSNotFound &&
		end_nsp.location != NSNotFound)
	{
		NSRange range_message = NSMakeRange(start_nsp.location, end_nsp.location - start_nsp.location);
		
		nsp = [data substringWithRange:range_message];
		
		data = [data substringFromIndex:end_nsp.location+1];
	}
	
	// Recherche du ack
	NSInteger ack;
	
	NSRange start_ack = [data rangeOfString:@"-"];
	
	if(start_ack.location == NSNotFound)
		ack = [data integerValue];
	else
		ack = [[data substringFromIndex:start_ack.location+1] integerValue];
	
	if(ack >= 0)
	{
		NSString *key = [NSString stringWithFormat:@"%i",ack];
		
		SocketIOCallback callbackFunction = [_acks objectForKey:key];
		if (callbackFunction != nil)
		{
			_ackFunction = callbackFunction;
			[self removeAcknowledgeForKey:key];
		}
		
	}
}

#pragma mark SocketIO public
- (void) sendMessage:(id)data
{
	[self sendEvent:@"message" data:data];
}

- (void) sendMessage:(id)data ack:(SocketIOCallback)function
{
	[self sendEvent:@"message" data:data ack:function];
}

- (void) sendEvent:(NSString *)eventName data:(id)data
{
	[self sendEvent:eventName data:data ack:nil];
}

- (void) sendEvent:(NSString *)eventName data:(id)data ack:(SocketIOCallback)function
{
	NSMutableArray *array = [NSMutableArray arrayWithObject:eventName];
	
	SocketIOPacket *packet;
 
	if(data && ![data isKindOfClass:NSData.class])
	{
		packet = [[SocketIOPacket alloc]initWithEngineType:EngineIOTypeMessage socketType:SocketIOTypeEvent];
		[array addObject:data];
		
	}
	else if(data && [data isKindOfClass:NSData.class])
	{
		packet = [[SocketIOPacket alloc]initWithEngineType:EngineIOTypeMessage socketType:SocketIOTypeBinaryEvent];
		[array addObject:@{@"_placeholder": @"true", @"num":@0}];
	}
	else
	{
		packet = [[SocketIOPacket alloc]initWithEngineType:EngineIOTypeMessage socketType:SocketIOTypeEvent];
	}
	
	NSString * jsonString = [[NSString alloc] initWithData:[NSJSONSerialization dataWithJSONObject:array options:0 error:nil] encoding:NSUTF8StringEncoding];
	
	
	[packet setNsp:_nsp];
	[packet setData:jsonString];
	[packet setPacketId:[self addAcknowledge:function]];
	
	//if(data && [data isKindOfClass:NSData.class])
	//	[packet setPacketId:@"0"];
	
	[self sendPacket:packet];
	
	if(data && [data isKindOfClass:NSData.class])
	   [self sendData:[self eventToSend:EngineIOTypeMessage withData:data]];
}

- (void) sendStream:(SocketIOOutputStream*)stream name:(NSString *)eventName extradata:(id)extradata
{
	[_outputStreams setObject:stream forKey:[stream identifier]];
	
	SocketIOPacket *packet = [[SocketIOPacket alloc]initWithEngineType:EngineIOTypeMessage socketType:SocketIOTypeStream];
	[packet setValues:@[eventName,@[[NSNumber numberWithInteger:0]], [stream identifier]]];
	[packet setEventTitle:@"$stream"];
	[self sendPacket:packet];
}

- (void) sendStreams:(NSArray*)streams name:(NSString *)eventName extradata:(id)extradata
{
	NSMutableArray * indexes = [NSMutableArray new];
	NSMutableArray * values = [NSMutableArray new];
	[values addObject:eventName];
	[values addObject:indexes];
	
	NSInteger index = 0;
	for(SocketIOOutputStream * stream in streams)
	{
		[_outputStreams setObject:stream forKey:[stream identifier]];
		[indexes addObject:[NSNumber numberWithInteger:index]];
		[values addObject:[stream identifier]];
		index ++;
	}

	
	
	SocketIOPacket *packet = [[SocketIOPacket alloc]initWithEngineType:EngineIOTypeMessage socketType:SocketIOTypeStream];
	[packet setValues:values];
	[packet setNsp:self.nsp];
	[packet setEventTitle:@"$stream"];
	[self sendPacket:packet];
}

- (void) sendPacket:(SocketIOPacket *)packet
{
	NSString *req = [packet toString];
	
	if([_transport isReady])
	{
		NSLog(@"  SENDING : %@", req);
		[_transport send:req];
	}
	else
		[_queue addObject:packet];
	
}

- (void) sendData:(NSData *)data
{
	
	if([_transport isReady])
	{
		NSLog(@"  SENDING DATA %i bytes", [data length]);
		[_transport send:data];
	}
	else
		[_queue addObject:data];
}

- (void) sendConnect
{
	SocketIOPacket *packet = [[SocketIOPacket alloc] initWithEngineType:EngineIOTypeMessage socketType:SocketIOTypeConnect];
	[packet setNsp:_nsp];
	[self sendPacket:packet];
}

#pragma mark Getters

- (NSString *) nsp
{
	return _nsp;
}

#pragma mark Ping

-(void) sendPing
{
	SocketIOPacket *packet = [[SocketIOPacket alloc] initWithEngineType:EngineIOTypePing socketType:SocketIOTypeNone];
	[self sendPacket:packet];
}

- (void) runPing
{
	if (_ping)
	{
		dispatch_source_cancel(_ping);
		_ping = NULL;
	}
	
	_ping = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER,
										0,
										0,
										dispatch_get_main_queue());
	
	dispatch_source_set_timer(_ping,
							  dispatch_time(DISPATCH_TIME_NOW, DISPATCH_TIME_NOW),
							  _pingTimeout * NSEC_PER_SEC,
							  0);
	
	__weak SocketIO *weakSelf = self;
	
	dispatch_source_set_event_handler(_ping, ^{
		[weakSelf sendPing];
	});
	
	dispatch_resume(_ping);
}

#pragma mark delegates call

-(void)didReceive:(id)title
		  content:(id)content
	 extraContent:(id)extraContent
	  ackFunction:(SocketIOCallback)function
{
	if([title isEqualToString:@"$stream"])
	{
		[self didReceiveStream:content withCallback:function];
	}
	else if([title isEqualToString:@"$stream-read"])
	{
		[self didReceiveStreamRead:[content objectAtIndex:0] length:[[content objectAtIndex:1] integerValue] withCallback:function];
	}
	else if([title isEqualToString:@"$stream-write"])
	{
		[self didReceiveStreamData:content extra:extraContent withCallback:function];
	}
	else if([title isEqualToString:@"$stream-end"])
	{
		[self didReceiveStreamEnd:content withCallback:function];
	}
	else if([title isEqualToString:@"$stream-error"])
	{
		NSLog(@"ERROR : %@", content);
	}
	else
	{
		if(content)
		{
			[_delegate socketIO:self didReceiveEvent:title data:content extradata:extraContent ack:function];
		}
		else
		{
			[_delegate socketIO:self didReceiveMessage:title ack:function];
		}
	}

}

#pragma mark Stream analyze

-(void)didReceiveStreamRead:(NSString *)key length:(NSUInteger)len withCallback:(SocketIOInputStreamCallback)function
{
	SocketIOOutputStream * stream = ((SocketIOOutputStream *)[_outputStreams objectForKey:key]);
	
	[[stream delegate]stream:stream askData:len];
	
}

-(void)didReceiveStreamEnd:(NSString *)key withCallback:(SocketIOCallback)function
{
	SocketIOInputStream * stream = ((SocketIOInputStream *)[_inputStreams objectForKey:key]);
	[[stream delegate]streamDidFinish:stream];
	[_inputStreams removeObjectForKey:key];
}

-(void)didReceiveStreamData:(NSData *)streamdata extra:(id)extra withCallback:(SocketIOCallback)function
{
	NSLog(@"STREAM WRITE");
	
	SocketIOInputStream * stream = ((SocketIOInputStream *)[_inputStreams objectForKey:[extra objectAtIndex:0]]);
	
	SocketIOInputStreamCallback cb = [stream callback];
	
	cb(streamdata);
	
	function([NSNull null]);
}

-(void)didReceiveStream:(NSArray *)streamarray withCallback:(SocketIOCallback)function
{
	NSString * title;
	id data;
	NSArray * indexes;
	NSMutableArray * streamKeys = [NSMutableArray new];
	
	if([streamarray count]>0 && [[streamarray objectAtIndex:0]isKindOfClass:NSString.class])
	{
		title = [streamarray objectAtIndex:0];
		if([streamarray count]>1 && [[streamarray objectAtIndex:1]isKindOfClass:NSArray.class])
			indexes = [streamarray objectAtIndex:1];
	}
	else
	{
		NSAssert(![[streamarray objectAtIndex:0]isKindOfClass:NSString.class], @"Error : Did you give a name to emit ?");
	}
	
	
	for(NSNumber * index in indexes)
	{
		[streamKeys addObject:[streamarray objectAtIndex:[index intValue]+2]];
	}
	
	if(indexes && [streamarray objectAtIndex:[[indexes lastObject] intValue]+2])
		data = [streamarray objectAtIndex:[[indexes lastObject] intValue]+2];
	

	for(NSString * key in streamKeys)
	{
		SocketIOInputStream * stream = [[SocketIOInputStream alloc]initWithSocket:self identifier:key];
		[_inputStreams setObject:stream forKey:key];
		[_delegate socketIO:self didReceiveStream:stream];
	}


}

- (void) streamAskForData:(NSString *)key length:(NSUInteger)len withCallback:(SocketIOInputStreamCallback)function
{
	SocketIOInputStream * stream = ((SocketIOInputStream *)[_inputStreams objectForKey:key]);
	[stream setCallback:function];
	
	SocketIOPacket *packet = [[SocketIOPacket alloc]initWithEngineType:EngineIOTypeMessage socketType:SocketIOTypeStream];
	[packet setValues:@[key, [NSNumber numberWithInteger:len]]];
	[packet setNsp:self.nsp];
	[packet setEventTitle:@"$stream-read"];
	[self sendPacket:packet];
}

- (void) stream:(NSString *)key sendData:(NSData *)data withCallback:(SocketIOCallback)function
{
	SocketIOPacket *packet = [[SocketIOPacket alloc]initWithEngineType:EngineIOTypeMessage socketType:SocketIOTypeStream];
	
	[packet setValues:@[key, @{@"_placeholder":[NSNumber numberWithBool:YES], @"num":@0}, @"buffer"]];
	[packet setEventTitle:@"$stream-write"];
	[packet setPacketId:[self addAcknowledge:function]];
	[packet setNsp:self.nsp];
	[self sendPacket:packet];
	[self sendData:[self streamToSend:EngineIOTypeMessage withData:data]];
}

- (void) streamDidEnd:(NSString *)key
{
	SocketIOPacket *packet = [[SocketIOPacket alloc]initWithEngineType:EngineIOTypeMessage socketType:SocketIOTypeStream];
	[packet setValues:@[key]];
	[packet setNsp:self.nsp];
	[packet setEventTitle:@"$stream-end"];
	[self sendPacket:packet];
	
	[_outputStreams removeObjectForKey:key];
}


@end
