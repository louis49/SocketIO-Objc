//
//  BDViewController.m
//  SocketIO-ObjC
//
//  Created by admin on 01/20/2015.
//  Copyright (c) 2014 admin. All rights reserved.
//

#import "BDViewController.h"

@interface BDViewController ()
{
	NSMutableDictionary *_streamsData;
	
	NSData * data1ToSend;
	NSUInteger index1Data;
	NSString * data1Indentifier;
	
	NSData * data2ToSend;
	NSUInteger index2Data;
	NSString * data2Indentifier;
}

@end

@implementation BDViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
	
	_streamsData = [NSMutableDictionary new];
	
	data1ToSend = [[NSFileManager defaultManager] contentsAtPath:[[NSBundle mainBundle] pathForResource:@"Pix" ofType:@"png"]];
	index1Data = 0;
	
	data2ToSend = [[NSFileManager defaultManager] contentsAtPath:[[NSBundle mainBundle] pathForResource:@"Google" ofType:@"png"]];
	index2Data = 0;
	
	
	SocketIO * socketGlobal = [[SocketIO alloc] initWithDelegate:self host:@"localhost" port:8080 namespace:nil timeout:1000 secured:NO];
	[socketGlobal connect];
	
	
	SocketIO * socketPublic = [[SocketIO alloc] initWithDelegate:self host:@"localhost" port:8080 namespace:@"/public" timeout:1000 secured:NO];
	[socketPublic connect];
	
	
	SocketIO * socketPrivate = [[SocketIO alloc] initWithDelegate:self host:@"localhost" port:8080 namespace:@"/private" timeout:1000 secured:NO];
	[socketPrivate connectWithParams:@{@"login": @"fail"}];
	
}

- (void) socketIODidDisconnect:(SocketIO *)socket
{
	NSLog(@"Disconnect");
}
- (void) socketIO:(SocketIO *)socket didReceiveMessage:(id)data ack:(SocketIOCallback)function
{
	NSLog(@"didReceiveMessage");
	
	if([data isKindOfClass:NSData.class])
	{
		NSAssert([[[NSString alloc]initWithData:data encoding:NSASCIIStringEncoding] isEqualToString:@"Binary message"], @"Binary message");
	}
	else
	{
		NSAssert([data isEqualToString:@"Simple Message"], @"Simple message");
	}
	
	if(function)
	{
		function([@"Binary Ack" dataUsingEncoding:NSASCIIStringEncoding]);
	}
	
}


- (void) socketIO:(SocketIO *)socket didReceiveEvent:(NSString *) eventName data:(id)data extradata:(id)extradata ack:(SocketIOCallback) function
{
	NSLog(@"didReceiveEvent");
	
	
	if([eventName isEqualToString:@"SimpleEventWithNoAck"])
	{
		NSAssert([data isKindOfClass:NSString.class], @"Simple Event NSString");
		NSAssert([data  isEqualToString:@"Simple event"], @"Simple event");
		NSAssert(!function , @"Nil ack");
	}
	else if([eventName isEqualToString:@"BinaryEventWithNoAck"])
	{
		NSAssert([data isKindOfClass:NSData.class], @"Binary Event NSData");
		NSAssert([[[NSString alloc]initWithData:data encoding:NSASCIIStringEncoding] isEqualToString:@"Binary event"], @"Binary event");
		NSAssert(!function , @"Nil ack");
	}
	else if([eventName isEqualToString:@"SimpleEventWithSimpleAck"])
	{
		NSAssert(function, @"ack");
		function(@"Simple Ack");
	}
	else if([eventName isEqualToString:@"SimpleEventWithBinaryAck"])
	{
		NSAssert(function, @"ack");
		function([@"Binary Ack" dataUsingEncoding:NSASCIIStringEncoding]);
	}
	else if([eventName isEqualToString:@"BinaryEventWithSimpleAck"])
	{
		NSAssert(function, @"ack");
		function(@"Simple Ack");
	}
	else if([eventName isEqualToString:@"BinaryEventWithBinaryAck"])
	{
		NSAssert(function, @"ack");
		function([@"Binary Ack" dataUsingEncoding:NSASCIIStringEncoding]);
	}
}

- (void) socketIO:(SocketIO *)socket didReceiveStream:(SocketIOInputStream *)stream
{
	[stream setDelegate:self];
	[_streamsData setObject:[NSMutableData new] forKey:[stream identifier]];
	if (![stream isFinished])
	{
		[stream readLength:1024];
	}
}

- (void) stream:(SocketIOInputStream*)stream didReceiveData:(NSData*)data
{
	NSLog(@"DATA %i", [data length]);
	
	[[_streamsData objectForKey:[stream identifier]] appendData:data];
	
	if (![stream isFinished])
	{
		[stream readLength:1024];
	}
}

- (void) streamDidFinish:(SocketIOInputStream*)stream
{
	NSData * data = [_streamsData objectForKey:[stream identifier]];
	UIImage * image = [UIImage imageWithData:data];
	NSLog(@"FINISH");
}

- (void) stream:(SocketIOOutputStream*)stream askData:(NSUInteger)length
{
	if([[stream identifier]isEqualToString:data1Indentifier])
	{
		if((index1Data + length) <= data1ToSend.length)
			[stream write:[data1ToSend subdataWithRange:NSMakeRange(index1Data, length)]];
		else if(index1Data < data1ToSend.length)
			[stream write:[data1ToSend subdataWithRange:NSMakeRange(index1Data, data1ToSend.length - index1Data)]];
		else
			[stream close];
	
		index1Data = index1Data + length;
	}
	else
	{
		if((index2Data + length) <= data2ToSend.length)
			[stream write:[data2ToSend subdataWithRange:NSMakeRange(index2Data, length)]];
		else if(index2Data < data2ToSend.length)
			[stream write:[data2ToSend subdataWithRange:NSMakeRange(index2Data, data2ToSend.length - index2Data)]];
		else
			[stream close];
	
		index2Data = index2Data + length;
	}

}

- (void) socketIODidConnect:(SocketIO *)socket
{
	if(![socket nsp])
	{
		NSLog(@"CONNECTED ON ROOT NSP");
	}
	
	
	
	SocketIOOutputStream * stream1 = [[SocketIOOutputStream alloc] initWithSocket:socket];
	[stream1 setDelegate:self];
	data1Indentifier = [stream1 identifier];
	
	SocketIOOutputStream * stream2 = [[SocketIOOutputStream alloc] initWithSocket:socket];
	[stream2 setDelegate:self];
	data2Indentifier = [stream2 identifier];
	
	[socket sendStreams:@[stream1, stream2]  name:@"Send Stream" extradata:nil];
	
	[socket sendEvent:@"EventAskSendStream" data:@{@"variation": @"A"}];

	
	
	
	[socket sendMessage:@"MessageWithNoAck"];
	
	[socket sendMessage:@"MessageWithAck" ack:^(id argsData)
	 {
		NSAssert([argsData isKindOfClass:NSString.class], @"Simple ACK String");
		NSAssert([argsData isEqualToString:@"Simple Ack"], @"Simple ACK");
	 }];
	
	
	[socket sendMessage:@"MessageWithBinaryAck" ack:^(id argsData)
	 {
		NSAssert([argsData isKindOfClass:NSData.class], @"Binary ACK NSData");
		NSAssert([[[NSString alloc]initWithData:argsData encoding:NSASCIIStringEncoding] isEqualToString:@"Binary Ack"], @"Binary ACK");
	 }];
	
	
	[socket sendEvent:@"EventWithNoAckAndTable" data:@[@{@"var00": @"value00", @"var01":@"value01"}, @{@"var10": @"value10", @"var11":@"value11"}]];
	
	[socket sendEvent:@"EventWithNoAckAndDic" data:@{@"var00": @"value00", @"var01":@"value01"}];
	
	
	
	[socket sendEvent:@"EventWithSimpleAckAndDic" data:@{@"var00": @"value00", @"var01":@"value01"} ack:^(id argsData)
	 {
		NSAssert([argsData isKindOfClass:NSString.class], @"Simple ACK String");
		NSAssert([argsData isEqualToString:@"Simple Ack"], @"Simple ACK");
	 }];
	
	
	[socket sendEvent:@"EventWithBinaryAckAndDic" data:@{@"var00": @"value00", @"var01":@"value01"} ack:^(id argsData)
	 {
		NSAssert([argsData isKindOfClass:NSData.class], @"Binary ACK NSData");
		NSAssert([[[NSString alloc]initWithData:argsData encoding:NSASCIIStringEncoding] isEqualToString:@"Binary Ack"], @"Binary ACK");
	 }];
	
	
	
	[socket sendEvent:@"EventAskSimpleEventWithNoAck" data:@{@"var00": @"value00", @"var01":@"value01"}];
	[socket sendEvent:@"EventAskBinaryEventWithNoAck" data:@{@"var00": @"value00", @"var01":@"value01"}];
	[socket sendEvent:@"EventAskSimpleEventWithSimpleAck" data:@{@"var00": @"value00", @"var01":@"value01"}];
	[socket sendEvent:@"EventAskSimpleEventWithBinaryAck" data:@{@"var00": @"value00", @"var01":@"value01"}];
	[socket sendEvent:@"EventAskBinaryEventWithSimpleAck" data:@{@"var00": @"value00", @"var01":@"value01"}];
	[socket sendEvent:@"EventAskBinaryEventWithBinaryAck" data:@{@"var00": @"value00", @"var01":@"value01"}];
	
	[socket sendEvent:@"EventAskBinaryMessageWithNoAck" data:@{@"var00": @"value00", @"var01":@"value01"}];
	[socket sendEvent:@"EventAskBinaryMessageWithBinaryAck" data:@{@"var00": @"value00", @"var01":@"value01"}];
	 
}

- (void) socketIO:(SocketIO *)socket didReceiveError:(NSString *)error
{
	NSAssert([error isEqualToString:@"unauthorized"], @"Auth");
	[socket connectWithParams:@{@"login": @"hello"}];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

@end
