require 'socket'

module Avi
  class Client
    class << self
      attr_accessor :host, :port
    end

    def self.get(key)
      request "GET #{key}"
    end
    def self.set(key, val)
      request "SET #{key} #{val}"
    end

    private

    def self.request(string)
      @client = TCPSocket.new(host, port)

      # Send EOF after writing the request.
      @client.write string

      @client.close_write
      p @client.read
    end

  end
end

Avi::Client.port = 4000
Avi::Client.host = 'localhost'

Avi::Client.set 'name', 'avi'
Avi::Client.get 'name'
Avi::Client.set 'name', 'bvi'
Avi::Client.get 'name'
