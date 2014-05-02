# encoding: UTF-8

require 'delegate'

module Deferring
  class DeferredAssociation < SimpleDelegator

    attr_reader :name,
                :values,
                :load_state

    def initialize(name, original_association)
      super(original_association)
      @name = name
      @load_state = :ghost
    end

    alias_method :original_association, :__getobj__

    def klass
      if association.respond_to?(:klass)
        association.klass
      else
        name.singularize.classify.constantize
      end
    end

    delegate :[],
             :size,
             :length,
             to: :values

    def ids=(ids)
      ids = Array(ids).reject { |id| id.blank? }
      @values = klass.find(ids)
      @original_values = original_association.to_a.clone
      loaded!

      @values
    end

    def association
      load
      original_association
    end

    def values
      load
      @values
    end

    def original_values
      load
      @original_values
    end

    def values=(records)
      @values = records
      @original_values = original_association.to_a.clone
      loaded!

      @values
    end

    def ids
      values.map(&:id)
    end

    def <<(record)
      values << record unless values.include? record
    end
    alias_method :push, :<<
    alias_method :concat, :<<

    def delete(record)
      values.delete(record)
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

    def loaded!
      @load_state = :loaded
    end

    def loaded?
      @load_state == :loaded
    end

    def load
      return if loaded?

      @values = original_association.to_a.clone
      @original_values = @values.clone.freeze
      loaded!
    end

  end
end
