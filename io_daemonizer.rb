# io_daemonizer v.5 https://github.com/joeyschoblaska/io_daemonizer

require "json"
require "shellwords"
require "socket"
require "stringio"

class IODaemonizer
  def self.wrap(port:, setup:, run:, autostart: true)
    case ARGV[0]
    when "start"
      puts "starting server..."
      Daemon.run(port: port, setup: setup, run: run)
    when "stop"
      puts "stopping server..."
      send_request(port: port, args: ARGV)
    else
      begin
        send_request(port: port, args: ARGV)
      rescue Errno::ECONNREFUSED => e
        raise(e) unless autostart
        daemon = Daemon.new(port: port, setup: setup, run: run)
        daemon.setup
        fork { daemon.start }
        sleep 0.1
        send_request(port: port, args: ARGV)
      end
    end
  rescue Errno::ECONNREFUSED
    puts "server not running or not responding"
  end

  def self.send_request(port:, args:)
    consumer = LabeledIOConsumer.new

    TCPSocket.open("127.0.0.1", port) do |socket|
      socket.puts args.shelljoin
      socket.write $stdin.tty? ? "" : $stdin.read
      socket.close_write

      consumer.write(socket.read) until socket.eof?
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
    def self.run(port:, setup:, run:)
      daemon = new(port: port, setup: setup, run: run)
      daemon.setup
      daemon.start
    end

    def initialize(port:, setup:, run:)
      @port = port
      @setup = setup
      @run = run
      @context = Object.new
    end

    def setup
      @context.instance_exec &@setup
    end

    def start
      @server = TCPServer.open("127.0.0.1", @port)
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
          stdout: IOLabeler.new(1, socket, "stdout"),
          stderr: IOLabeler.new(2, socket, "stderr"),
        ) { @context.instance_exec args, &@run }
      end
    rescue => e
      socket.write e.inspect
      raise e
    ensure
      socket.close_write
      socket.close
    end
  end

  class IOLabeler < IO
    attr_reader :label

    def initialize(fd, socket, label)
      super(fd)
      @socket = socket
      @label = label
    end

    def write(chunk)
      @socket.write({@label => chunk}.to_json)
    end

    def reopen(io)
      @label = io&.label || @label
    end
  end

  class LabeledIOConsumer
    def initialize
      @buffer = ""
    end

    def write(chunk)
      chunk.chars.each do |ch|
        @buffer << ch
        process_buffer
      end
    end

    private

    def process_buffer
      parsed = JSON.parse(@buffer)
      key = parsed.keys[0]
      value = parsed.values[0]

      case key
      when "stdout"
        $stdout.write(value)
      when "stderr"
        $stderr.write(value)
      end

      @buffer = ""
    rescue JSON::ParserError
    end
  end
end
