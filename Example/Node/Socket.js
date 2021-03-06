var Socket = module.exports;
var fs = require('fs');
var ss = require('socket.io-stream');

var assert = function(condition, message) {
	if (!condition)
		throw Error("Assert failed" + (typeof message !== "undefined" ? ": " + message : ""));
};

Socket.receiveStream = function(stream1, stream2, data)
{
	stream1.pipe(fs.createWriteStream('pix2.png'));
	if(stream2)
		stream2.pipe(fs.createWriteStream('google2.png'));
}

Socket.sendStream = function(data, func)
{
	var streamA = ss.createStream();
	var streamB = ss.createStream();
	var filenameA = '../Browser/Pix.png';
	var filenameB = '../Browser/google.png';
	
	if(data.variation === 'A')
		ss(this).emit('Send Stream', streamA, {name: filenameA});
	else if(data.variation === 'B')
		ss(this).emit('Send Stream', streamA);
	else if(data.variation === 'C')
		ss(this).emit('Send Stream', streamA, streamB);
	else if(data.variation === 'D')
		ss(this).emit('Send Stream', streamA, streamB, [{name: filenameA}, {name: filenameB}]);
	fs.createReadStream(filenameA).pipe(streamA);
	
	if(data.variation === 'C' || data.variation === 'D')
		fs.createReadStream(filenameB).pipe(streamB);
}



Socket.message = function(message, func)
{
	if(func)
	{
		if(message === 'MessageWithAck')
			func('Simple Ack');
		else if(message === 'MessageWithBinaryAck')
			func(new Buffer('Binary Ack', 'binary'));
	}
}

Socket.eventWithNoAckAndTable = function(data)
{
	assert(data[0].var00);
	assert(data[0].var00 === 'value00');
	assert(data[0].var01);
	assert(data[0].var01 === 'value01');
	assert(data[1].var10);
	assert(data[1].var10 === 'value10');
	assert(data[1].var11);
	assert(data[1].var11 === 'value11');
}

Socket.eventWithNoAckAndDic = function(data)
{
	assert(data.var00);
	assert(data.var00 === 'value00');
	assert(data.var01);
	assert(data.var01 === 'value01');
}

Socket.eventWithSimpleAckAndDic = function(data, func)
{
	assert(data.var00);
	assert(data.var00 === 'value00');
	assert(data.var01);
	assert(data.var01 === 'value01');
	assert(func);
	func('Simple Ack');
}

Socket.eventWithBinaryAckAndDic = function(data, func)
{
	assert(data.var00);
	assert(data.var00 === 'value00');
	assert(data.var01);
	assert(data.var01 === 'value01');
	assert(func);
	func(new Buffer("Binary Ack", 'binary'));
}

Socket.eventAskSimpleEventWithNoAck = function(data, func)
{
	this.emit('SimpleEventWithNoAck', "Simple event");
}

Socket.eventAskBinaryEventWithNoAck = function(data, func)
{
	this.emit('BinaryEventWithNoAck', new Buffer("Binary event", 'binary'));
}

Socket.eventAskSimpleEventWithSimpleAck = function(data, func)
{
	this.emit('SimpleEventWithSimpleAck', "Simple event", function(ack)
	{
		assert(typeof ack === 'string');
		assert(ack === 'Simple Ack');
	});
}

Socket.eventAskSimpleEventWithBinaryAck = function(data, func)
{
	this.emit('SimpleEventWithBinaryAck', "Simple event", function(ack)
	{
		assert(stringFromBinary(ack) === 'Binary Ack');
		assert(typeof ack === 'object');
	});
}

Socket.eventAskBinaryEventWithSimpleAck = function(data, func)
{
	this.emit('BinaryEventWithSimpleAck', new Buffer("Binary event", 'binary'), function(ack)
	{
		assert(typeof ack === 'string');
		assert(ack === 'Simple Ack');
	});
}

Socket.eventAskBinaryEventWithBinaryAck = function(data, func)
{
	this.emit('BinaryEventWithBinaryAck', new Buffer("Binary event", 'binary'), function(ack)
	{
		assert(typeof ack === 'object');
		assert(stringFromBinary(ack) === 'Binary Ack');
	});
}

Socket.binaryMessageWithNoAck = function(data, func)
{
	this.emit(new Buffer("Binary message", 'binary'));
}

Socket.binaryMessageWithBinaryAck = function(data, func)
{
	this.emit(new Buffer("Binary message", 'binary'), function(ack)
	{
		assert(typeof ack === 'object');
		assert(stringFromBinary(ack) === 'Binary Ack');
	});
}


Socket.disconnect = function(func)
{
	console.log ( "Client Disconnected :", this.client.conn.remoteAddress);
	
	for (var id in this.server.of('/').connected)
	{
		console.log( "Send disconnect from :", this.id, 'to :', id);
		this.server.of('/').connected[id].client.server.emit('disconnect',{'from':this.id});
	};
}

function stringFromBinary(arrayBuffer)
{
	var binaryString = '';
var bytes = new Uint8Array(arrayBuffer);
	var length = bytes.length;
	for (var i = 0; i < length/2; i++)
	{
		binaryString += String.fromCharCode(bytes[i*2]);
	}
	return binaryString;
}
