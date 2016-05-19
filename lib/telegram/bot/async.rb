module Telegram
  module Bot
    # Clients can perform requests in async way with ActiveJob.
    # For now it supports only clients configured with `Telegram.bots_config`
    # (including `secrets.yml`).
    #

    #
    #   client.async = true
    #   client.send_message(message) # Will be in a job
    #   client.async { client.send_message(message) } # will be sent immediately
    #
    module Async
      module Job
        def perform(client_id, *args)
          client = client_class.by_id!(client_id.to_sym)
          client.async(false) { client.request(*args) }
        end
      end

      module ClassMethods
        def default_async_job
          @default_async_job ||= begin
            klass = Class.new(ApplicationJob) { include Job }
            const_set(:AsyncJob, klass)
          end
        end
      end

      attr_reader :id

      def initialize(*, id: nil, async: nil, **options)
        super
        @id = id
        self.async = async
      end

      # Sets `@async` to `self.class.default_async_job` if `true` is given
      # or uses given value.
      # Pass custom job class to perform async calls with.
      def async=(val)
        @async =
          case val
          when true then self.class.default_async_job
          when String then const_get(val)
          else val
          end
      end

      # Returns value of `@async` if no block is given. Otherwise sets this value
      # for a block.
      def async(val = true)
        return @async unless block_given?
        old_val = @async
        self.async = val
        yield
      ensure
        @async = old_val
      end

      # Uses job if #async is set.
      def request(*args)
        return async.perform_later(id, *args) if async
        super
      end
    end
  end
end
