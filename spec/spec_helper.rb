require 'support/active_record'
require 'deferring'
require 'support/models'
require 'support/rails_versions'

RSpec.configure do |config|
  config.disable_monkey_patching!

  config.run_all_when_everything_filtered = true
  config.filter_run :focus

  # Run specs in random order to surface order dependencies. If you find an
  # order dependency and want to debug it, you can fix the order by providing
  # the seed, which is printed after each run.
  #     --seed 1234
  config.order = 'random'

  # Rollback all the database changes after each spec, poor man's
  # DatabaseCleaner :-)
  config.around do |example|
    ActiveRecord::Base.transaction do
      example.run
      raise ActiveRecord::Rollback
    end
  end

end
