//
//  SocketIOTransportWebsocket.h
//  SocketIO
//
//  Created by Desnos on 23/12/2014.
//  Copyright (c) 2014 Desnos. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "SocketIOTransport.h"
#import "SRWebSocket.h"

@interface SocketIOTransportWebsocket : NSObject <SocketIOTransport, SRWebSocketDelegate>


@end
