module Deferring
  class DeferredCallbackListener < Struct.new(:event_name, :callee, :callback)

    [:before_link, :before_unlink, :after_link, :after_unlink].each do |event_name|
      define_method(event_name) do |record|
        callee.public_send(callback, record)
      end
    end

  end
end
