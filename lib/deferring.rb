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
    reject_if_proc = options.delete(:reject_if)
    accepts_nested_attributes_for(*args, options)

    association_name = args.first.to_s

    # teams_attributes=
    define_method :"#{association_name}_attributes=" do |attributes|
      find_or_create_deferred_association(association_name, [], inverse_association_name)

      # Convert the attributes to an array if a Hash is passed. This is possible
      # as the keys of the hash are ignored in this case.
      #
      # Example:
      #   {
      #     first: { name: 'Service Desk' },
      #     second: { name: 'DBA' }
      #   }
      #   becomes
      #   [
      #     { name: 'Service Desk' },
      #     { name: 'DBA'}
      #   ]
      attributes = attributes.values if attributes.is_a? Hash

      # Remove the attributes that are to be destroyed from the ids that are to
      # be assigned to the DeferredAssociation instance.
      attributes.reject! { |record| record.delete(:_destroy) == '1' }

      # Remove the attributes that fail the pass :reject_if proc.
      attributes.reject! { |record| reject_if_proc.call(record) } if reject_if_proc

      klass = self.class.reflect_on_association(:"#{association_name}").klass

      objects = attributes.map do |record|
        record[:id] ? klass.find(record[:id]) : klass.new(record)
      end

      send(:"deferred_#{association_name}").objects = objects
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
