var app = require('express')();
var server = require('http').Server(app)
var io = require('socket.io')(server);
//require('socket.io-stream')(io);
var Server = require('./Server');
// On lance l'écoute du port 
server.listen(8080);

console.log ( "Server running on port :", io.httpServer.address().port);

io.of('/private').use(Server.auth).on('connection', Server.connect);
io.of('/public').on('connection', Server.connect);
io.on('connection', Server.connect);