# encoding: UTF-8

require 'delegate'

module Deferring
  class DeferredAssociation < SimpleDelegator
    # TODO: Write tests for enumerable.
    include Enumerable

    attr_reader :load_state,
                :klass,
                :parent_record,
                :inverse_name,
                :dependent

    def initialize(original_association, klass, parent_record, inverse_name, dependent)
      super(original_association)
      @load_state    = :ghost
      @klass         = klass
      @parent_record = parent_record
      @inverse_name  = inverse_name
      @dependent     = dependent
    end
    alias_method :original_association, :__getobj__

    def inspect
      objects.inspect
    end
    alias_method :pretty_inspect, :inspect

    delegate :to_s, :to_a, :inspect, :==, # methods undefined by SimpleDelegator
             :is_a?, :as_json, to: :objects

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

    # Delegates methods from Ruby's Array module to the object in the deferred
    # association.
    delegate :[]=, :[], :clear, :select!, :reject!, :flatten, :flatten!, :sort!,
             :keep_if, :delete_if, :sort_by!, :empty?, :size, :length,
             to: :objects

    # Delegates Ruby's Enumerable#find method to the original association.
    #
    # The delegation has to be explicit in this case, because the inclusion of
    # Enumerable also defines the find-method on DeferredAssociation.
    def find(*args)
      original_association.find(*args)
    end

    # Delegates Ruby's Enumerable#select method to the original association when
    # no block has been given. Rails' select-method does not accept a block, so
    # we know that in that case the select-method has to be called on our
    # deferred association.
    #
    # The delegation has to be explicit in this case, because the inclusion of
    # Enumerable also defines the select-method on DeferredAssociation.
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

    def objects
      load_objects
      @objects
    end

    def objects=(records)
      @objects = records.map do |record|
        if inverse_name && record.class.reflect_on_association(inverse_name)
          record.send(:"#{inverse_name}=", parent_record)
        end
        record
      end

      @original_objects = original_association.to_a.clone
      objects_loaded!

      pending_deletes.each { |record| run_deferring_callbacks(:unlink, record) }
      pending_creates.each { |record| run_deferring_callbacks(:link, record) }

      @objects
    end

    def ids
      objects.map(&:id)
    end

    def <<(*records)
      # TODO: Do we want to prevent including the same object twice? Not sure,
      # but it will probably be filtered after saving and retrieving as well.
      records.flatten.uniq.each do |record|
        run_deferring_callbacks(:link, record) do
          if inverse_name && record.class.reflect_on_association(inverse_name)
            record.send(:"#{inverse_name}=", parent_record)
          end

          objects << record
        end
      end
      self
    end
    alias_method :push, :<<
    alias_method :concat, :<<
    alias_method :append, :<<

    def delete(*records)
      records.flatten.uniq.each do |record|
        run_deferring_callbacks(:unlink, record) { objects.delete(record) }
      end
      self
    end

    def destroy(*records)
      records.flatten.uniq.each do |record|
        record = record.to_i if record.is_a? String
        record = objects.detect { |o| o.id == record } if record.is_a? Fixnum

        run_deferring_callbacks(:unlink, record) {
          objects.delete(record)
          record.mark_for_destruction if dependent && [:destroy, :delete_all].include?(dependent)
        }
      end
    end

    def build(*args, &block)
      klass.new(*args, &block).tap do |record|
        run_deferring_callbacks(:link, record) do
          if inverse_name && record.class.reflect_on_association(inverse_name)
            record.send(:"#{inverse_name}=", parent_record)
          end

          objects.push(record)
        end
      end
    end

    def create(*args, &block)
      association.create(*args, &block).tap do |_|
        @load_state = :ghost
        load_objects
      end
    end

    def create!(*args, &block)
      association.create!(*args, &block).tap do |_|
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
    def links
      return [] unless objects_loaded?
      objects - original_objects
    end
    alias_method :pending_creates, :links

    # Returns the associated records to which the links will be deleted after
    # saving the parent of the assocation.
    def unlinks
      # TODO: Write test for it.
      return [] unless objects_loaded?
      original_objects - objects
    end
    alias_method :pending_deletes, :unlinks

    def add_callback_listener(listener)
      (@listeners ||= []) << listener
    end

    private

    def association
      load_objects
      original_association
    end

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

    def original_objects
      load_objects
      @original_objects
    end

    def run_deferring_callbacks(event_name, record)
      notify_callback_listeners(:"before_#{event_name}", record)
      yield if block_given?
      notify_callback_listeners(:"after_#{event_name}", record)
    end

    def notify_callback_listeners(event_name, record)
      @listeners && @listeners.each do |listener|
        if listener.event_name == event_name
          listener.public_send(event_name, record)
        end
      end
    end

  end
end
