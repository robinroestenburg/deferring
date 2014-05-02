# Delay Many

DelayMany makes it possible to delay saving ActiveRecord associations until the
parent object has been validated.

Currently supporting Rails 3.0, 3.2, 4.0 and 4.1.


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

TODO: Write usage instructions here

For more examples of using `delay_many`, please take a look at the specs.


## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request
