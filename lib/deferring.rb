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

    # teams
    define_method :"#{association_name}" do
      find_or_create_deferred_association(association_name)
      send(:"deferred_#{association_name}")
    end

    # teams=
    define_method :"#{association_name}=" do |values|
      find_or_create_deferred_association(association_name)
      send(:"deferred_#{association_name}").values = values
    end

    # team_ids=
    define_method :"#{association_name.singularize}_ids=" do |ids|
      find_or_create_deferred_association(association_name)
      send(:"deferred_#{association_name}").ids = ids
    end

    # team_ids
    define_method :"#{association_name.singularize}_ids" do
      find_or_create_deferred_association(association_name)
      send(:"deferred_#{association_name}").ids
    end

    # performs the save after the parent object has been saved
    after_save :"perform_deferred_#{association_name}_save!"
    define_method :"perform_deferred_#{association_name}_save!" do
      find_or_create_deferred_association(association_name)

      # Send the values of our delegated association to the original
      # association and store the result.
      send(:"original_#{association_name}=",
           send(:"deferred_#{association_name}").values)

      # Store the new value of the association into our delegated association.
      send(
        :"deferred_#{association_name}=",
        DeferredAssociation.new(
          association_name,
          send(:"original_#{association_name}")))
    end

    define_method :find_or_create_deferred_association do |name|
      if send(:"deferred_#{name}").nil?
        send(
          :"deferred_#{name}=",
          DeferredAssociation.new(name, send(:"original_#{name}")))
      end
    end
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

      send(:"deferred_#{association_name}").ids = records.map { |record| record[:id] }
    end

    # TODO: Already defined?
    define_method :find_or_create_deferred_association do |name|
      if send(:"deferred_#{name}").nil?
        send(:"deferred_#{name}=", DeferredAssociation.new(name, send(:"original_#{name}")))
      end
    end

  end
end

ActiveRecord::Base.send(:extend, Deferring)
