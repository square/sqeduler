# encoding: utf-8
module Sqeduler
  module TimeDuration
    def time_duration(timespan)
      rest, secs = timespan.divmod(60)  # self is the time difference t2 - t1
      rest, mins = rest.divmod(60)
      days, hours = rest.divmod(24)

      result = []
      result << "#{days} Days" if days > 0
      result << "#{hours} Hours" if hours > 0
      result << "#{mins} Minutes" if mins > 0
      result << "#{secs.round(2)} Seconds" if secs > 0
      result.join(" ")
    end
  end
end
