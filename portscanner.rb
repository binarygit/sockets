#!/usr/bin/ruby
require 'debug'
require 'socket'

=begin
Basic steps:

 Go to google.com
 try to connect to ports
 when a part successfully connects
 add the port number to the array
 and then close the connection.

=end

=begin

  This is my first implementation. It's limitations are that
  the socket connecting code is blocking. Hence this takes a long
  time to complete.

  ports = 1..100
  connected_ports = []

  ports.each do |port|
    p "Starting for port #{port}"
    socket = TCPSocket.new 'google.com', port, connect_timeout: 2
    socket.write 'GET /'
    connected_ports << port
    p "Port #{port} connected successfully"
  rescue IO::TimeoutError
  end

  p connected_ports

=end

ports = 1..200

sockets = ports.map do |port|
  socket = Socket.new(:INET, :STREAM)
  remote_addr = Socket.sockaddr_in(port, 'archive.org')
  socket.connect_nonblock(remote_addr)
rescue Errno::EINPROGRESS 
  socket
end

while sockets.length > 0
  begin
    # It'll take a long time for this script to complete if
    # the 5 sec timeout is not specified here.
    writeable_sockets = IO.select(nil, sockets, nil, 5)
    break unless writeable_sockets
    writeable_sockets[1].each do |socket|
      begin 
        socket.connect_nonblock(socket.remote_address)
      rescue Errno::ENOTCONN
        # This error is raised when a socket is not
        # connected successfully. One of the reasons could be
        # because there's no socket listening at the specified
        # port.
        sockets.delete(socket)
      rescue Errno::EISCONN
        puts "Successfully connected at #{socket.remote_address.ip_port}"
        sockets.delete(socket)
      end
    end
  end
end

# Taken from documentation of connect_nonblock
# This will get the HTML from the server!
#socket.write("GET / HTTP/1.0\r\n\r\n")
#p socket.read
