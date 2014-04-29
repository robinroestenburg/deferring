# encoding: UTF-8

require 'delay_many/version'
require 'delay_many/foo'

module DelayMany
  # Creates a wrapper around `has_and_belongs_to_many`. A normal habtm
  # association is created, but the association is decoracted by a
  # RaincheckAssociation. This will replace the accessor methods to the
  # association with our own which will not automatically save the association.
  def has_and_belongs_to_many_deferred(*args)
    has_and_belongs_to_many(*args)

    association_name = args.first.to_s

    # Store the original accessor methods of the association.
    alias_method :"original_#{association_name}", :"#{association_name}"
    alias_method :"original_#{association_name}=", :"#{association_name}="

    # Accessor for our own association.
    attr_accessor :"rainchecked_#{association_name}"

    # teams
    define_method :"#{association_name}" do
      find_or_create_rainchecked_association(association_name)
      send(:"rainchecked_#{association_name}")
    end

    # teams=
    define_method :"#{association_name}=" do |values|
      find_or_create_rainchecked_association(association_name)
      send(:"rainchecked_#{association_name}").values = values
    end

    # team_ids=
    define_method :"#{association_name.singularize}_ids=" do |ids|
      find_or_create_rainchecked_association(association_name)
      send(:"rainchecked_#{association_name}").ids = ids
    end

    # team_ids
    define_method :"#{association_name.singularize}_ids" do
      find_or_create_rainchecked_association(association_name)
      send(:"rainchecked_#{association_name}").ids
    end

    # performs the save after the parent object has been saved
    after_save :"perform_deferred_#{association_name}_save!"
    define_method :"perform_deferred_#{association_name}_save!" do
      find_or_create_rainchecked_association(association_name)

      # p send(:"original_#{association_name}")
      # p send(:"rainchecked_#{association_name}")

      # Send the values of our delegated association to the original
      # association and store the result.
      send(:"original_#{association_name}=",
           send(:"rainchecked_#{association_name}").values)

      # Store the new value of the association into our delegated association.
      send(
        :"rainchecked_#{association_name}=",
        Foo.new(association_name, send(:"original_#{association_name}")))
    end

    define_method :find_or_create_rainchecked_association do |name|
      if send(:"rainchecked_#{name}").nil?
        # TODO: Fix, so that it is loaded correctly for new objects.
        send(:"original_#{name}").to_a

        send(
          :"rainchecked_#{name}=",
          Foo.new(name, send(:"original_#{name}")))
      end
    end
  end

  def accepts_deferred_nested_attributes_for(*args)
    accepts_nested_attributes_for(*args)

    association_name = args.first.to_s

    # teams_attributes
    define_method :"#{association_name}_attributes=" do |records|
      find_or_create_rainchecked_association(association_name)
      records.each do |record|

        send(:"rainchecked_#{association_name}").add_by_id(record[:id]) unless record[:_destroy]
        send(:"rainchecked_#{association_name}").remove_by_id(record[:id]) if record[:_destroy]
      end
    end

    define_method :find_or_create_rainchecked_association do |name|
      if send(:"rainchecked_#{name}").nil?
        # TODO: Fix, so that it is loaded correctly for new objects.
        send(:"original_#{name}").to_a

        send(
          :"rainchecked_#{name}=",
          Foo.new(name, send(:"original_#{name}")))
      end
    end

  end
end

ActiveRecord::Base.send(:extend, DelayMany)
