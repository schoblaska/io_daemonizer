ENV["IO_DAEMONIZER_PORT"] = "6872" # set before loading IO Daemonizer

require "./io_daemonizer"

class App
  def initialize
    sleep(1) # simulate slow startup
  end

  def shout(msg)
    msg.upcast
  end
end

IODaemonizer.wrap(
  setup: -> do
    @app = App.new # slow
  end,
  run: ->(args) do
    puts @app.shout(args.join(" ")) # fast
  end
)
