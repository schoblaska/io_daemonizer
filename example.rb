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
