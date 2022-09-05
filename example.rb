require "./io_daemonizer"

class App
  def initialize
    sleep(1) # simulate slow startup
  end

  def say(msg)
    msg.reverse
  end
end

IODaemonizer.wrap(
  setup: -> do
    @app = App.new # slow
  end,
  run: ->(args) do
    puts @app.say(args.join(" ")) # fast
  end
)
