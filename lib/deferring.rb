# encoding: UTF-8

require 'deferring/version'
require 'deferring/deferred_association'
require 'deferring/deferred_callback_listener'

module Deferring
  # Creates a wrapper around `has_and_belongs_to_many`. A normal habtm
  # association is created, but this association is wrapped in a
  # DeferredAssociation. The accessor methods of the original association are
  # replaced with ones that will defer saving the association until the parent
  # object has been saved.
  def deferred_has_and_belongs_to_many(*args)
    options = args.extract_options!
    listeners = create_callback_listeners!(options)

    has_and_belongs_to_many(*args, options)
    generate_deferred_association_methods(args.first.to_s, listeners)
  end

  # Creates a wrapper around `has_many`. A normal has many association is
  # created, but this association is wrapped in a DeferredAssociation. The
  # accessor methods of the original association are replaced with ones that
  # will defer saving the association until the parent object has been saved.
  def deferred_has_many(*args)
    options = args.extract_options!
    listeners = create_callback_listeners!(options)
    inverse_association_name = options.fetch(:as, self.name.underscore.to_sym)

    has_many(*args, options)
    generate_deferred_association_methods(args.first.to_s, listeners, inverse_association_name)
  end

  def deferred_accepts_nested_attributes_for(*args)
    options = args.extract_options!
    inverse_association_name = options.fetch(:as, self.name.underscore.to_sym)
    reject_if = options.delete(:reject_if)
    accepts_nested_attributes_for(*args, options)

    association_name = args.first.to_s

    # teams_attributes=
    define_method :"#{association_name}_attributes=" do |attributes_collection|
      find_or_create_deferred_association(association_name, [], inverse_association_name)

      unless attributes_collection.is_a?(Hash) || attributes_collection.is_a?(Array)
        raise ArgumentError, "Hash or Array expected, got #{attributes_collection.class.name} (#{attributes_collection.inspect})"
      end

      # TODO: Implement :limit checks. Check rails source.

      if attributes_collection.is_a? Hash
        keys = attributes_collection.keys
        attributes_collection = if keys.include?('id') || keys.include?(:id)
          [attributes_collection]
        else
          attributes_collection.values
        end
      end

      attributes_collection.each do |attributes|
        attributes = attributes.with_indifferent_access

        if attributes['id'].blank?
          if !reject_new_record?(attributes)
            send(:"#{association_name}").build(attributes.except(*unassignable_keys))
          end

        elsif existing_record = send(:"#{association_name}").detect { |record| record.id.to_s == attributes['id'].to_s }
          if !call_reject_if(attributes)

            existing_record.attributes = attributes.except(*unassignable_keys)

            # TODO: Implement value_to_boolean code from rails for checking _destroy field.
            if attributes['_destroy'] == '1' && options[:allow_destroy]
              # remove from existing records
              send(:"#{association_name}").delete(existing_record)
            end
          end

        else # new record referenced by id
          if !call_reject_if(attributes)
            klass = self.class.reflect_on_association(:"#{association_name}").klass

            attribute_ids = attributes_collection.map { |a| a['id'] || a[:id] }.compact
            # TODO: Find out how to get send(:"#{association_name}").scoped.where working
            new_records = attribute_ids.empty? ? [] : klass.where(klass.primary_key => attribute_ids)
            new_record = new_records.detect { |record| record.id.to_s == attributes['id'].to_s }

            send(:"#{association_name}").push(new_record)
          end
        end
      end
    end

    # Determines if a new record should be build by checking for
    # has_destroy_flag? or if a <tt>:reject_if</tt> proc exists for this
    # association and evaluates to +true+.
    define_method :reject_new_record? do |attributes|
      # TODO: Implement value_to_boolean code from rails for checking _destroy field.
      attributes['_destroy'] == '1' || call_reject_if(attributes)
    end

    define_method :call_reject_if do |attributes|
      return false if attributes['_destroy'] == '1'
      case callback = reject_if
      when Symbol
        method(callback).arity == 0 ? send(callback) : send(callback, attributes)
      when Proc
        callback.call(attributes)
      end
    end

    define_method :unassignable_keys do
      %w(_destroy)
    end

    generate_find_or_create_deferred_association_method
  end

  private

  def generate_deferred_association_methods(association_name, listeners, inverse_association_name = nil)
    # Store the original accessor methods of the association.
    alias_method :"original_#{association_name}", :"#{association_name}"
    alias_method :"original_#{association_name}=", :"#{association_name}="

    # Accessor for our own association.
    attr_accessor :"deferred_#{association_name}"

    # collection
    #
    # Returns an array of all the associated objects. An empty array is returned
    # if none are found.
    # TODO: add force_reload argument?
    define_method :"#{association_name}" do
      find_or_create_deferred_association(association_name, listeners, inverse_association_name)
      send(:"deferred_#{association_name}")
    end

    # collection=objects
    #
    # Replaces the collection's content by deleting and adding objects as
    # appropriate.
    define_method :"#{association_name}=" do |objects|
      find_or_create_deferred_association(association_name, listeners, inverse_association_name)
      send(:"deferred_#{association_name}").objects = objects
    end

    # collection_singular_ids=
    #
    # Replace the collection by the objects identified by the primary keys in
    # ids.
    define_method :"#{association_name.singularize}_ids=" do |ids|
      find_or_create_deferred_association(association_name, listeners, inverse_association_name)

      klass = self.class.reflect_on_association(:"#{association_name}").klass
      objects = klass.find(ids.reject(&:blank?))
      send(:"deferred_#{association_name}").objects = objects
    end

    # collection_singular_ids
    #
    # Returns an array of the associated objects' ids.
    define_method :"#{association_name.singularize}_ids" do
      find_or_create_deferred_association(association_name, listeners, inverse_association_name)
      send(:"deferred_#{association_name}").ids
    end

    # collection_singular_checked
    attr_accessor :"#{association_name}_checked"
    # collection_singular_checked=
    define_method(:"#{association_name}_checked=") do |ids|
      send(:"#{association_name.singularize}_ids=", ids.split(','))
    end

    #  the save after the parent object has been saved
    after_save :"perform_deferred_#{association_name}_save!"
    define_method :"perform_deferred_#{association_name}_save!" do
      find_or_create_deferred_association(association_name, listeners, inverse_association_name)

      # Send the objects of our delegated association to the original
      # association and store the result.
      send(:"original_#{association_name}=", send(:"deferred_#{association_name}").objects)

      # Store the new value of the association into our delegated association.
      save_deferred_association(association_name, listeners, inverse_association_name)
    end

    define_method :"reload_with_deferred_#{association_name}" do |*args|
      find_or_create_deferred_association(association_name, listeners, inverse_association_name)

      send(:"reload_without_deferred_#{association_name}", *args).tap do
        save_deferred_association(association_name, listeners, inverse_association_name)
      end
    end
    alias_method_chain :reload, :"deferred_#{association_name}"

    generate_save_deferred_assocation_method
    generate_find_or_create_deferred_association_method
  end

  def generate_save_deferred_assocation_method
    define_method :save_deferred_association do |name, listeners, inverse_association_name|
      klass = self.class.reflect_on_association(:"#{name}").klass
      send(
        :"deferred_#{name}=",
        DeferredAssociation.new(send(:"original_#{name}"), klass, self, inverse_association_name))
      listeners.each do |event_name, callback_method|
        l = DeferredCallbackListener.new(event_name, self, callback_method)
        send(:"deferred_#{name}").add_callback_listener(l)
      end
    end
  end

  def generate_find_or_create_deferred_association_method
    define_method :find_or_create_deferred_association do |name, listeners, inverse_association_name|
      if send(:"deferred_#{name}").nil?
        save_deferred_association(name, listeners, inverse_association_name)
      end
    end
  end

  def create_callback_listeners!(options)
    [:before_link, :before_unlink, :after_link, :after_unlink].map do |event_name|
      callback_method = options.delete(event_name)
      [event_name, callback_method] if callback_method
    end.compact
  end

end

ActiveRecord::Base.send(:extend, Deferring)
