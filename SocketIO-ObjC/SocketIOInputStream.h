//
//  SocketIOStream.h
//  SocketIO-ObjC
//
//  Created by Desnos on 20/01/2015.
//  Copyright (c) 2015 admin. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "SocketIO.h"



@class SocketIOInputStream;
@protocol SocketIOInputStreamDelegate <NSObject>
- (void) stream:(SocketIOInputStream*)stream didReceiveData:(NSData*)data;
- (void) streamDidFinish:(SocketIOInputStream*)stream;
@end

@class SocketIO;
typedef void(^SocketIOInputStreamCallback)(id argsData);
@interface SocketIOInputStream : NSObject

@property (assign, readonly) BOOL isFinished;
@property (weak) id<SocketIOInputStreamDelegate> delegate;
@property (copy,nonatomic) SocketIOInputStreamCallback callback;


-(id)initWithSocket:(SocketIO *)socket identifier:(NSString *)identifier;

-(void) readLength:(NSUInteger)len;
-(NSString *) identifier;
@end
