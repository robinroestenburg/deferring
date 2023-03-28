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
    autosave = options.fetch(:autosave, true)
    validate = options.fetch(:validate, true)

    has_and_belongs_to_many(*args, **options)
    generate_deferred_association_methods(
      args.first.to_s,
      listeners,
      autosave: autosave,
      type: :habtm,
      validate: validate)
  end

  # Creates a wrapper around `has_many`. A normal has many association is
  # created, but this association is wrapped in a DeferredAssociation. The
  # accessor methods of the original association are replaced with ones that
  # will defer saving the association until the parent object has been saved.
  def deferred_has_many(*args)
    options = args.extract_options!
    listeners = create_callback_listeners!(options)
    inverse_association_name = options[:as] || options[:inverse_of] || self.name.underscore.to_sym
    autosave = options.fetch(:autosave, true)
    validate = options.fetch(:validate, true)

    has_many(*args, **options)
    generate_deferred_association_methods(
      args.first.to_s,
      listeners,
      inverse_association_name: inverse_association_name,
      autosave: autosave,
      type: :has_many,
      dependent: options[:dependent],
      validate: validate)
  end

  def deferred_accepts_nested_attributes_for(*args)
    options = args.extract_options!
    reject_if = options.delete(:reject_if)
    accepts_nested_attributes_for(*args, options)

    association_name = args.first.to_s

    # teams_attributes=
    define_method :"#{association_name}_attributes=" do |attributes_collection|
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
          if !send(:"deferred_#{association_name}_reject_new_record?", attributes)
            send(:"#{association_name}").build(attributes.except(*deferred_unassignable_keys))
          end

        elsif existing_record = send(:"#{association_name}").detect { |record| record.id.to_s == attributes['id'].to_s }
          if !send(:"deferred_#{association_name}_call_reject_if", attributes)

            existing_record.attributes = attributes.except(*deferred_unassignable_keys)

            # TODO: Implement value_to_boolean code from rails for checking _destroy field.
            if attributes['_destroy'] == '1' && options[:allow_destroy]
              # remove from existing records and mark for destruction upon
              # saving
              send(:"#{association_name}").delete(existing_record)
              existing_record.mark_for_destruction
            end
          end

        else # new record referenced by id
          if !send(:"deferred_#{association_name}_call_reject_if", attributes)
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
    define_method :"deferred_#{association_name}_reject_new_record?" do |attributes|
      # TODO: Implement value_to_boolean code from rails for checking _destroy field.
      attributes['_destroy'] == '1' || send(:"deferred_#{association_name}_call_reject_if", attributes)
    end

    define_method :"deferred_#{association_name}_call_reject_if" do |attributes|
      return false if attributes['_destroy'] == '1'
      case callback = reject_if
      when Symbol
        method(callback).arity == 0 ? send(callback) : send(callback, attributes)
      when Proc
        callback.call(attributes)
      end
    end

    define_method :deferred_unassignable_keys do
      %w(_destroy id)
    end
  end

  private

  def generate_deferred_association_methods(association_name, listeners, options = {})
    deferred_association_name = :"deferred_#{association_name}"
    inverse_association_name  = options[:inverse_association_name]
    autosave                  = options.fetch(:autosave, true)
    type                      = options.fetch(:type)
    validate                  = options.fetch(:validate, true)
    dependent                 = options[:dependent]

    # Store the original accessor methods of the association.
    alias_method :"original_#{association_name}", :"#{association_name}"
    alias_method :"original_#{association_name}=", :"#{association_name}="

    # Accessor for our own association.
    define_method(deferred_association_name) do
      return instance_variable_get(:"@#{deferred_association_name}") if instance_variable_defined?(:"@#{deferred_association_name}")

      klass = self.class.reflect_on_association(:"#{association_name}").klass
      deferred_association = DeferredAssociation.new(send(:"original_#{association_name}"),
                                                     klass,
                                                     self,
                                                     inverse_association_name,
                                                     dependent)
      listeners.each do |event_name, callback_method|
        deferred_association.add_callback_listener(event_name, callback_method)
      end

      instance_variable_set(:"@#{deferred_association_name}", deferred_association)
    end

    define_method :"#{deferred_association_name}=" do |deferred_association|
      instance_variable_set(:"@#{deferred_association_name}", deferred_association)
    end

    # collection
    #
    # Returns an array of all the associated objects. An empty array is returned
    # if none are found.
    define_method :"#{association_name}" do
      send(deferred_association_name)
    end

    # collection=objects
    #
    # Replaces the collection's content by deleting and adding objects as
    # appropriate.
    define_method :"#{association_name}=" do |objects|
      send(deferred_association_name).objects = objects
    end

    # collection_singular_ids=
    #
    # Replace the collection by the objects identified by the primary keys in
    # ids.
    define_method :"#{association_name.singularize}_ids=" do |ids|
      ids ||= []
      klass = self.class.reflect_on_association(:"#{association_name}").klass
      objects = klass.find(ids.reject(&:blank?))

      send(deferred_association_name).objects = objects
    end

    # collection_singular_ids
    #
    # Returns an array of the associated objects' ids.
    define_method :"#{association_name.singularize}_ids" do
      send(deferred_association_name).ids
    end

    # collection_singular_checked
    attr_accessor :"#{association_name}_checked"
    # collection_singular_checked=
    define_method(:"#{association_name}_checked=") do |ids|
      ids ||= ''
      send(:"#{association_name.singularize}_ids=", ids.split(','))
    end

    # Prepend #changed_for_autosave? and #reload methods to extend existing
    # behavior in ActiveRecord.
    self.prepend(Module.new do
      define_method :changed_for_autosave? do
        super() || send(deferred_association_name).changed_for_autosave?
      end

      define_method :reload do |*args|
        super(*args).tap do
          update_deferred_association(association_name, listeners, inverse_association_name, dependent)
        end
      end
    end)

    after_validation :"perform_#{deferred_association_name}_validation!"
    define_method :"perform_#{deferred_association_name}_validation!" do
      # Do not perform validations for HABTM associations as they are always
      # validated by Rails upon saving.
      return true if type == :habtm

      # Do not perform validation when the association has not been loaded
      # (performance improvement).
      return true unless send(deferred_association_name).loaded?

      # Do not perform validations when validate: false.
      return true if validate == false

      all_records_valid = send(deferred_association_name).objects.inject(true) do |valid, record|
        unless record.valid?
          valid = false
          if autosave
            if ActiveRecord::VERSION::MAJOR == 6 && ActiveRecord::VERSION::MINOR == 1
              record.errors.group_by_attribute.each do |attribute, errors|
                errors.each do |error|
                  self.errors.import(
                    error,
                    attribute: "#{association_name}.#{attribute}"
                  )
                end
              end
            else
              record.errors.each do |attribute, message|
                attribute = "#{association_name}.#{attribute}"
                errors[attribute] << message
                errors[attribute].uniq!
              end
            end
          else
            errors.add(association_name)
          end
        end
        valid
      end
      return true if all_records_valid

      false
    end

    #  the save after the parent object has been saved
    after_save :"perform_#{deferred_association_name}_save!"
    define_method :"perform_#{deferred_association_name}_save!" do
      # Send the objects of our delegated association to the original
      # association and store the result.
      deferred_association = send(deferred_association_name)
      if deferred_association.send(:objects_loaded?)
        send(:"original_#{association_name}").delete(deferred_association.unlinks)
        unless send(:"original_#{association_name}").push(deferred_association.links)
          raise ActiveRecord::RecordNotSaved,
            "Failed to replace #{association_name} because one or more of " \
            "the new records could not be saved."
        end
      end

      # Store the new value of the association into our delegated association.
      update_deferred_association(association_name, listeners, inverse_association_name, dependent)
    end

    generate_update_deferred_assocation_method
  end

  def generate_update_deferred_assocation_method
    define_method :update_deferred_association do |name, listeners, inverse_association_name, dependent|
      klass = self.class.reflect_on_association(:"#{name}").klass
      deferred_association = DeferredAssociation.new(send(:"original_#{name}"), klass, self, inverse_association_name, dependent)
      listeners.each do |event_name, callback_method|
        deferred_association.add_callback_listener(event_name, callback_method)
      end
      send(:"deferred_#{name}=", deferred_association)
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
