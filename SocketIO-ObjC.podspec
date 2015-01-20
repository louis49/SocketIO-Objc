Pod::Spec.new do |s|
s.name     = 'SocketIO-ObjC'
s.version  = '1.0'
s.platform = :ios, '7.0'
s.summary  = 'socket.io iOS devices.'
s.author   = { 'DESNOS Benoît' => 'desnos.benoit@gmail.com' }
s.source_files = 'SocketIO-ObjC/*.{h,m}'
s.requires_arc = true
s.dependency 'SocketRocket'
s.dependency 'AFNetworking'
end