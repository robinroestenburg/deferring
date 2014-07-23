# encoding: UTF-8

require 'delegate'

module Deferring
  class DeferredAssociation < SimpleDelegator
    # TODO: Write tests for enumerable.
    include Enumerable

    attr_reader :load_state

    def initialize(original_association, name)
      super(original_association)
      @name = name
      @load_state = :ghost
    end

    alias_method :original_association, :__getobj__

    delegate :to_s, :to_a, :inspect, :==, # methods undefined by SimpleDelegator
             :is_a?, :as_json,

             :[], :clear, :reject, :reject!, :flatten, :flatten!, :sort!,
             :empty?, :size, :length, # methods on Array

             to: :objects

    def each(&block)
      objects.each(&block)
    end

    # TODO: Add explanation about :first/:last loaded? problem.
    [:first, :last].each do |method|
      define_method method do
        unless objects_loaded?
          original_association.send(method)
        else
          objects.send(method)
        end
      end
    end

    def find(*args)
      original_association.find(*args)
    end

    def select(value = Proc.new)
      if block_given?
        objects.select { |*block_args| value.call(*block_args) }
      else
        original_association.select(value)
      end
    end

    # Rails 3.0 specific, not needed anymore for Rails 3.0+
    def set_inverse_instance(associated_record, parent_record)
      original_association.__send__(:set_inverse_instance, associated_record, parent_record)
    end

    def association
      load_objects
      original_association
    end

    def objects
      load_objects
      @objects
    end

    def original_objects
      load_objects
      @original_objects
    end

    def objects=(records)
      @objects = records
      @original_objects = original_association.to_a.clone
      objects_loaded!

      pending_deletes.each { |record| run_unlink_callbacks(record) }
      pending_creates.each { |record| run_link_callbacks(record) }

      @objects
    end

    def ids
      objects.map(&:id)
    end

    def <<(records)
      # TODO: Do we want to prevent including the same object twice? Not sure,
      # but it will probably be filtered after saving and retrieving as well.
      Array(records).flatten.uniq.each do |record|
        run_link_callbacks(record) do
          objects << record
        end
      end
      self
    end
    alias_method :push, :<<
    alias_method :concat, :<<
    alias_method :append, :<<

    def delete(records)
      Array(records).flatten.uniq.each do |record|
        run_unlink_callbacks(record) do
          objects.delete(record)
        end
      end
      self
    end

    def build(*args, &block)
      association.build(*args, &block).tap do |result|
        objects.push(result)
        association.reload
      end
    end

    def create!(*args, &block)
      association.create!(*args, &block).tap do |result|
        @load_state = :ghost
        load_objects
      end
    end

    def reload
      original_association.reload
      @load_state = :ghost
      self
    end
    alias_method :reset, :reload

    # Returns the associated records to which links will be created after saving
    # the parent of the association.
    def pending_creates
      return [] unless objects_loaded?
      objects - original_objects
    end
    alias_method :links, :pending_creates

    # Returns the associated records to which the links will be deleted after
    # saving the parent of the assocation.
    def pending_deletes
      # TODO: Write test for it.
      return [] unless objects_loaded?
      original_objects - objects
    end
    alias_method :unlinks, :pending_deletes

    # Custom callback stuff
    def add_listener(listener)
      (@listeners ||= []) << listener
    end

    private

    def load_objects
      return if objects_loaded?

      @objects = original_association.to_a.clone
      @original_objects = @objects.clone.freeze
      objects_loaded!
    end

    def objects_loaded?
      @load_state == :loaded
    end

    def objects_loaded!
      @load_state = :loaded
    end

    def run_unlink_callbacks(record)
      notify_listeners(:before_unlink, record)
      yield if block_given?
      notify_listeners(:after_unlink, record)
    end

    def run_link_callbacks(record)
      notify_listeners(:before_link, record)
      yield if block_given?
      notify_listeners(:after_link, record)
    end

    def notify_listeners(event_name, record)
      @listeners && @listeners.each do |listener|
        if listener.event_name == event_name
          listener.public_send(event_name, record)
        end
      end
    end

  end
end
