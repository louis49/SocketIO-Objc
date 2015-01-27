//
//  SocketIOPacket.h
//  SocketIO
//
//  Created by Desnos on 23/12/2014.
//  Copyright (c) 2014 Desnos. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef enum {
	EngineIOTypeOpen,
	EngineIOTypeClose,
	EngineIOTypePing,
	EngineIOTypePong,
	EngineIOTypeMessage,
	EngineIOTypeUpgrade,
	EngineIOTypeNoop
} EngineIOType;

typedef enum {
	SocketIOTypeConnect,
	SocketIOTypeDisconnect,
	SocketIOTypeEvent,
	SocketIOTypeAck,
	SocketIOTypeError,
	SocketIOTypeBinaryEvent,
	SocketIOTypeBinaryAck,
	SocketIOTypeNone,
	SocketIOTypeStream
} SocketIOType;

@interface SocketIOPacket : NSObject
{
	
	
}
@property (assign, nonatomic) EngineIOType engineType;
@property (assign, nonatomic) SocketIOType socketType;
@property (strong, nonatomic) NSString * eventTitle;
@property (strong, nonatomic) NSString * eventData;
@property (strong, nonatomic) NSString * data;
@property (strong, nonatomic) NSData * binary;
@property (strong, nonatomic) id extra;
@property (strong, nonatomic) NSString * nsp;
@property (strong, nonatomic) NSString *packetId;
@property (strong, nonatomic) NSArray * values;
- (id) initWithEngineType:(EngineIOType) _engineType socketType:(SocketIOType)_socketType;
- (id) initWithEngineType:(EngineIOType) _engineType socketType:(SocketIOType)_socketType rawData:(NSString*)rawdata;
- (NSString *) toString;

@end
