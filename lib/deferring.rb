# encoding: UTF-8

require 'deferring/version'
require 'deferring/proxy'
require 'deferring/foo'

module Deferring
  # Creates a wrapper around `has_and_belongs_to_many`. A normal habtm
  # association is created, but the association is decoracted by a
  # DeferredAssociation. This will replace the accessor methods to the
  # association with our own which will not automatically save the association.
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
        Foo.new(association_name, send(:"original_#{association_name}")))
    end

    define_method :find_or_create_deferred_association do |name|
      if send(:"deferred_#{name}").nil?
        send(:"deferred_#{name}=", Foo.new(name, send(:"original_#{name}")))
      end
    end
  end

  def deferred_accepts_nested_attributes_for(*args)
    accepts_nested_attributes_for(*args)

    association_name = args.first.to_s

    # teams_attributes=
    define_method :"#{association_name}_attributes=" do |records|
      find_or_create_deferred_association(association_name)
      records.each do |record|

        send(:"deferred_#{association_name}").add_by_id(record[:id]) unless record[:_destroy]
        send(:"deferred_#{association_name}").remove_by_id(record[:id]) if record[:_destroy]
      end
    end

    # TODO: Already defined?
    define_method :find_or_create_deferred_association do |name|
      if send(:"deferred_#{name}").nil?
        send(:"deferred_#{name}=", Foo.new(name, send(:"original_#{name}")))
      end
    end

  end
end

ActiveRecord::Base.send(:extend, Deferring)
