require 'spec_helper'

describe Person do

  before(:all) do
    Person.create!(name: 'Alice')
    Person.create!(name: 'Bob')

    Team.create!(name: 'Database Administration')
    Team.create!(name: 'End-User Support')
    Team.create!(name: 'Operations')
  end

  let(:dba) { Team.where(name: 'Database Administration').first }
  let(:support) { Team.where(name: 'End-User Support').first }
  let(:operations) { Team.where(name: 'Operations').first }

  it 'does not create a link between person and teams until person is saved' do
    p = Person.new(name: 'Chuck')
    p.teams << dba << support

    expect(Person.count_by_sql("SELECT COUNT(*) FROM people_teams")).to eq(0)
    # TODO: Change name of original_teams, maybe:
    # -- teams.target
    # -- teams_without_deferred_save
    # What use case?
    expect(p.original_teams.size).to eq(0)
    expect(p.teams.size).to eq(2)

    p.save!

    p.reload
    expect(Person.count_by_sql("SELECT COUNT(*) FROM people_teams")).to eq(2)
    expect(p.original_teams.size).to eq(2)
    expect(p.teams.size).to eq(2)
  end

  xit 'should not add duplicate values' do
    dba = Team.first
    dba.people = [Person.first, Person.find(2), Person.last]

    dba.people.size.should eq 2
    dba.person_ids.should eq [1,2]
  end

  it 'delays updates to existing parent' do
    p = Person.first
    p.teams << [dba, support]

    expect{ p.save }.to change{ Person.first.teams.size }.from(0).to(2)
  end

  it 'delays deletes' do
    p = Person.first
    p.team_ids = [dba.id, support.id, operations.id]
    p.save
    p.teams.delete([
      Team.find(dba.id),
      Team.find(operations.id)
    ])

    expect{ p.save }.to change{ Person.first.teams.size }.from(3).to(1)
  end

  it 'replaces records' do
    p = Person.first
    p.teams = [Team.find(dba.id)]
    expect(p.teams.length).to eq(1)
    p.teams = [Team.find(support.id), Team.find(operations.id)]
    expect(p.teams.length).to eq(2)

    expect{ p.save }.to change{ Person.first.teams.size }.from(0).to(2)
  end

  it 'should replace ids' do
    p = Person.first
    p.teams = [Team.first]
    expect(p.teams.length).to eq(1)
    p.team_ids = [Team.first.id, Team.last.id]
    expect(p.teams.length).to eq(2)

    expect{ p.save }.to change{ Person.first.teams.size }.from(0).to(2)

    expect(p.teams[0]).to eq(Team.first)
    expect(p.teams[1]).to eq(Team.last)
  end

  it 'should return ids' do
    p = Person.first
    p.teams = [Team.first, Team.last]
    expect(p.team_ids.size).to eq(2)
    expect(p.team_ids).to include(Team.first.id, Team.last.id)

    expect{ p.save }.to change{ Person.first.team_ids.size }.from(0).to(2)

    expect(p.team_ids.size).to eq(2)
    expect(p.team_ids).to include(Team.first.id, Team.last.id)
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

    # it 'should execute first on rainchecked association' do
    #   p = Person.first
    #   p.team_ids = [dba.id, support.id, operations.id]
    #   expect(p.teams.first).to eq(dba)
    #   p.save!
    #   expect(Person.first.teams.first).to eq(dba)
    # end

    # it 'should execute last on rainchecked association' do
    #   p = Person.first
    #   p.team_ids = [dba.id, support.id, operations.id]
    #   expect(p.teams.last).to eq(operations)
    #   p.save!
    #   expect(Person.first.teams.last).to eq(operations)
    # end

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

  end

  it 'should find one without loading collection' do
    p = Person.first
    p.teams = [Team.first, Team.find(3)]
    p.save
    teams = Person.first.teams
    teams.loaded?.should == false
    teams.find(3).should ==  Team.find(3)
    teams.first.should == Team.first
    teams.last.should == Team.find(3)
    teams.loaded?.should == false
  end

  it 'should call before_add, after_add, before_remove, after_remove callbacks' do
    bob = Person.first
    bob.teams = [Team.first, Team.find(3)]
    bob.save!

    bob = Person.first
    bob.teams.delete(bob.teams[0])
    bob.teams << Team.find(2)
    bob.save!

    bob.audit_log.length.should == 4
    bob.audit_log.should == [
      'Before removing team 1',
      'After removing team 1',
      'Before adding team 2',
      'After adding team 2'
    ]
  end

  it 'should set via *_ids method' do
    p = Person.first
    p.team_ids = [1,3]
    p.save
    p = Person.first
    p.teams.length.should == 2
    p.team_ids.should == [1,3]
  end

  it 'should mass assign' do
    p = Person.first
    p.teams << Team.first << Team.last << Team.find(2)
    p.save

    # Destroy team 2 and 3. Keep team 1.
    p = Person.first
    p.attributes = {
      teams_attributes: [
        { id: 1 },
        { id: 3, _destroy: true },
        { id: 2, _destroy: true }
      ]
    }
    p.teams.length.should == 1
    p.team_ids.sort.should == [1]

    Person.first
    Person.first.teams.length.should == 3
    Person.first.team_ids.sort.should == [1,2,3]

    p.save!

    p = Person.first
    p.teams.length.should == 1
    p.team_ids.sort.should == [1]
  end

  it 'should mass assign' do
    p = Person.first
    p.teams << Team.first << Team.last << Team.find(2)
    p.save

    # Destroy team 2 and 3. Keep team 1.
    p = Person.first
    p.teams_attributes = [
      { id: 1 },
      { id: 3, _destroy: true },
      { id: 2, _destroy: true }
    ]
    p.teams.length.should == 1
    p.team_ids.sort.should == [1]

    Person.first
    Person.first.teams.length.should == 3
    Person.first.team_ids.sort.should == [1,2,3]

    p.save!

    p = Person.first
    p.teams.length.should == 1
    p.team_ids.sort.should == [1]
  end

end
