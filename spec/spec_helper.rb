require 'support/active_record'
require 'deferring'
require 'support/models/person'
require 'support/models/team'
require 'support/models/issue'
require 'support/models/address'
require 'support/models/non_validated_issue'
require 'support/matchers/query_matcher'

RSpec.configure do |config|
  config.disable_monkey_patching!

  config.run_all_when_everything_filtered = true
  config.filter_run :focus

  # Run specs in random order to surface order dependencies. If you find an
  # order dependency and want to debug it, you can fix the order by providing
  # the seed, which is printed after each run.
  #     --seed 1234
  config.order = 'random'

  config.include(Deferring::Matchers)

  # Rollback all the database changes after each spec, poor man's
  # DatabaseCleaner :-)
  config.around do |example|
    ActiveRecord::Base.transaction do
      example.run
      raise ActiveRecord::Rollback
    end
  end
end

# Catch queries executed within the &block
def catch_queries(&block)
  queries  = []
  callback = lambda { |name, start, finish, id, payload|
    queries << payload[:sql] if payload[:sql] =~ /^SELECT|UPDATE|INSERT/
  }

  result = ActiveSupport::Notifications.subscribed(callback, 'sql.active_record') do
    yield
  end
  [result, queries]
end
