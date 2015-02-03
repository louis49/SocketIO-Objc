var io = require('socket.io-client');
var fs = require('browserify-fs');
var ss = require('socket.io-stream');

var socket = io.connect('http://localhost:8080/public', {'transports':['websocket']});

socket.on('connect', function ()
{
	socket.emit('EventAskSendStream', {'variation': 'A'});
});

var newtream = function()
{
	var stream = ss.createStream();
	ss(socket).emit('Send Stream', stream, {name: 'kiki'});
	fs.createReadStream('/google.png').pipe(stream);
}

ss(socket).on('Send Stream', function(stream, data)
{
	console.log(data);

	stream.pipe(fs.createWriteStream('/pix.png'));
			  
	var stream = ss.createStream();
	ss(socket).emit('Send Stream', stream);
	fs.createReadStream('/pix.png').pipe(stream);

});
