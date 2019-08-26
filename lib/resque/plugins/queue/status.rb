# frozen_string_literal: true

require 'resque/plugins/queue/status/version'

module Resque
  module Plugins
    module Queue
      # Resque::Plugins::Queue::Status.
      # It provides adding simple queue statuses for your jobs.
      # You can specify your own key for your queues and check the status.
      #
      # You can use it doing extend Resque::Plugins::Queue::Status
      #
      # For example
      #
      #       class ExampleJob
      #         extend Resque::Plugins::Queue::Status
      #
      #         def self.perform()
      #           puts 'hoge'
      #         end
      #
      #       end
      #
      #       Resque.enqueue(ExampleJob, queue_status_key: 'hoge')
      #       ExampleJob.current_queue_status('hoge')
      #
      # The queue status key lasts 24 hours to expire
      #
      module Status
        PROCESS = 'PROCESS'
        COMPLETE = 'COMPLETE'
        FAIL = 'FAIL'
        STATUSES = [PROCESS, COMPLETE, FAIL].freeze

        def before_enqueue_queue_status(args)
          _set_status(
            queue_status_key: _queue_status_key(args),
            status: PROCESS
          )
        end

        def after_perform_queue_status(args)
          _set_status(
            queue_status_key: _queue_status_key(args),
            status: COMPLETE
          )
        end

        def on_failure_queue_status(err, args)
          _set_status(
            queue_status_key: _queue_status_key(args),
            status: FAIL,
            meta: err
          )
        end

        def current_queue_status(queue_status_key)
          JSON.parse(
            Resque.redis.get(_namespaced_queue_status(queue_status_key)),
            symbolize_names: true
          )
        end

        def all_queue_statuses
          Resque.redis.keys("#{_prefix}:*")
        end

        def clear_all_queue_statuses
          Resque.redis.del(*all_queue_statuses) unless all_queue_statuses.empty?
        end

        def _queue_status_key(args)
          args['queue_status_key'] || args[:queue_status_key]
        end

        def _namespaced_queue_status(queue_status_key)
          queue_status_key_name = Resque::Job.decode(
            Resque::Job.encode(queue_status_key)
          )
          "#{_prefix}:#{queue_status_key_name}"
        end

        def _set_status(args)
          Resque.redis.set(
            _namespaced_queue_status(args[:queue_status_key]),
            args.slice(:status, :meta).to_json,
            ex: 24 * 60 * 60
          )
        end

        def _prefix
          "queuestatus:#{name}"
        end
      end
    end
  end
end
