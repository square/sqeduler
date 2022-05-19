### 0.3.8 / 2022-05-19
* Support sidekiq-scheduler 4

### 0.3.8 / 2018-01-10

* "NoMethodError: undefined method `constantize' for ..." error fixed in tests  
* Yard gem version updated to "~> 0.9.11" 

### 0.3.7 / 2016-09-21

* Fixed a bug introduced by sidekiq-scheduler 2.0.9 that resulted in the schedule being empty

### 0.3.6 / 2016-06-16

* Symbolize keys in redis config hash
* Add method to list disabled workers

### 0.3.5 / 2016-05-03

* Move sidekiq-scheduler from 1.x to 2.x

### 0.3.4 / 2016-03-28

* Add ability to use a client-provided connection pool rather than creating one

### 0.3.3 / 2016-03-25

* Fixed lock refresher not calling `redis_pool` properly so it wouldn't actually run

### 0.3.2 / 2016-03-10

* Fixed lock refresher failing to lock properly for exclusive runs
* Added debug logs for lock refresher

### 0.3.1 / 2016-02-17

* Fixed lock refresh checking timeout rather than expiration for finding eligible jobs

### 0.3.0 / 2016-01-25

* Added lock refresh to maintain exclusive locks until long running jobs finish

### 0.2.2 / 2015-11-11

* Support ERB in job schedules
* Handle exceptions more gracefully in lock acquisition

### 0.2.0 / 2015-04-18

* Add KillSwitch middleware
* Cleanup

### 0.1.4 / 2015-03-26

* Initial release
