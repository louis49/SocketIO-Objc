//
//  BDViewController.h
//  SocketIO-ObjC
//
//  Created by admin on 01/20/2015.
//  Copyright (c) 2014 admin. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <SocketIO.h>
#import "SocketIOInputStream.h" 
#import "SocketIOOutputStream.h"

@interface BDViewController : UIViewController<SocketIODelegate, SocketIOInputStreamDelegate, SocketIOOutputStreamDelegate>

@end
