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

  def say(msg)
    msg.reverse # simulate something useful
  end
end

app = App.new # slow; does the same thing each run
puts app.say(ARGV.join(" ")) # fast; does something different each run
```

If we're calling this script frequently, we don't want to pay the cost of `App.new` each time. Instead, IO Daemonizer can wrap the setup step and the run step separately:

```ruby
require "io_daemonizer"

class App
  # ...
end

IODaemonizer.serve(
  {
    setup: -> do
      @app = App.new # slow
    end,
    run: ->(args) do # ARGV will be passed to run block as `args`
      puts @app.say(args.join(" ")) # fast
    end
  }
)
```

Now the slow step is performed once and its state is stored in memory in a persistent thread running in the background. Calling the script will pipe arguments over a TCP socket to the daemon process, which executes the `run` lambda in the scope of the `setup` step and returns the results over the socket. The caller then prints the results to stdout.

## Usage
IO Daemonizer is packaged as a gem, but it has no dependencies outside the core library and you may find it more convenient to include `io_daemonizer.rb` in your project directly. It needs to be loaded with each call to your script, so the less overhead the better.

## Roadmap
* [x] proof of concept
* [ ] block while setting up daemon
* [ ] basic docs (benchmarks, server control)
* [ ] license
* [ ] :bookmark: `v.1`: gemify 
* [ ] auto-start server if not available (configurable?)
* [ ] exit codes
* [ ] stdin
* [ ] port argument
* [ ] support io more generically
* [ ] feedback and status ("starting...", "stopping...")
* [ ] pids?
* [ ] usage instructions (-h)?
* [ ] logs?
* [ ] support first argument that sends remaining as literal args (eg, so that you can pass "stop" _to_ the daemon instead of stopping it)
