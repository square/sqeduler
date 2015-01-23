# encoding: utf-8
module Sqeduler
  module RedisScripts
    def release_lock
      sha_and_evaluate(:release, key, lock_value)
    end

    def refresh_lock
      sha_and_evaluate(:refresh, key, lock_value)
    end

    private

    def sha_and_evaluate(script_name, key, value)
      redis_pool.with do |redis|
        # strip leading whitespace of 8 characters
        sha = load_sha(redis, script_name)
        # all scripts return 0 or 1
        redis.evalsha(sha, :keys => [key], :argv => [value]) == 1
      end
    end

    def load_sha(redis, script_name)
      @redis_sha_cache ||= {}
      @redis_sha_cache[script_name] ||= begin
        script = if script_name == :refresh
                   refresh_lock_script
                 elsif script_name == :release
                   release_lock_script
                 else
                   fail "No script for #{:script_name}"
                 end

        redis.script(:load, script.gsub(/^ {8}/, ""))
      end
    end

    def refresh_lock_script
      <<-EOF
        if redis.call('GET', KEYS[1]) == false then
          if #{expiration} > 0 then
            return redis.call('SET', KEYS[1], ARGV[1], 'NX', 'EX', #{expiration}) and 1 or 0
          else
            return redis.call('SET', KEYS[1], ARGV[1], 'NX') and 1 or 0
          end
        elseif redis.call('GET', KEYS[1]) == ARGV[1] then
          if #{expiration} > 0 then
            redis.call('EXPIRE', KEYS[1], #{expiration})
          end
          if redis.call('GET', KEYS[1]) == ARGV[1] then
            return 1
          end
        end
        return 0
      EOF
    end

    def release_lock_script
      <<-EOF
        if redis.call('GET', KEYS[1]) == ARGV[1] then
          redis.call('DEL', KEYS[1])
          return 1
        else
          return 0
        end
      EOF
    end
  end
end
