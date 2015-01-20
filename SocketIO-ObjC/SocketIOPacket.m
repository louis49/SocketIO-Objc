//
//  SocketIOPacket.m
//  SocketIO
//
//  Created by Desnos on 23/12/2014.
//  Copyright (c) 2014 Desnos. All rights reserved.
//

#import "SocketIOPacket.h"

@interface SocketIOPacket()
{

}
@end

@implementation SocketIOPacket
@synthesize engineType, socketType, data, nsp, packetId, binary, eventTitle, eventData;

- (id) initWithEngineType:(EngineIOType) _engineType socketType:(SocketIOType)_socketType
{
	self = [self init];
	if (self)
	{
		self.engineType = _engineType;
		self.socketType = _socketType;
	}
	return self;
}

- (id) initWithEngineType:(EngineIOType) _engineType socketType:(SocketIOType)_socketType rawData:(NSString*)rawdata
{
	self = [self initWithEngineType:_engineType socketType:_socketType];
	if (self)
	{
		[self parseRawData:rawdata];
	}
	return self;
}

-(void)parseRawData:(NSString *)rawdata
{
	if([rawdata hasPrefix:@"/"])
	{
		nsp = rawdata;
	}
}


- (NSString *) toString
{
	NSMutableArray * array = [NSMutableArray new];
	
	// EngineIO Type
	[array addObject:[NSString stringWithFormat:@"%@",[NSNumber numberWithInteger:engineType]]];
	
	if(socketType != SocketIOTypeNone)
	{
		// SocketIO Type
		[array addObject:[NSString stringWithFormat:@"%@",[NSNumber numberWithInteger:socketType]]];
	
		if(nsp && socketType != SocketIOTypeBinaryEvent && socketType != SocketIOTypeBinaryAck)
			[array addObject:[NSString stringWithFormat:@"%@,",nsp]];
		else if(nsp && socketType == SocketIOTypeBinaryEvent)
			[array addObject:[NSString stringWithFormat:@"1-%@,",nsp]];
		else if(nsp && socketType == SocketIOTypeBinaryAck)
			[array addObject:[NSString stringWithFormat:@"1-%@,",nsp]];
		else if(!nsp && socketType == SocketIOTypeBinaryAck)
			[array addObject:[NSString stringWithFormat:@"1-"]];
		/*else
			[array addObject:@"-"];*/

		if(packetId)
			[array addObject:[NSString stringWithFormat:@"%@", packetId]];
	
		if(data)
			[array addObject:[NSString stringWithFormat:@"%@",data]];
	}
	
	NSString * string = [array componentsJoinedByString:@""];
	
	return string;
}

@end
