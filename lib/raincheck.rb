require "raincheck/version"

module Raincheck

  class Foo

    attr_reader :name, :values, :original_association

    def initialize(name, original_association)
      @name = name
      @original_association = original_association
      @values = original_association.clone
    end

    delegate :[],
             :<<,
             :size,
             :delete,
             :length,
             :first,
             :last,
             to: :values

    # ActiveRecord::Relation
    # ==
    # any?
    # build
    def build(*args)
      result = @original_association.build(args)
      values.concat(result)
      values
    end

    # create, create!
    def create!(*args)
      result = @original_association.create!(args)
      values.concat(result)
      values
    end

    # delete, delete_all, destroy, destroy_all
    # eager_loading?, empty?, explain
    # first_or_create, first_or_create!, first_or_initialize
    # initialize_copy, insert, inspect
    # joined_includes_values
    # many?
    # new, new
    # reload, reset
    # scope_for_create, scoping, size
    # to_a, to_sql
    # update, update_all
    # where_values_hash#

    # ActiveRecord::QueryMethods
    # arel
    # bind, build_arel
    # create_with
    # eager_load, extending
    # from
    # group
    # having
    # includes
    # joins
    # limit, lock
    # offset, order
    # preload
    # readonly, reorder, reverse_order
    # select
    # uniq
    # where
    delegate :replace, :where, :klass, to: :original_association

    # ActiveRecord::Querying
    # count_by_sql
    # find_by_sql

    # ActiveRecord::FinderMethods
    # all, apply_join_dependency
    # construct_join_dependency_for_association_find,
    #   construct_limited_ids_condition,
    #   construct_relation_for_association_calculations,
    #   construct_relation_for_association_find
    # exists?
    # find, find_by_attributes, find_first, find_last, find_one,
    #   find_or_instantiator_by_attributes, find_some, find_with_associations,
    #   find_with_ids, first, first!
    # last, last!
    # using_limitable_reflections?

    # ActiveRecord::Calculations
    # average
    # calculate, count
    # maximum, minimum
    # pluck
    # sum#

    def set(values)
      @values = values
    end

    def set_ids(ids)
      @values = ids.map do |id|
        name.singularize.classify.constantize.find(id)
      end
    end

    def get_ids
      @values.map do |value|
        value.id
      end
    end

  end

  # Creates a wrapper around `has_and_belongs_to_many`. A normal habtm
  # association is created, but the association is decoracted by a
  # RaincheckAssociation. This will replace the accessor methods to the
  # association with our own which will not automatically save the association.
  def has_and_belongs_to_many_deferred(*args)
    has_and_belongs_to_many *args

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
      send(:"rainchecked_#{association_name}").set(values)
    end

    # team_ids=
    define_method :"#{association_name.singularize}_ids=" do |ids|
      find_or_create_rainchecked_association(association_name)
      send(:"rainchecked_#{association_name}").set_ids(ids)
    end

    # team_ids
    define_method :"#{association_name.singularize}_ids" do
      find_or_create_rainchecked_association(association_name)
      send(:"rainchecked_#{association_name}").get_ids
    end

    # performs the save after the parent object has been saved
    after_save :"perform_deferred_#{association_name}_save!"
    define_method :"perform_deferred_#{association_name}_save!" do
      find_or_create_rainchecked_association(association_name)

      # Send the values of our delegated association to the original association
      # and store the result.
      result = send(:"original_#{association_name}=", send(:"rainchecked_#{association_name}").values)

      # Store the new value of the association into our delegated association.
      send(
        :"rainchecked_#{association_name}=",
        Foo.new(association_name, send(:"original_#{association_name}")))
      result
    end

    define_method :find_or_create_rainchecked_association do |association_name|
      if send(:"rainchecked_#{association_name}").nil?
        send(
          :"rainchecked_#{association_name}=",
          Foo.new(association_name, send(:"original_#{association_name}")))
      end
    end

    # define_method "do_#{collection_name}_save!" do
    #   # Question: Why do we need this @use_original_collection_reader_behavior stuff?
    #   # Answer: Because AssociationCollection#replace(other_array) performs a
    #   # diff between current_array and other_array and deletes/adds only records
    #   # that have changed.
    #   #
    #   # In order to perform that diff, it needs to figure out what
    #   # "current_array" is, so it calls our collection_with_deferred_save, not
    #   # knowing that we've changed its behavior. It expects that method to
    #   # return the elements of that collection that are in the *database*
    #   # (the original behavior), so we have to provide that behavior...  If we
    #   # didn't provide it, it would end up trying to take the diff of two
    #   # identical collections so nothing would ever get saved.
    #   #
    #   # But we only want the old behavior in this case -- most of the time we
    #   # want the *new* behavior -- so we use
    #   # @use_original_collection_reader_behavior as a switch.

    #   self.send "use_original_collection_reader_behavior_for_#{collection_name}=", true
    #   if self.send("unsaved_#{collection_name}").nil?
    #     send("initialize_unsaved_#{collection_name}")
    #   end
    #   self.send "#{collection_name}_without_deferred_save=", self.send("unsaved_#{collection_name}")
    #     # /\ This is where the actual save occurs.
    #   self.send "use_original_collection_reader_behavior_for_#{collection_name}=", false

    #   true
    # end

  end

end

ActiveRecord::Base.send(:extend, Raincheck)

  # before_add :boo

  # def boo
  #   self.original_parrots = (self.unsaved_parrots || self.original_parrots.clone).flatten
  # end

  # alias_method :original_reload, :reload

  # def parrots
  #   self.unsaved_parrots ||= self.original_parrots.clone
  #     # /\ We initialize it to original_people in case they just loaded
  #     #  the object from the database, in which case we want unsaved_people
  #     #  to start out with the "saved people".
  #     #
  #     # If they just constructed a *new* object, this will work then too,
  #     #  because self.original_people.clone will return an empty array, [].
  #     #
  #     # Important: If we don't use clone, then it does an assignment by
  #     #  reference and any changes to unsaved_people will also change
  #     #  *original_people* (not what we want!)!
  # end

  # def parrot_ids
  #   parrots.map(&:id)
  # end

  # def parrot_ids=(ids)
  #   self.parrots = ids.map do |id|
  #     Parrot.find(id)
  #   end
  # end

  # def reload
  #   original_reload
  #   initialize_unsaved_parrots # If we didn't do this, then when we called
  #                              # reload, it would still have the same (possibly invalid) value of
  #                              # unsaved_people that it had before the reload.
  # end

  # def initialize_unsaved_parrots
  #   self.unsaved_parrots = self.original_parrots.clone
  # end
