# Sidekiq::Lock

Redis-based simple locking mechanism for [sidekiq][2]. Uses [SET command][1] introduced in Redis 2.6.16.

It can be handy if you push a lot of jobs into the queue(s), but you don't want to execute specific jobs at the same time - it provides a `lock` method that you can use in whatever way you want.

## Installation

This gem requires at least:
- redis 2.6.12
- redis-rb 3.0.5 (support for extended SET method)

Add this line to your application's Gemfile:

    gem 'sidekiq-lock', git: "git@github.com:emq/sidekiq-lock.git" # no stable release yet

And then execute:

    $ bundle

## Usage

Sidekiq-lock is a middleware/module combination, let me go through my thought process here :).

In your worker class include `Sidekiq::Lock::Worker` module and provide `lock` attribute inside `sidekiq_options`, for example:

``` ruby
class Worker
  include Sidekiq::Worker
  include Sidekiq::Lock::Worker

  # static lock that expires after one second
  sidekiq_options lock: { timeout: 1000, name: 'lock-worker' }

  def perform
    # ...
  end
end
```

What will happen is:

- middleware will setup a `Sidekiq::Lock::RedisLock` object under `Thread.current[Sidekiq::Lock::THREAD_KEY]` (well, I had no better idea for this) - assuming you provided `lock` options, otherwise it will do nothing, just execute your worker's code

- `Sidekiq::Lock::Worker` module provides a `lock` method that just simply points to that thread variable, just as a convenience

So now in your worker class you can call (whenever you need):

- `lock.acquire!` - will try to acquire the lock, if returns false on failure (that means some other process / thread took the lock first)
- `lock.acquired?` - set to `true` when lock is successfully acquired
- `lock.release!` - deletes the lock (if not already expired / taken by another process)

### Lock options

sidekiq_options lock will accept static values or `Proc` that will be called on argument(s) passed to `perform` method.

- timeout - specified expire time, in milliseconds
- name - name of the redis key that will be used as lock name

Dynamic lock example:

``` ruby
class Worker
  include Sidekiq::Worker
  include Sidekiq::Lock::Worker
  sidekiq_options lock: {
    timeout: proc { |user_id, timeout| timeout * 2 },
    name:    proc { |user_id, timeout| "lock:peruser:#{user_id}" }
  }

  def perform(user_id, timeout)
    # ...
    # do some work
    # only at this point I want' to try to acquire the lock
    if lock.acquire!
      # I can do the work
    else
      # reschedule, raise an error or do whatever you want
    end
  end
end
```

Just be sure to provide valid redis key as a lock name.

## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request

[1]: http://redis.io/commands/set
[2]: https://github.com/mperham/sidekiq