# encoding: utf-8
# Fake worker class for specs
class FakeWorker < Sqeduler::BaseWorker
  JOB_RUN_PATH =            "/tmp/job_run"
  JOB_BEFORE_START_PATH =   "/tmp/job_before_start"
  JOB_SUCCESS_PATH =        "/tmp/job_success"
  JOB_FAILURE_PATH =        "/tmp/job_failure"
  JOB_LOCK_FAILURE_PATH =   "/tmp/lock_failure"
  SCHEDULE_COLLISION_PATH = "/tmp/schedule_collision"

  def do_work(sleep_time)
    long_process(sleep_time)
  end

  def long_process(sleep_time)
    sleep sleep_time
    log_event(JOB_RUN_PATH)
  end

  private

  def on_success
    log_event(JOB_SUCCESS_PATH)
  end

  def on_failure(_e)
    log_event(JOB_FAILURE_PATH)
  end

  def before_start
    log_event(JOB_BEFORE_START_PATH)
  end

  def on_lock_timeout
    log_event(JOB_LOCK_FAILURE_PATH)
  end

  def on_schedule_collision
    log_event(SCHEDULE_COLLISION_PATH)
  end

  private

  def log_event(file_path)
    File.open(file_path, "a+") { |f| f.write "1" }
  end
end
