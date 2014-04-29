# encoding: UTF-8

require 'delegate'

module DelayMany
  class Foo < SimpleDelegator

    attr_reader :name, :values

    def initialize(name, original_association)
      super(original_association)

      @name = name
      @values = VirtualProxy.new { @values = original_association.to_a.clone }
    end

    alias_method :association, :__getobj__

    def ids=(ids)
      @values = ids.map { |id| klass.find(id) }
    end

    def ids
      @values.map(&:id)
    end

    def values=(records)
      @values = records.select { |record| add_record?(record) }
    end

    def add_record?(record)
      return false unless record
      !(values.detect { |value| value.id == record.id })
    end

    def add_record(record)
      values.push(record)
    end

    def add_by_id(id)
      add_record(klass.find(id)) if add_record?(klass.find(id))
    end

    def remove_by_id(id)
      if record = values.detect { |value| value.id == id }
        values.delete(record)
      end
    end

    delegate :[],
             :<<,
             :delete,
             :size,
             :length,
             to: :values

    def build(*args)
      result = association.build(args)
      values.concat(result)
      values
    end

    def create!(*args)
      result = association.create!(args)
      values.concat(result)
      values
    end

    def klass
      if association.respond_to?(:klass)
        association.klass
      else
        name.singularize.classify.constantize
      end
    end

  end
end
