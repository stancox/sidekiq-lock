require "test_helper"

class LockWorker
  include Sidekiq::Worker
  include Sidekiq::Lock::Worker
  sidekiq_options lock: { timeout: 1, name: 'lock-worker' }
end

class DynamicLockWorker
  include Sidekiq::Worker
  include Sidekiq::Lock::Worker
  sidekiq_options lock: {
    timeout: proc { |user_id, timeout| timeout*2 },
    name:    proc { |user_id, timeout| "lock:#{user_id}" }
  }
end

class RegularWorker
  include Sidekiq::Worker
  include Sidekiq::Lock::Worker
end


module Sidekiq
  module Lock
    describe Middleware do

      def thread_variable
        Thread.current[Sidekiq::Lock::THREAD_KEY]
      end

      before do
        Sidekiq.redis = REDIS
        Sidekiq.redis { |c| c.flushdb }
        Thread.current[Sidekiq::Lock::THREAD_KEY] = nil
      end

      let(:handler){ Sidekiq::Lock::Middleware.new }

      it 'sets lock variable with provided static lock options' do
        handler.call(LockWorker.new, {'class' => LockWorker, 'args' => []}, 'default') do
          true
        end

        assert_kind_of RedisLock, thread_variable
      end

      it 'sets lock variable with provided dynamic options' do
        handler.call(DynamicLockWorker.new, {'class' => DynamicLockWorker, 'args' => [1234, 1000]}, 'default') do
          true
        end

        assert_equal "lock:1234", thread_variable.name
        assert_equal 2000,   thread_variable.timeout
      end

      it 'sets nothing for workers without lock options' do
        handler.call(RegularWorker.new, {'class' => RegularWorker, 'args' => []}, 'default') do
          true
        end

        assert_nil thread_variable
      end

    end
  end
end