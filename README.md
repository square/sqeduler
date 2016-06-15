# sqeduler

[![Build Status](https://travis-ci.org/square/sqeduler.svg?branch=master)](https://travis-ci.org/square/sqeduler)

## Description

Provides loosely-coupled helpers for Sidekiq workers. Provides highly available scheduling across multiple hosts.

## Features

* Centralizes configuration for Sidekiq and Sidekiq::Scheduler
* Provides composable modules for Sidekiq jobs.
  * Simple callbacks for `before_start`, `on_success`, `on_failure`
  * Synchronization across multiple hosts:
    * Provides global level scheduler locks through a thread-safe redis lock
    * `synchronize_jobs_mode` for if a job should run exclusively. Currently only supports `:one_at_a_time`.
    * Callbacks for `on_schedule_collision` and `on_lock_timeout`
  * Crosshost worker killswitches. `enabled` and `disable` methods to enable and disable workers. Enabled by default.

## Examples

To install this gem, add it to your Gemfile:

```ruby
gem 'sqeduler'
```

### Scheduling

To use this gem for initializing `Sidekiq` and `Sidekiq::Scheduler`:

In an initializer:

```ruby
require 'sqeduler'
config = Sqeduler::Config.new(
  # configuration for connecting to redis client. Must be a hash, not a `ConnectionPool`.
  :redis_hash => SIDEKIQ_REDIS,
  :logger     => logger, # defaults to Rails.logger if nil
)

# OPTIONAL PARAMETERS
# Additional configuration for Sidekiq.
# Optional server config for sidekiq. Allows you to hook into `Sidekiq.configure_server`
config.on_server_start = proc {|config| ... }
# optional client config for sidekiq. Allows you to hook into `Sidekiq.configure_client`
config.on_client_start = proc {|config| ... }
# required if you want to start the Sidekiq::Scheduler
config.schedule_path = Rails.root.join('config').join('sidekiq_schedule.yml')
# optional to maintain locks for exclusive jobs, see "Lock Maintainer" below
config.maintain_locks = true

Sqeduler::Service.config = config
# Starts Sidekiq and Sidekiq::Scheduler
Sqeduler::Service.start
```

You can also pass in your own `ConnectionPool` instance as `config.redis_pool` rather than providing configuration in `redis_hash`. If you do so, it's recommended to use a `Redis::Namespace` so that the keys sqeduler sets are namespaced uniquely.

See documentation for [Sidekiq::Scheduler](https://github.com/Moove-it/sidekiq-scheduler#scheduled-jobs-recurring-jobs)
for specifics on how to construct your schedule YAML file.

### Lock Maintainer

Exclusive locks only last for the expiration you set. If your expiration is 30 seconds and the job runs for 60 seconds, you can have multiple jobs running at once. Rather than having to set absurdly high lock expirations, you can enable the `maintain_locks` option which handles this for you.

Every 30 seconds, Sqeduler will look for any exclusive Sidekiq jobs that have been running for more than 30 seconds, and have a lock expiration of more than 30 seconds and refresh the lock.

### Worker Helpers

To use `Sqeduler::Worker` modules:
* You **DO NOT need** to use this gem for starting Sidekiq or Sidekiq::Scheduler (i.e: `Sqeduler::Service.start`)
* You **DO need** to provide at `config.redis_hash`, and `config.logger` if you don't want to log to `Rails.logger`.
  * This gem creates a separate `ConnectionPool` so that it can create locks for synchronization and store state for disabling/enabling workers.
* You **DO need** to `include`/`prepend` these modules in the actual working class
  * They will not work if done in a parent class because of the way `prepend` works in conjunction with inheritance.

The modules:

* `Sqeduler::Worker::Callbacks`: simple callbacks for `before_start`, `on_success`, `on_failure`
* `Sqeduler::Worker::Synchronization`: synchronize workers across multiple hosts:
  * `synchronize_jobs_mode` for if a job should run exclusively. Currently only supports `:one_at_a_time`.
  * Callbacks for `on_schedule_collision` and `on_lock_timeout`
* `Sqeduler::Worker::KillSwitch`: cross-host worker disabling/enabling.
  * `enabled` and `disable` class methods to enable and disable workers.
  * Workers are enabled by default.

You can either include everything`include Sqeduler::Worker::Everything`) or prepend à la carte, but make sure to
use [prepend](http://ruby-doc.org/core-2.0.0/Module.html#method-i-prepend), not `include`.

Sample code and callback docs below.

```ruby
class MyWorker
  include Sidekiq::Worker

  # include everything
  include Sqeduler::Worker::Everything
  # or cherry pick the modules that you want

  # optionally synchronize jobs across hosts
  prepend Sqeduler::Worker::Synchronization
  # then define how the job should be synchronized
  # :timeout in seconds, how long should we poll for a lock, default is 5
  # :expiration in seconds, how long should the lock be held for
  synchronize :one_at_a_time, :expiration => 1.hour, :timeout => 1.second

  # cross-host methods for enabling and disabling workers
  # MyWorker.disable and MyWorker.enable
  prepend Sqeduler::Worker::KillSwitch


  # Simple callbacks for `before_start`, `on_success`, `on_failure`
  # must be the last worker to be prepended
  prepend Sqeduler::Worker::Callbacks

  def perform(*args)
    # Your typical sidekiq worker code
  end

  private

  # callbacks for Sqeduler::Worker::Callbacks

  def before_start
    # before perform is called
  end

  def on_success(total_time)
    # It worked! Save this status or enqueue other jobs.
  end

  def on_failure(e)
    # Bugsnag can already be notified with config.exception_notifier,
    # but maybe you need to log this differently.
  end

  # callbacks for Sqeduler::Worker::Synchronization

  # NOTE: Even if `on_schedule_collision` or `on_lock_timeout` occur your job will still
  # receive on_success if you prepend Sqeduler::Worker::Callbacks. These events do not
  # equate to failures.

  def on_schedule_collision(duration)
    # Called when your worker uses synchronization and :expiration is too low, i.e. it took longer
    # to carry out `perform` then your lock's expiration period. In this situation, it's possible for
    # the job to get scheduled again even though you expected the job to run exclusively.
  end

  def on_lock_timeout(key)
    # Called when your worker cannot obtain the lock.
  end
end
```

## License

Copyright 2015 Square Inc.

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.


