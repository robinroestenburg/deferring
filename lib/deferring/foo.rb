# encoding: UTF-8

require 'delegate'

module Deferring
  class Foo < SimpleDelegator

    attr_reader :name, :values, :load_state

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
      add_record(record)
    end
    alias_method :push, :<<
    alias_method :concat, :<<

    def delete(record)
      delete_record(record)
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

    def pending_creates
      values - original_values
    end

    def pending_deletes
      original_values - values
    end

    # TODO: Move to private.
    def add_by_id(id)
      record = klass.find(id)
      add_record(record)
    end

    # TODO: Move to private.
    def remove_by_id(id)
      record = klass.find(id)
      delete_record(record)
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

    def add_record(record)
      unless existing_record?(record)
        values << record
      end
    end

    def delete_record(record)
      if existing_record?(record)
        values.delete(record)
      end
    end

    def existing_record?(record)
      values.index_by(&:id).has_key? record.id
    end

  end
end
