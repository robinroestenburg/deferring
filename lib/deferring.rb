# encoding: UTF-8

require 'deferring/version'
require 'deferring/deferred_association'

module Deferring
  # Creates a wrapper around `has_and_belongs_to_many`. A normal habtm
  # association is created, but this association is wrapped in a
  # DeferredAssociation. The accessor methods of the original association are
  # replaced with ones that will defer saving the association until the parent
  # object has been saved.
  def deferred_has_and_belongs_to_many(*args)
    has_and_belongs_to_many(*args)
    association_name = args.first.to_s

    # Store the original accessor methods of the association.
    alias_method :"original_#{association_name}", :"#{association_name}"
    alias_method :"original_#{association_name}=", :"#{association_name}="

    # Accessor for our own association.
    attr_accessor :"deferred_#{association_name}"

    # before/afer remove callbacks
    define_callbacks :deferred_remove, scope: [:kind, :name]
    set_callback :deferred_remove, :before, lambda { |record|
      send(:"before_removing_#{association_name.singularize}", self.instance_variable_get(:@deferred_remove))
    }
    set_callback :deferred_remove, :after, lambda { |record|
      send(:"after_removing_#{association_name.singularize}", self.instance_variable_get(:@deferred_remove))
    }
    define_method :"before_removing_#{association_name.singularize}" do |record|
    end
    define_method :"after_removing_#{association_name.singularize}" do |record|
    end

    # collection
    #
    # Returns an array of all the associated objects. An empty array is returned
    # if none are found.
    # TODO: add force_reload argument?
    define_method :"#{association_name}" do
      find_or_create_deferred_association(association_name)
      send(:"deferred_#{association_name}")
    end

    # collection=objects
    #
    # Replaces the collection's content by deleting and adding objects as
    # appropriate.
    define_method :"#{association_name}=" do |objects|
      find_or_create_deferred_association(association_name)
      send(:"deferred_#{association_name}").objects = objects
    end

    # collection_singular_ids=
    #
    # Replace the collection by the objects identified by the primary keys in
    # ids.
    define_method :"#{association_name.singularize}_ids=" do |ids|
      find_or_create_deferred_association(association_name)

      klass = self.class.reflect_on_association(:"#{association_name}").klass
      objects = klass.find(ids)
      send(:"deferred_#{association_name}").objects = objects
    end

    # collection_singular_ids
    #
    # Returns an array of the associated objects' ids.
    define_method :"#{association_name.singularize}_ids" do
      find_or_create_deferred_association(association_name)
      send(:"deferred_#{association_name}").ids
    end

    # performs the save after the parent object has been saved
    after_save :"perform_deferred_#{association_name}_save!"
    define_method :"perform_deferred_#{association_name}_save!" do
      find_or_create_deferred_association(association_name)

      # Send the objects of our delegated association to the original
      # association and store the result.
      send(:"original_#{association_name}=",
           send(:"deferred_#{association_name}").objects)

      # Store the new value of the association into our delegated association.
      send(
        :"deferred_#{association_name}=",
        DeferredAssociation.new(send(:"original_#{association_name}"), self))

    end

    define_method :"reload_with_deferred_#{association_name}" do |*args|
      find_or_create_deferred_association(association_name)

      send(:"reload_without_deferred_#{association_name}", *args).tap do
        send(
          :"deferred_#{association_name}=",
          DeferredAssociation.new(send(:"original_#{association_name}"), self))
      end
    end
    alias_method_chain :reload, :"deferred_#{association_name}"

    generate_find_or_create_deferred_association_method
  end

  def deferred_accepts_nested_attributes_for(*args)
    accepts_nested_attributes_for(*args)
    association_name = args.first.to_s

    # teams_attributes=
    define_method :"#{association_name}_attributes=" do |records|
      find_or_create_deferred_association(association_name)

      # Remove the records that are to be destroyed from the ids that are to be
      # assigned to the DeferredAssociation instance.
      records.reject! { |record| record[:_destroy] }

      klass = self.class.reflect_on_association(:"#{association_name}").klass
      objects = klass.find(records.map { |record| record[:id] })
      send(:"deferred_#{association_name}").objects = objects
    end

    generate_find_or_create_deferred_association_method
  end

  def generate_find_or_create_deferred_association_method
    define_method :find_or_create_deferred_association do |name|
      if send(:"deferred_#{name}").nil?
        send(
          :"deferred_#{name}=",
          DeferredAssociation.new(send(:"original_#{name}"), self))
      end
    end
  end
end

ActiveRecord::Base.send(:extend, Deferring)
