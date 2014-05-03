# Deferring

Deferring makes it possible to delay saving ActiveRecord associations until the
parent object has been saved.

Currently supporting Rails 3.0, 3.2, 4.0 and 4.1.

It is important to note that Deferring does not touch the original `has_many`
and `has_and_belongs_to_many` associations. You can use them, wihtout worrying
about any changed behaviour or side-effects from using Deferring.

## Credits/Rationale

The ideas of this gem was originally thought of by TylerRick (see this thread).
The gem created by TylerRick is still available, but not maintained. This gem
has been forked by (among others) MartinKoener - who added Rails 3 support.

A project I am working on, uses the `autosave_habtm` gem, which kind of takes
different approach to doing the same thing. This gem only supported Rails 3.0.

As we are upgrading to Rails 3.2 (and later Rails 4), I needed a gem to provide
this behaviour. Upgrading either one of the gems would result into rewriting a
lot of the code (for different reasons, some purely estetic :)), so that is why
I wrote a new gem.


## Why use it?

Let's take a look at the following example:

``` ruby

```

The links to the Teams associated to the Person are stored directly, before the
(in this case invalid) parent is actually saved. This is how Rails' `has_many`
and `has_and_belongs_to_many` associations work, but not how (imho) they should
work in this situation.

The `delay_many` gem will delay creating the links between Person and Team until
the Person has been saved succesfully. Let's look at the aforementioned example
again, now using the `delay_many` gem:

``` ruby

```


## Use cases

* Auditing
* ...


## Getting started

### Installation

Add this line to your application's Gemfile:

    gem 'delay_many'

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install delay_many


### How do I use it?

Deferring adds a couple of methods to your ActiveRecord models. These are:

- `deferred_has_and_belongs_to_many`
- `deferred_accepts_nested_attributes_for`
- `deferred_has_many`

These methods wrap the existing methods. For instance, `deferred_has_many` will
call `has_many` in order to set up the assocation.

### How does it work?

Deferring actually wraps the original association and replaces the accessor
methods to the association by a custom object that will keep track of the
updates to the association. When the parent is saved (using an `after_save`),
this object is assigned to the original association which will automatically
save the changes to the database.

### Gotchas

#### Using custom callback methods

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
* collection.reload
* collection.reset
* collection.replace
* collection.append (<<)

## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request
