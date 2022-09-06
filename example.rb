require "./io_daemonizer"

class App
  def initialize
    sleep(1) # simulate slow startup
  end

  def shout(msg)
    msg.upcase
  end
end

IODaemonizer.wrap(
  port: 6872,
  setup: -> do
    @app = App.new # slow
  end,
  run: ->(args) do
    puts @app.shout(args.join(" ")) # fast
  end
)

IODaemonizer.wrap(
  port: 6872,
  setup: -> { @app = App.new },
  run: ->(args) do
    # DO NOT USE ARGV HERE - use args instead, which is how the daemon passes
    # the arguments it receives over the socket to the run block
    puts @app.shout(ARGV.join(" "))
  end
)
