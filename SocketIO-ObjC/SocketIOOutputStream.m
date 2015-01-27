//
//  SocketIOOutputStream.m
//  SocketIO-ObjC
//
//  Created by Desnos on 21/01/2015.
//  Copyright (c) 2015 admin. All rights reserved.
//

#import "SocketIOOutputStream.h"

@interface SocketIOOutputStream ()
@property (retain, nonatomic) SocketIO * _socket;
@property (retain, readonly) NSString * _identifier;
@end

@implementation SocketIOOutputStream
@synthesize _socket;
@synthesize _identifier;
@synthesize isFinished;
@synthesize delegate;


-(id)initWithSocket:(SocketIO *)socket
{
	self = [super init];
	
	if(self)
	{
		_socket = socket;
		isFinished = false;
		_identifier = [self UUID];
	}
	
	return self;
}

-(void) close
{
	[_socket streamDidEnd:_identifier];
}

-(void) write:(NSData *)data
{
	[_socket stream:_identifier sendData:data withCallback:^(id argsData)
	{
		//NSLog(@"CB : %@", argsData);
	}];
}

-(NSString *) identifier
{
	return _identifier;
}


-(NSString *)UUID
{
	NSString * uuid = @"00000000-0000-4000-8000-000000000000";
	
	NSMutableString * newuuid= [NSMutableString new];
	
	[uuid enumerateSubstringsInRange:NSMakeRange(0, [uuid length]) options:NSStringEnumerationByComposedCharacterSequences usingBlock:^(NSString *substring, NSRange substringRange, NSRange enclosingRange, BOOL *stop)
	{
		if([substring isEqualToString:@"0"])
			[newuuid appendString:[[NSString alloc] initWithFormat:@"%x", (int)(arc4random_uniform(15)+1)]];
		else if([substring isEqualToString:@"8"])
			[newuuid appendString:[[NSString alloc] initWithFormat:@"%x", (int)(arc4random_uniform(4)+8)]];
		else
			[newuuid appendString:substring];
	}];
	
	return newuuid;
}

@end
