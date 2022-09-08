# IO Daemonizer
Wrap a Ruby script that speaks stdio in a daemon so that you only pay the startup overhead once.

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
real    0m1.089s # <- slow

$ time ruby example.rb there
THERE
real    0m1.089s # <- slow
```

Instead, IO Daemonizer can wrap the setup step and the run step separately:

```ruby
require "io_daemonizer"

class App
  # ...
end

IODaemonizer.wrap(
  port: 6872,
  setup: -> do
    @app = App.new # slow
  end,
  run: ->(args) do # ARGV will be passed to run block as `args`
    puts @app.shout(args.join(" ")) # fast
  end
)
```

Now, when we call our script the first time it will perform the expensive setup step once and store the state in a background process. Subsequent calls will run in a new process that communicates with the daemon over a TCP socket. Any stdio communication in the daemon will be forwarded back to the client:

```
$ time ruby example.rb hello
HELLO
real    0m1.088s # <- still slow...

$ time ruby example.rb there
THERE
real    0m0.067s # <- fast!
```

## Installation
IO Daemonizer is packaged as a gem, but it has no dependencies outside the core library and you may find it more convenient to include `io_daemonizer.rb` in your project directly. It needs to be loaded with each call to your script, so the less overhead the better.

## Usage
### `IODaemonizer::wrap`
This is the only method you need to call in your script. It parses the command-line args and handles starting / stopping the daemon and forwarding commands to it.

`IODaemonizer::wrap` takes the following parameters:

#### `port:` (required)
The port that you want your daemon to run on. Make sure to use a different port for each script.

#### `setup:` (required)
A lambda which contains the one-time setup steps in your script. Any instance variables set in this step will be available to the run step.

In this context, ARGV will be equal to the arguments that are present during server initialization.

#### `run:` (required)
A lambda which accepts a single parameter containing the command-line args forwarded from the client process (eg, `run: ->(args) { ... }`). Make sure to include the argument or you'll get the following error: `#<ArgumentError: wrong number of arguments (given 1, expected 0)>`.

Both the setup and run blocks are stored in variables inside the daemon, and all execution is done within the daemon's scope - the client only passes its `ARGV` over the socket to the daemon and prints any response. If you reference `ARGV` directly in your run block it will not work as expected since it will be the _daemon_'s `ARGV` that gets evaluated:

```ruby
IODaemonizer.wrap(
  port: 6872,
  setup: -> { @app = App.new },
  run: ->(args) do
    # DO NOT USE ARGV HERE - use args instead, which is how the daemon passes
    # the arguments it receives over the socket to the run block
    puts @app.shout(ARGV.join(" "))
  end
)

# $ ruby example.rb start
#   => starting server...

# $ ruby example.rb hello
#   START
```

Also note that the daemon's scope is persisted across runs of your script. So, for example, the following would print a new number each run:

```ruby
IODaemonizer.wrap(
  port: 6872,
  setup: -> { @count = 0 },
  run: ->(args) { puts @count += 1 }
)
```

#### `autostart:` (optional; default: `true`)
Attempt to start the server automatically if it's not already running. If set to `false`, you will need to manually start your script's daemon with `ruby example.rb start` before calling it.

### Starting and stopping the server
Call your script with `start` or `stop` as the first argument to control the daemon process.

The daemon will start synchronously (ie, it will wait until the setup step completes to send itself to the background and return).

### Executing your script
Once the daemon is running, you can call your script as normal.

## Roadmap
* [x] proof of concept
* [x] basic docs
* [x] license
* [x] [`v.1`](https://github.com/joeyschoblaska/io_daemonizer/tree/v.1): gemify 
* [x] `v.2`: not sure what happened to v.2
* [x] [`v.3`](https://github.com/joeyschoblaska/io_daemonizer/tree/v.3): support stdin
* [x] [`v.4`](https://github.com/joeyschoblaska/io_daemonizer/tree/v.4): pass port as argument
* [x] [`v.5`](https://github.com/joeyschoblaska/io_daemonizer/tree/v.5): autostart server
* [x] [`v.6`](https://github.com/joeyschoblaska/io_daemonizer/tree/v.6): write stderr to stderr
* [x] [`v.7`](https://github.com/joeyschoblaska/io_daemonizer/tree/v.7): optimize streaming json parser :rocket:
* [ ] command to get server status
* [ ] command to restart the server
* [ ] configurable timeouts
* [ ] logs?
* [ ] support first argument that sends remaining as literal args (eg, so that you can pass "stop" _to_ the daemon instead of stopping it)
* [ ] optional async startup
* [ ] support io more generically
* [ ] pids?
* [ ] use dynamic port 0 (need pid or some other way to find running daemon)
* [ ] usage instructions (-h)?
* [ ] forward exit code to client script?
