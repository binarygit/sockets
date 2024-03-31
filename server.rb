require 'socket'

one_mb = 1_000_000
one_kb = 1024

case ARGV.pop
when 'nblock'
  # This server uses non-blocking reading/writing methods
  Socket.tcp_server_loop(4000) do |connection|
    # Simplest way to read data from the connection.
    loop do
      begin
        puts connection.read_nonblock(one_mb)
      rescue Errno::EAGAIN
        retry
      rescue EOFError
        break
      end
    end

    puts 'okay closed'

    # Close the connection once we're done reading. Lets the client
    # know that they can stop waiting for us to write something back.
    connection.close
  end
when 'block'
  # This server uses only blocking reading/writing methods
  Socket.tcp_server_loop(4000) do |connection|
    # Simplest way to read data from the connection.
    while data = connection.gets
      puts data
      connection.write "Now you see me!\n"
    end
    puts 'okay closed'

    # Close the connection once we're done reading. Lets the client
    # know that they can stop waiting for us to write something back.
    connection.close
  end
when 'http'
  # This is my first HTTP server implementation.
  RESPONSE_STATUS_CODES = {
    200 => '200 OK',
    404 => '404 NOT FOUND'
  }

  def response(status:, data:)
    <<~RESPONSE
    HTTP/1.1 #{RESPONSE_STATUS_CODES[status]}
    Server: Avi Server
    Etag: avi-avi
    Date: #{Time.now.utc.strftime '%a, %d %b %Y %H:%M:%S UTC'}

    #{data}
    RESPONSE
  end

  def handle(connection)
    # Simplest way to read data from the connection.
    request = connection.readpartial(10000)
    file_content = nil
    status = nil

    root = '/home/kali/Documents/articles/'
    file_name = request.split("\n").first.split[1]
    # This is useful to print when using the preforked server.
    #p "Process #{Process.pid} request: #{file_name}, time: #{Time.now}" 
    file_name = 'index.html' if file_name == '/'
    file_name = root + file_name

    if File.exist? file_name
      # Create delay in request processing.
      sleep 6
      file_content = File.read(file_name)
      status = 200
    else
      status = 404
    end

    connection.write response(data: file_content, status: status)
    # I am closing the socket on all instances of this socket by using shutdown(2).
    # There are two instances of the socket, first one in the parent
    # process the second, here, in the child process.
    #
    # When shutdown is not used the socket never closes in the
    # parent process which hangs the browser.
    connection.close_write

    # Close the connection once we're done reading. Lets the client
    # know that they can stop waiting for us to write something back.
    connection.close
  end

  # Server Processes request serially
  def serial_server
    Socket.tcp_server_loop(3000) do |connection|
      handle(connection)
    end
  end

  def process_per_connection_server
    Socket.tcp_server_loop(3000) do |connection|
      pid = fork do
        handle(connection)
      end

      Process.detach(pid)
    end
  end

  # note: Socket(connection) must be local inside each thread because
  # in threads local variables are shared.
  def thread_per_connection_server
    trap(:INT) { exit }

    Socket.tcp_server_loop(3000) do |connection|
      Thread.abort_on_exception = true

      Thread.new do
        handle(connection)
      end
    end
  end

  class PreforkedServer
    CONCURRENCY = 4

    def initialize
      @control_socket = TCPServer.new(3000)
      trap(:INT) { exit }
    end

    def run
      child_pids = []

      CONCURRENCY.times do
        child_pids << spawn_child
      end

      trap(:INT) {
        child_pids.each do |cpid|
          begin
            Process.kill(:INT, cpid)
          rescue Errno::ESRCH
          end
        end

        exit
      }

      # The parent's process role is only to spawn new child processes
      # when one of them unexpectedly exits.
      loop do
        pid = Process.wait
        $stderr.puts "#{pid} exited unexpectedly" 

        child_pids.delete(pid)
        child_pids << spawn_child
      end
    end

    def spawn_child
      fork { handle_connection }
    end

    def handle_connection
      # accept(2) is blocking.
      # Without this loop each process would exit because
      # after the connection is closed there's no more code to run.
      loop do
        connection = @control_socket.accept
        handle(connection)
      end
    end
  end

  # Just because I can spawn 25 threads at once doesn't mean that
  # the requests are serviced faster.
  # A greater time spent on blocking I/O by my code means that this server's
  # performance is better than the preforked server because this server
  # uses way less resources.
  class ThreadPoolServer
    CONCURRENCY = 25

    def initialize
      @control_socket = TCPServer.new(3000)
      trap(:INT) { exit }
    end

    def run
      Thread.abort_on_exception = true
      threads = ThreadGroup.new

      CONCURRENCY.times do
        threads.add spawn_thread
      end

      sleep
    end

    def spawn_thread
      Thread.new do
        loop do
          connection = @control_socket.accept
          handle(connection)
        end
      end
    end
  end

  #serial_server
  #process_per_connection_server
  #thread_per_connection_server
  #PreforkedServer.new.run
  ThreadPoolServer.new.run
end



