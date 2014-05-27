# encoding: UTF-8

require 'delegate'

module Deferring
  class DeferredAssociation < SimpleDelegator
    # TODO: Write tests for enumerable.
    include Enumerable

    attr_reader :load_state

    def initialize(original_association, obj, name)
      super(original_association)
      @name = name
      @obj = obj
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

      pending_deletes.each do |record|
        # TODO: I don't like the fact that we know something about @obj in here.
        #       Refactor to remove that (some kind of notification), it looks
        #       terrible this way ;(
        @obj.instance_variable_set(:"@deferred_#{@name.singularize}_remove", record)
        @obj.run_callbacks :"deferred_#{@name.singularize}_remove"
        @obj.send(:remove_instance_variable, :"@deferred_#{@name.singularize}_remove")
      end

      pending_creates.each do |record|
        @obj.instance_variable_set(:"@deferred_#{@name.singularize}_add", record)
        @obj.run_callbacks :"deferred_#{@name.singularize}_add"
        @obj.send(:remove_instance_variable, :"@deferred_#{@name.singularize}_add")
      end

      @objects
    end

    def ids
      objects.map(&:id)
    end

    def <<(records)
      # TODO: Do we want to prevent including the same object twice? Not sure,
      # but it will probably be filtered after saving and retrieving as well.
      Array(records).flatten.uniq.each do |record|
        @obj.instance_variable_set(:"@deferred_#{@name.singularize}_add", record)
        @obj.run_callbacks :"deferred_#{@name.singularize}_add" do
          objects << record
        end
        @obj.send(:remove_instance_variable, :"@deferred_#{@name.singularize}_add")
      end
      objects
    end
    alias_method :push, :<<
    alias_method :concat, :<<
    alias_method :append, :<<

    def delete(records)
      Array(records).flatten.uniq.each do |record|
        @obj.instance_variable_set(:"@deferred_#{@name.singularize}_remove", record)
        @obj.run_callbacks :"deferred_#{@name.singularize}_remove" do
          objects.delete(record)
        end
        @obj.send(:remove_instance_variable, :"@deferred_#{@name.singularize}_remove")
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

  end
end
