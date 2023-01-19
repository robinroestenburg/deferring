# Deferring

[![Build Status](http://img.shields.io/travis/robinroestenburg/deferring.svg?style=flat)](https://travis-ci.org/robinroestenburg/deferring)
[![Gem Version](http://img.shields.io/gem/v/deferring.svg?style=flat)](https://rubygems.org/gems/deferring)

Deferring makes it possible to delay saving ActiveRecord associations until the
parent object has been saved.

Currently supporting Rails 5.x, 6.0 & 6.1 on MRI Ruby 2.5+.

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

Deferring adds a couple of methods to your ActiveRecord classes. These are:

- `deferred_has_and_belongs_to_many`
- `deferred_accepts_nested_attributes_for`
- `deferred_has_many`

These methods wrap the existing methods. For instance,
`deferred_has_and_belongs_to_many` will call `has_and_belongs_to_many` in order
to set up the association.

In order to create a deferred association, you can just replace the regular
method by one provided by Deferring.

Simple!

Next to that, Deferring adds the following functionality:
* new callbacks that are triggered when adding/removing a record to the
  deferred association before saving the parent, and
* new methods on the deferred association to retrieve the records that are to be
  linked to/unlinked from the parent.

#### Callbacks

##### Rails' callbacks

You can use the regular Rails callbacks on deferred associations. However, these
callbacks are triggered at a different point in time.

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
`before_adding` callback method).

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

##### New link and unlink callbacks

As said, the regular `:before_add`, etc. callbacks still work, but they are only
triggered after the parent object has been saved. You can use the following
callbacks when you want a method to be executed when adding/deleting a record to
the deferred association *before saving* the parent:
* `:before_link`
* `:after_link`
* `:before_unlink`
* `:after_unlink`

Another example to illustrate:

``` ruby
class Person < ActiveRecord::Base
  deferred_has_and_belongs_to_many :pets, before_link: :link_pet

  def audit_log
    @log = []
  end

  def link_pet(pet)
    audit_log << "Before linking #{pet.class} with id #{pet.id}"
  end
end
```

This sets up a Person model that has a deferred HABTM association to pets. Each
time a pet is linked to the Person a log statement is written to the audit log
(using the `link_pet` callback function).

``` ruby
person = Person.first
person.pets << Pet.find(1)
person.audit_log # => ['Before linking Pet with id 1']

person.save
person.audit_log # => ['Before linking Pet with id 1']
```

As you can see, the callback method will not be called again when saving the
parent object.

Note that, instead of a `:before_link` callback, you can also use a
`before_save` callback on the Person model that calls the `link_pet` method on
each of the pets that are to be linked to the parent object.

#### Links and unlinks

In some cases, you want to know which records are going to be linked or unlinked
from the parent object. Deferring provides this information with the following
methods:
* `association.links`
* `association.unlinks`

These are aliased as `:pending_creates` and `:pending_deletes`. I am not sure if
this will be supported in the future, so do not depend on it.

An example:

Writing to the audit log is very expensive. Writing to it every time a record is
added would slow down the application. In this case, you want to write to the
audit log in bulk. Here is how you could do that using Deferring:

``` ruby
class Person < ActiveRecord::Base
  deferred_has_and_belongs_to_many :pets

  before_save :log_linked_pets

  def log_linked_pets
    ids = pending_creates.map(&:id)
    audit_log << "Linking pets: #{ids.join(',')}"
  end

  def audit_log
    @log = []
  end
end
```

### How does it work?

Deferring wraps the original ActiveRecord association and replaces the accessor
methods to the association by a custom object that will keep track of the
updates to the association. This wrapper is basically an array with some extras
to match the ActiveRecord API.

When the parent is saved, this object is assigned to the original association
(using an `after_save` callback on the parent model) which will automatically
save the changes to the database.

For the astute reader: Yes, the gem abuses the exact problem it is trying to
avoid ;-)

### Gotchas

#### Using autosave (or not, actually)

TL;DR; Using `autosave: true` (or false) on a deferred association does not do
anything.

This is what the Rails documentation says about the AutosaveAssociation:

_AutosaveAssociation is a module that takes care of automatically saving
associated records when their parent is saved. In addition to saving, it also
destroys any associated records that were marked for destruction._

_If validations for any of the associations fail, their error messages will be
applied to the parent._

The `deferring` gem works with `pending_deletes` (or the alias `unlinks`)
instead of the `marked_for_destruction` flag, so everything related to that in
AutosaveAssociation does not work as you would expect.

Also, `deferring` adds the associated records present in a deferred
association to the original (in this case, autosaved) association by assigning
the array of associated records to original association. This kind of assignment
bypasses the autosave behaviour, see the _Why use it?_ part on top of this
README.

**TODO:** Is this correct? Or does autosave: true prevent new records from being
saved? Test.

#### Adding/removing records before saving parent

Event if using Deferring, it is still possible to add/remove a record before
saving the parent. There are two ways:
* using methods that are not mapped to the deferred associations, or
* using the original association.

##### Unmapped methods

As a rule, you can expect that methods defined in `Enumerable` and `Array` are
called on the deferred association. Exceptions are:
* `find`, and
* `select` (when not using a block).

Most other methods are called on the original association, most importantly:
* `create` or `create!`, and
* `destroy`, `destroy!` and `destroy_all`,

This can cause an record to be removed or added before saving the parent object.

``` ruby
class Person
  deferred_has_and_belongs_to_many :teams
  validates :name, presence: true
end

class Team
  has_and_belongs_to_many :people
end

person = Person.create(name: 'Bob')
person.teams.create(name: 'Support')
person.name = nil
person.save
# => false, because the name attribute is empty

Person.first.teams
# => [#<Team id: 4, name: "Support", ... ]
```

##### Original association

The original association is renamed to `original_association_name`. So, the
original association of the deferred association named `teams` can be accessed
by using `original_teams`.

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

person.original_teams << support
person.name = nil
person.save
# => false, because the name attribute is empty

Person.first.teams
# => [#<Team id: 4, name: "Support", ... ]
```

## Development

Run specs on all different Rails version using Appraisal:

```
bundle exec appraisal rake
```

## TODO

* check out what is going on with uniq: true
* collection(true) (same as reload)
* collection.replace

## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request
