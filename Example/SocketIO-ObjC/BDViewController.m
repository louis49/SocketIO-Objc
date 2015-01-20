//
//  BDViewController.m
//  SocketIO-ObjC
//
//  Created by admin on 01/20/2015.
//  Copyright (c) 2014 admin. All rights reserved.
//

#import "BDViewController.h"

@interface BDViewController ()

@end

@implementation BDViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
	
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
	//NSLog(@"didReceiveMessage");
	
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


- (void) socketIO:(SocketIO *)socket didReceiveEvent:(NSString *) eventName data:(id) data ack:(SocketIOCallback) function
{
	//NSLog(@"didReceiveEvent");
	
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



- (void) socketIODidConnect:(SocketIO *)socket
{
	if(![socket nsp])
		{
		NSLog(@"CONNECTED ON ROOT NSP");
		}
	
	
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
