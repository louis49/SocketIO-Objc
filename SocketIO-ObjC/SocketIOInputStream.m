//
//  SocketIOStream.m
//  SocketIO-ObjC
//
//  Created by Desnos on 20/01/2015.
//  Copyright (c) 2015 admin. All rights reserved.
//

#import "SocketIOInputStream.h"

@interface SocketIOInputStream ()
@property (retain, nonatomic) SocketIO * _socket;
@property (retain, readonly) NSString * _identifier;
@end

@implementation SocketIOInputStream
@synthesize isFinished;
@synthesize delegate;
@synthesize _identifier;
@synthesize _socket;
@synthesize callback;

-(id)initWithSocket:(SocketIO *)socket identifier:(NSString *)identifier
{
	self = [super init];
	
	if(self)
	{
		_socket = socket;
		_identifier = identifier;
		isFinished = false;
	}

	return self;
}

-(void) readLength:(NSUInteger)len
{
	[_socket streamAskForData:_identifier length:len withCallback:^(id argsData)
	{
		[delegate stream:self didReceiveData:argsData];
	}];
}

-(NSString *) identifier
{
	return _identifier;
}


@end
