require 'active_support/all'
require 'active_record'

ActiveRecord::Base.establish_connection adapter: 'sqlite3', database: ':memory:'

ActiveRecord::Schema.define version: 0 do
  create_table :people do |t|
    t.string :name
    t.timestamps null: false
  end

  create_table :people_teams, id: false do |t|
    t.integer :person_id
    t.integer :team_id
  end

  create_table :teams do |t|
    t.string :name
    t.timestamps null: false
  end

  create_table :issues do |t|
    t.string :subject
    t.integer :person_id
    t.timestamps null: false
  end

  create_table :addresses do |t|
    t.integer :addressable_id
    t.string :addressable_type
    t.string :street
    t.timestamps null: false
  end

  create_table :non_validated_issues do |t|
    t.string :subject
    t.integer :person_id
    t.timestamps null: false
  end
end
ActiveRecord::Base.logger = Logger.new(File.dirname(__FILE__) + '/debug.log')
