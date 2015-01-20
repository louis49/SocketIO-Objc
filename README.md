# Socket.IO / Objective C Library

** This version only support Socket.io v1.X.X **

Support Features : 
* Ack
* Binary Data
* Binary Ack
* Namespace

run "Server" Target then SocketIO-ObjC-Exemple to run some test usage methods

Inspired by : 
* [github.com/francoisp/socket.IO-objc](https://github.com/francoisp/socket.IO-objc)

## Usage

The easiest way to connect to your Socket.IO / node.js server is

``` objective-c
SocketIO * socketGlobal = [[SocketIO alloc] initWithDelegate:self host:@"localhost" port:8080 namespace:nil timeout:1000 secured:NO];
[socketGlobal connect];
```

You can use Namespace : 
``` objective-c
SocketIO * socketPublic = [[SocketIO alloc] initWithDelegate:self host:@"localhost" port:8080 namespace:@"/public" timeout:1000 secured:NO];
[socketPublic connect];
```

You can send extra-data during connexion : 
``` objective-c
SocketIO * socketPrivate = [[SocketIO alloc] initWithDelegate:self host:@"localhost" port:8080 namespace:@"/private" timeout:1000 secured:NO];
[socketPrivate connectWithParams:@{@"login": @"fail"}];
```

Sending Data : 
``` objective-c
- (void) sendMessage:(id)data;
- (void) sendMessage:(id)data ack:(SocketIOCallback)function;
- (void) sendEvent:(NSString *)eventName data:(id)data;
- (void) sendEvent:(NSString *)eventName data:(id)data ack:(SocketIOCallback)function;
```
"(id)data" can be NSString, NSData, NSArray, NSDictionnary

Receiving Data : 
``` objective-c
- (void) socketIO:(SocketIO *)socket didReceiveMessage:(id)data ack:(SocketIOCallback)function;
- (void) socketIO:(SocketIO *)socket didReceiveEvent:(NSString *)eventName data:(id)data ack:(SocketIOCallback)function;
```
if "ack" is not nil you can answer to the server with a binary or simple ack: 
``` objective-c
function([@"Binary Ack" dataUsingEncoding:NSASCIIStringEncoding]);
OR
function(@"Simple Ack");
```
