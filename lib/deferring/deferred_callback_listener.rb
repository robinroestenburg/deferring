module Deferring
  class DeferredCallbackListener
    attr_reader :event_name, :callee, :callback_method

    def initialize(event_name, callee, callback_method)
      @event_name = event_name
      @callee = callee
      @callback_method = callback_method
    end

    [:before_link, :before_unlink, :after_link, :after_unlink].each do |event_name|
      define_method(event_name) do |record|
        callee.public_send(callback_method, record)
      end
    end
  end
end
