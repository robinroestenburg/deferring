# encoding: UTF-8

module DelayMany
  class Foo

    attr_reader :name, :values, :original_association

    def initialize(name, original_association)
      @name = name
      @original_association = original_association
      @values = original_association.target.clone
    end

    def set(values)
      @values = values
    end

    def ids=(ids)
      @values = ids.map do |id|
        item = name.singularize.classify.constantize.find(id)
      end
    end

    def ids
      @values.map(&:id)
    end

    def add_by_id(id)
      record = name.singularize.classify.constantize.find(id)
      unless @values.detect { |value| value.id == id }
        @values.push(record)
      end
    end

    def remove_by_id(id)
      record = name.singularize.classify.constantize.find(id)
      @values.reject! { |value| value.id == id }
    end

    delegate :[],
             :<<,
             :delete,
             :size,
             :length,
             :first,
             :last,
             to: :values

    def build(*args)
      result = @original_association.build(args)
      values.concat(result)
      values
    end

    def create!(*args)
      result = @original_association.create!(args)
      values.concat(result)
      values
    end

    # All other methods are delegated to the original association.
    def method_missing(*args, &block)
      original_association.send(*args, &block)
    end
  end
end
