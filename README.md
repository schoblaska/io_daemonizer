# IO Daemonizer
Wrap a Ruby script that speaks IO (STDIO only for now; see roadmap) in a daemon so that you only pay the startup overhead once.

Inspired by and largely stolen from [fohte/rubocop-daemon](https://github.com/fohte/rubocop-daemon).

## Example
A Ruby script that involves some expensive setup:

```ruby
class App
  def initialize
    sleep(1) # simulate slow startup; load dependencies, etc
  end

  def shout(msg)
    msg.upcase # simulate something useful
  end
end

app = App.new # slow; does the same thing each run
puts app.shout(ARGV.join(" ")) # fast; does something different each run
```

If we're calling this script frequently, we don't want to pay the cost of `App.new` each time.

```
$ time ruby example.rb hello
HELLO
real    0m1.089s

$ time ruby example.rb there
THERE
real    0m1.089s
```

Instead, IO Daemonizer can wrap the setup step and the run step separately:

```ruby
require "io_daemonizer"

class App
  # ...
end

IODaemonizer.wrap(
  {
    setup: -> do
      @app = App.new # slow
    end,
    run: ->(args) do # ARGV will be passed to run block as `args`
      puts @app.shout(args.join(" ")) # fast
    end
  }
)
```

Now we can call our script with `start` to perform the expensive setup step once and store the state in a background process. Subsequent calls to our script will run in a new process that communicates with the daemon over a TCP socket. The daemon redirects stdio through the socket connection and the client prints any messages it receives.

```
$ time ruby example.rb start
starting server...
real    0m1.088s

$ time ruby example.rb hello
HELLO
real    0m0.081s

$ time ruby example.rb there
THERE
real    0m0.067s
```

## Installation
IO Daemonizer is packaged as a gem, but it has no dependencies outside the core library and you may find it more convenient to include `io_daemonizer.rb` in your project directly. It needs to be loaded with each call to your script, so the less overhead the better.

## Usage
### Defining your setup and run blocks
Both the setup and run blocks are stored in variables inside the daemon, and all execution is done within the daemon's scope - the client only passes its `ARGV` over the socket to the daemon and prints any response. If you reference `ARGV` directly in your run block it will not work as expected since it will be the _daemon_'s `ARGV` that gets evaluated:

```ruby
IODaemonizer.wrap(
  {
    setup: -> do
      @app = App.new
    end,
    run: ->(args) do
      # DO NOT USE ARGV HERE - use args instead, which is how the daemon passes
      # the arguments it receives over the socket to the run block
      puts @app.shout(ARGV.join(" "))
    end
  }
)

# $ ruby example.rb start
#   => starting server...

# $ ruby example.rb hello
#   START
```

Also note that the daemon's scope is persisted across runs of your script. So, for example, the following would print a new number each run:

```ruby
IODaemonizer.wrap(
  setup: -> { @count = 0 },
  run: ->(args) { puts @count += 1 }
)
```

### Starting and stopping the server
Call your script with `start` or `stop` as the first argument to control the daemon process.

The daemon will start synchronously (ie, it will wait until the setup step completes to send itself to the background and return).

### Executing your script
Once the daemon is running, you can call your script as normal.

### Specifying port
The port can be specified with the `IO_DAEMONIZER_PORT` environment variable. Make sure to use a different port for each script.

## Roadmap
* [x] proof of concept
* [x] basic docs
* [x] license
* [x] [`v.1`](https://github.com/joeyschoblaska/io_daemonizer/tree/v.1): gemify 
* [ ] auto-start server if not available (configurable?)
* [ ] support stdin
* [ ] pass port as argument?
* [ ] support io more generically
* [ ] command to get server status
* [ ] command to restart the server
* [ ] pids?
* [ ] use dynamic port 0 (need pid or some other way to find running daemon)
* [ ] usage instructions (-h)?
* [ ] logs?
* [ ] optional async startup
* [ ] support first argument that sends remaining as literal args (eg, so that you can pass "stop" _to_ the daemon instead of stopping it)
* [ ] forward exit code to client script?
