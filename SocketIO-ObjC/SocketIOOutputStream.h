//
//  SocketIOOutputStream.h
//  SocketIO-ObjC
//
//  Created by Desnos on 21/01/2015.
//  Copyright (c) 2015 admin. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "SocketIO.h"

@class SocketIOOutputStream;
@protocol SocketIOOutputStreamDelegate <NSObject>
- (void) stream:(id)stream askData:(NSUInteger)length;
- (void) streamDidFinish:(id)stream;
@end

@class SocketIO;
typedef void(^SocketIOOutputStreamCallback)(id argsData);
@interface SocketIOOutputStream : NSObject
@property (assign, readonly) BOOL isFinished;
@property (weak) id<SocketIOOutputStreamDelegate> delegate;
@property (copy,nonatomic) SocketIOOutputStreamCallback callback;

-(id)initWithSocket:(SocketIO *)socket;

-(void) close;
-(void) write:(NSData *)data;
-(NSString *) identifier;
-(NSString *)UUID;
@end
