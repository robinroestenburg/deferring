# encoding: UTF-8

require 'delegate'

module Deferring
  class DeferredAssociation < SimpleDelegator

    attr_reader :values,
                :load_state

    def initialize(original_association)
      super(original_association)
      @load_state = :ghost
    end

    alias_method :original_association, :__getobj__

    delegate :[],
             :size,
             :length,
             to: :values

    def association
      load_objects
      original_association
    end

    def values
      load_objects
      @values
    end

    def original_values
      load_objects
      @original_values
    end

    def values=(records)
      @values = records
      @original_values = original_association.to_a.clone
      objects_loaded!

      @values
    end

    def ids
      values.map(&:id)
    end

    def <<(records)
      # TODO: Do we want to prevent including the same object twice? Not sure,
      # but it will probably be filtered after saving and retrieving as well.
      values.concat(Array(records).flatten)
    end
    alias_method :push, :<<
    alias_method :concat, :<<
    alias_method :append, :<<

    def delete(records)
      Array(records).flatten.uniq.each do |record|
        values.delete(record)
      end
      self
    end

    def build(*args)
      association.build(args).tap do |result|
        values.concat(result)
      end
    end

    def create!(*args)
      association.create!(args).tap do |result|
        values.concat(result)
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
      values - original_values
    end

    # Returns the associated records to which the links will be deleted after
    # saving the parent of the assocation.
    def pending_deletes
      original_values - values
    end

    private

    def objects_loaded!
      @load_state = :loaded
    end

    def objects_loaded?
      @load_state == :loaded
    end

    def load_objects
      return if objects_loaded?

      @values = original_association.to_a.clone
      @original_values = @values.clone.freeze
      objects_loaded!
    end

  end
end
