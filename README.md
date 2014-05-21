# Deferring

Deferring makes it possible to delay saving ActiveRecord associations until the
parent object has been saved.

Currently supporting Rails 3.0, 3.2, 4.0 and 4.1.

It is important to note that Deferring does not touch the original `has_many`
and `has_and_belongs_to_many` associations. You can use them, without worrying
about any changed behaviour or side-effects from using Deferring.


## Why use it?

Let's take a look at the following example:

``` ruby
class Person
  has_and_belongs_to_many :teams
  validates :name, presence: true
end

class Team
  has_and_belongs_to_many :people
end

support = Team.create(name: 'Support')
person = Person.create(name: 'Bob')

person.teams << support
person.name = nil
person.save
# => false, because the name attribute is empty

Person.first.teams
# => [#<Team id: 4, name: "Support", ... ]
```

The links to the Teams associated to the Person are stored directly, before the
(in this case invalid) parent is actually saved. This is how Rails' `has_many`
and `has_and_belongs_to_many` associations work, but not how (imho) they should
work in this situation.

The `deferring` gem will delay creating the links between Person and Team until
the Person has been saved successfully. Let's look at the example again, only
now using the `deferring` gem:

``` ruby
class Person
  deferred_has_and_belongs_to_many :teams
  validates :name, presence: true
end

class Team
  has_and_belongs_to_many :people
end
support = Team.create(name: 'Support')
person = Person.create(name: 'Bob')

person.teams << support
person.name = nil
person.save
# => false, because the name attribute is empty

Person.first.teams
# => []
```


## Use cases

* Auditing
* ...


## Credits/Rationale

The idea for this gem was originally thought of by Tyler Rick (see [this Ruby
form thread from 2006](https://www.ruby-forum.com/topic/81095)). The gem created
by TylerRick is still
[available](https://github.com/TylerRick/has_and_belongs_to_many_with_deferred_save),
but unmaintained. This gem has been forked by Martin Koerner, who released his
fork as a gem called
[`deferred_associations`](https://rubygems.org/gems/deferred_associations).
Koerner fixes some issues with Rick's original implementation and added support
for Rails 3 and 4.

A project I am working on, uses the
[`autosave_habtm`](https://rubygems.org/gems/autosave_habtm) gem, which kind of
takes different approach to doing the same thing. This gem only supports Rails
3.0.

As we are upgrading to Rails 3.2 (and later Rails 4), I needed a gem to provide
this behaviour. Upgrading either one of the gems would result into rewriting a
lot of the code (for different reasons, some purely esthetic :)), so that is why
I wrote a new gem.


## Getting started

### Installation

Add this line to your application's Gemfile:

    gem 'deferring'

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install deferring


### How do I use it?

Deferring adds a couple of methods to your ActiveRecord models. These are:

- `deferred_has_and_belongs_to_many`
- `deferred_accepts_nested_attributes_for`
- `deferred_has_many`

These methods wrap the existing methods. For instance, `deferred_has_many` will
call `has_many` in order to set up the association.

**TODO** Describe pending_creates/pending_deletes/links/unlinks/callbacks/
original_name/checked.


### How does it work?

Deferring wraps the original ActiveRecord association and replaces the accessor
methods to the association by a custom object that will keep track of the
updates to the association. This wrapper is basically an array with some extras
to match the ActiveRecord API.

When the parent is saved, this object is assigned to the original association
(using an `after_save` callback on the parent model) which will automatically
save the changes to the database.

### Gotchas

#### Using custom callback methods

**TODO**: This is incorrect, rewrite.

You can use custom callback functions. However, the callbacks for defferred
associations are triggered at a different point in time.

An example to illustrate:

``` ruby
class Person < ActiveRecord::Base
  has_and_belongs_to_many :teams, before_add: :before_adding
  deferred_has_and_belongs_to_many :pets, before_add: :before_adding

  def audit_log
    @log = []
  end

  def before_adding(record)
    audit_log << "Before adding #{record.class} with id #{record.id}"
  end
end
```

This sets up a Person model that has a regular HABTM association with teams and
that has a deferred HABTM association with pets. Each time a team or pet is
added to the database a log statement is written to the audit log (using the
`before_adding` callback function).

The regular HABTM association behaves likes this:

``` ruby
person = Person.first
person.teams << Team.find(1)
person.audit_log # => ['Before adding Team 1']
```

As records of deferred associations are saved to the database after saving the
parent the behavior is a bit different:

``` ruby
person = Person.first
person.pets << Pet.find(1)
person.audit_log # => []

person.save
person.audit_log # => ['Before adding Pet 1']
```

## TODO

* check out what is going on with uniq: true
* collection(true) (same as reload)
* collection.replace
* `set_inverse_instance`?
* add service on one side of the collection, will not make it through to the
  other side?
* validations!

## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request
