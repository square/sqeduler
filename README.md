# sqeduler

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

To install this gem with necessary forks:

```ruby
gem 'sqeduler'
gem 'sidekiq-scheduler', :github => 'ecin/sidekiq-scheduler', :branch => 'ecin/redis-lock' # https://github.com/Moove-it/sidekiq-scheduler/pull/38
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

Sqeduler::Service.config = config
# Starts Sidekiq and Sidekiq::Scheduler
Sqeduler::Service.start
```

See documentation for [Sidekiq::Scheduler](https://github.com/Moove-it/sidekiq-scheduler#scheduled-jobs-recurring-jobs)
for specifics on how to construct your schedule YAML file.

### Worker Helpers

To use `Sqeduler::Worker` modules:
* You **DO NOT need** to use this gem for starting Sidekiq or Sidekiq::Scheduler (i.e: `Sqeduler::Service.start`)
* You **DO need** to provide at `config.redis_hash`, and `config.logger` if you don't want to log to `Rails.logger`.
  * This gem creates a separate `ConnectionPool` so that it can create locks for synchronization and store state for disabling/enabling workers.

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
  # :timeout, how long should we poll for a lock, default is 5.seconds
  # :expiration, how long should the lock be held for, must be provided in seconds
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

  # NOTE: Even if on_scuedule_conflict or on_lock_timeout occur your job will still
  # receive on_success if you prepend Sqeduler::Worker::Callbacks. These events do not
  # equate to failures.

  def on_scuedule_conflict(duration)
    # Called when your worker uses synchronization and :expiration is too low, i.e. it took longer
    # to carry out `do_work` then your lock's expiration period. In this situation, it's possible for
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


