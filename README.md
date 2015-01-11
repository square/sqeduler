# sqeduler

## Description

Provides common infrastructure for using Sidekiq scheduling across multiple hosts.

## Features

* Centralizes configuration for Sidekiq and Sidekiq::Scheduler
* Provides global level scheduler locks via a simple redis lock
* Provides a simple base class for Sidekiq jobs:
  * Simple callbacks for `before_start`, `on_success`, `on_failure`, `on_schedule_collision`.
  * `synchronize_jobs_mode` for if a job should run exclusively. Currently only supports `:one_at_a_time`.

## Examples

To install this gem with necessary forks:
```ruby
gem 'sqeduler'
gem 'sidekiq-scheduler', :github => 'ecin/sidekiq-scheduler', :branch => 'ecin/redis-lock' # https://github.com/Moove-it/sidekiq-scheduler/pull/38
```

To use just use `Sidekiq` and `Sidekiq::Scheduler`:

In an initializer:

```ruby
require 'sqeduler'

config = {
  :redis_config       => SIDEKIQ_REDIS, # configuration for connecting to redis client
  :logger             => logger, # defaults to Rails.logger if nil
  :schedule_path      => Rails.root.join('config').join('sidekiq_schedule.yml'),
  :exception_notifier => proc { |e| Bugsnag.notify_error(e) } # a general exception reporter, we like Bugsnag
}

# OPTIONAL PARAMETERS

# We use a `ConnectionPool` for worker synchronization lock (Sqeduler::BaseWorker.synchronize_jobs).
# `ConnectionPool` is a already a dependency for Sidekiq used to pool redis connections, it's important
# to tune these settings with care.
config[:locks_pool_timeout] = timeout
config[:locks_pool_size] = size

# Additional configuration for Sidekiq.
# Pptional server config for sidekiq. Allows you to hook into `Sidekiq.configure_server`
config[:on_server_start] = proc {|config| ... }
# optional client config for sidekiq. Allows you to hook into `Sidekiq.configure_client`
config[:on_client_start] = proc {|config| ... }

Sqeduler::Service.config = Sqeduler::Config.new(config)
# Starts the service.
Sqeduler::Service.start
```

See documentation for [Sidekiq::Scheduler](https://github.com/Moove-it/sidekiq-scheduler#scheduled-jobs-recurring-jobs)
for specifics on how to construct your schedule YAML file.

To use the `Sqeduler::BaseWorker`:

```ruby
class MyWorker < ::Sqeduler::BaseWorker
  include Sidekiq::Worker
  # optionally synchronize jobs across hosts
  # the default timeout is 5.seconds
  synchronize_jobs :one_at_a_time, :expiration => 1.hour, :timeout => 1.second

  private

  def do_work
    # The actual meat of your job.
    # Should take the same args as perform.
  end

  def on_success
    # It worked! Save this status or enqueue other jobs.
  end

  def on_failure(e)
    # Bugsnag can already be notified with config.exception_notifier,
    # but maybe you need to log this differently.
  end

  def on_scuedule_conflict
    # Called when your worker uses synchronization and :expiration is too low, i.e. it took longer
    # to carry out `do_work` then your lock's expiration period. In this situation, it's possible for
    # the job to get scheduled again even though you expected the job to run exclusively.
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


