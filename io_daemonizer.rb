# io_daemonizer v.3 https://github.com/joeyschoblaska/io_daemonizer

require "shellwords"
require "socket"
require "stringio"

class IODaemonizer
  PORT = ENV["IO_DAEMONIZER_PORT"] || 5289

  def self.wrap(setup: -> {}, run: -> {})
    case ARGV[0]
    when "start"
      puts "starting server..."
      Daemon.run(setup: setup, run: run)
    when "stop"
      puts "stopping server..."
      send_request(ARGV)
    else
      send_request(ARGV)
    end
  rescue Errno::ECONNREFUSED
    puts "server not running or not responding"
  end

  def self.send_request(args)
    TCPSocket.open("127.0.0.1", PORT) do |socket|
      socket.puts args.shelljoin
      socket.write $stdin.tty? ? "" : $stdin.read
      socket.close_write
      STDOUT.write(socket.read(4096)) until socket.eof?
    end
  end

  def self.redirect(stdin: $stdin, stdout: $stdout, stderr: $stderr)
    oldin, oldout, olderr = $stdin.dup, $stdout.dup, $stderr.dup
    $stdin, $stdout, $stderr = stdin, stdout, stderr

    yield
  ensure
    $stdin, $stdout, $stderr = oldin, oldout, olderr
  end

  class Daemon
    def self.run(setup: -> {}, run: -> {})
      daemon = new(setup: setup, run: run)
      daemon.setup
      daemon.start
    end

    def initialize(setup: -> {}, run: -> {})
      @setup = setup
      @run = run
      @context = Object.new
    end

    def setup
      @context.instance_exec &@setup
    end

    def start
      @server = TCPServer.open("127.0.0.1", PORT)
      Process.daemon(true)
      read_socket(@server.accept) until @server.closed?
    end

    private

    def read_socket(socket)
      raw_args, *body = socket.read.lines
      args = raw_args.shellsplit

      if args[0] == "stop"
        @server.close
      else
        IODaemonizer.redirect(
          stdin: StringIO.new(body.join),
          stdout: socket,
          stderr: socket
        ) { @context.instance_exec args, &@run }
      end
    rescue => e
      socket.write e.inspect
    ensure
      socket.close
    end
  end
end
