#!/usr/bin/ruby
require 'debug'
require 'socket'

module Avi
  class Server
    def initialize(port)
      @server = TCPServer.new(port)
      puts "Listening on #{port}"
      @storage = {}
    end

    def start
      Socket.accept_loop(@server) do |connection|
        @request = connection.read
        connection.write process_request
        connection.close
      end
    end

    private

    def process_request
      command, key, value = @request.split

      case command.upcase
      when 'GET'
        @storage[key]
      when 'SET'
        @storage[key] = value
      end
    end
  end
end

server = Avi::Server.new(4000)
server.start
