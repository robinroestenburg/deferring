# encoding: UTF-8

class VirtualProxy < BasicObject
  def initialize(&loader)
    @loader = loader
    @object = nil
  end

  def method_missing(name, *args, &block)
    __load__
    @object.public_send(name, *args, &block)
  end

  def inspect
    "VirtualProxy(#{@object ? @object.inspect : ''})"
  end

  def __object__
    @object
  end

  def __load__
    @object ||= @loader.call
  end
end
