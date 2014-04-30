# encoding: UTF-8

require 'delegate'

module Deferring
  class Foo < SimpleDelegator

    attr_reader :name, :values

    def initialize(name, original_association)
      super(original_association)
      @name = name
      @values = VirtualProxy.new { @values = original_association.to_a.clone }
    end

    alias_method :association, :__getobj__

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
      # TODO: Change to replace implementation.
      @values = klass.find(ids)
    end

    def values=(records)
      # TODO: Change to replace implementation.
      old_ids = values.map(&:id).compact
      new_ids = records.map(&:id).compact

      @pending_creates = klass.find(new_ids - old_ids)
      @pending_deletes = klass.find(old_ids - new_ids)

      @values = records
    end

    def ids
      @values.map(&:id)
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
      @pending_creates ||= []
    end

    def pending_deletes
      @pending_deletes ||= []
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

    def add_record(record)
      unless existing_record?(record)
        pending_creates << record
        values << record
      end
    end

    def delete_record(record)
      if existing_record?(record)
        pending_deletes << record
        values.delete(record)
      end
    end

    def existing_record?(record)
      values.index_by(&:id).has_key? record.id
    end

  end
end
