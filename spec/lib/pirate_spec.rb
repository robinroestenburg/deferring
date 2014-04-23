require 'spec_helper'

class Person < ActiveRecord::Base
  has_and_belongs_to_many_deferred :teams
  validates_presence_of :name

  has_many :shoes
end

class Team < ActiveRecord::Base
  has_and_belongs_to_many_deferred :people
end

class Shoe < ActiveRecord::Base
  belongs_to :person
end

describe Person do

  before do
    Person.create!(name: 'Alice')
    Person.create!(name: 'Bob')

    Team.create!(name: 'Database Administration')
    Team.create!(name: 'End-User Support')
    Team.create!(name: 'Operations')
  end

  let(:dba) { Team.where(name: 'Database Administration').first }
  let(:support) { Team.where(name: 'End-User Support').first }
  let(:operations) { Team.where(name: 'Operations').first }


  it 'creates are delayed until parent is saved' do
    p = Person.new(name: 'Chuck')
    p.teams << dba << support
    Person.count.should == 2

    p.save!
    Person.count.should == 3

    p = Person.where(name: p.name).first
    p.teams.size.should == 2
  end

  it 'delays updates to existing parent' do
    p = Person.first
    p.teams << dba << support
    Person.first.teams.size.should == 0
    p.save!
    Person.first.teams.size.should == 2
  end

  it 'delays deletes' do
    p = Person.first
    p.team_ids = [dba.id, support.id, operations.id]
    p.save
    p = Person.first

    # TODO: I had to remove the array here.
    p.teams.delete(Team.find(dba.id))
    p.teams.delete(Team.find(operations.id))

    Person.first.teams.size.should == 3
    p.save
    Person.first.teams.size.should == 1
  end

  it 'replaces records' do
    p = Person.first
    p.teams = [Team.find(dba.id)]
    p.teams.length.should == 1
    p.teams = [Team.find(support.id), Team.find(operations.id)]
    p.teams.length.should == 2
    Person.first.teams.length.should == 0
    p.save!
    Person.first.teams.length.should == 2
  end

  it "should replace ids" do
    p = Person.first
    p.teams = [Team.first]
    p.team_ids = [Team.first.id, Team.last.id]
    p.teams.length.should == 2
    Person.first.teams.length.should == 0
    p.save
    p = Person.first
    p.teams.length.should == 2
    p.teams[0].should == Team.first
    p.teams[1].should == Team.last
  end

  it "should return ids" do
    p = Person.first
    p.teams = [Team.first, Team.last]
    p.team_ids.length.should == 2
    p.team_ids.should == [Team.first.id, Team.last.id]
    p.save
    p = Person.first
    p.team_ids.length.should == 2
    p.team_ids.should == [Team.first.id, Team.last.id]
  end

  it 'does not create records when parent is not valid' do
    p = Person.first
    p.name = nil # Person.name should be present, Person should not be saved.
    p.teams << dba

    p.save

    expect(p.errors.size).to eq(1)
    expect(Person.first.teams.size).to eq(0)
  end

  describe 'active record api' do

    it 'should execute first on rainchecked association' do
      p = Person.first
      p.team_ids = [dba.id, support.id, operations.id]
      expect(p.teams.first).to eq(dba)
      p.save!
      expect(Person.first.teams.first).to eq(dba)
    end

    it 'should execute last on rainchecked association' do
      p = Person.first
      p.team_ids = [dba.id, support.id, operations.id]
      expect(p.teams.last).to eq(operations)
      p.save!
      expect(Person.first.teams.last).to eq(operations)
    end

    it 'should build a new record' do
      p = Person.first
      p.teams.build(name: 'Service Desk')
      expect(p.teams[0]).to be_new_record
    end

    it 'should build and save a new record' do
      p = Person.first
      p.teams.build(name: 'Service Desk')
      expect(p.teams[0]).to be_new_record
      expect(Person.first.teams.size).to eq(0)
      p p.teams[0]
      p.save
      expect(Person.first.teams.size).to eq(1)
    end

    it 'should add a new record' do
      p = Person.first
      p.teams.create!(:name => 'Service Desk')
      expect(p.teams[0]).to_not be_new_record
      expect(Person.first.teams.size).to eq(1)
      p.save
      expect(Person.first.teams.size).to eq(1)
    end

    it 'should allow ActiveRecord::QueryMethods' do
      p = Person.first
      p.teams << dba << operations
      p.save
      expect(Person.first.teams.where(name: 'Operations').first).to eq(operations)
    end

    it 'should know klass' do
      p = Person.first
      p.teams = [dba, operations]
      expect(p.teams.klass).to eq(Team)
    end

  end

end
