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

  describe 'preloading associations' do
    before do
      p = Person.find(1)
      p.teams << dba << support
      p.save!
    end

    if rails30 # old-style preload
      it 'should have loaded the association' do
        p = Person.find(1)
        Person.send(:preload_associations, p, [:teams])
        expect(p.teams.loaded?).to be_true
        expect(p.team_ids).to eq [dba.id, support.id]
      end
    end

    if rails32 || rails4
      it 'should have loaded the association when pre-loading' do
        people = Person.preload(:teams)
        expect(people[0].teams.loaded?).to be_true
        expect(people[0].team_ids).to eq [dba.id, support.id]
      end

      it 'should have loaded the association when eager loading' do
        people = Person.eager_load(:teams)
        expect(people[0].teams.loaded?).to be_true
        expect(people[0].team_ids).to eq [dba.id, support.id]
      end

      it 'should have loaded the association when joining' do
        people = Person.includes(:teams).all
        expect(people[0].teams.loaded?).to be_true
        expect(people[0].team_ids).to eq [dba.id, support.id]
      end
    end

    it 'should not have loaded the association when using a regular query' do
      people = Person.all
      expect(people[0].teams.loaded?).to be_false
    end
  end

  context 'reloading & resetting associations' do

    it 'should throw away unsaved changes when reloading the parent' do
      bob = Person.where(name: 'Bob').first
      bob.teams << operations
      bob.save!

      bob.teams << dba << support
      bob.reload # RELOAD THE PARENT

      bob.teams.should eq [operations]
      bob.teams.pending_creates.should be_empty
    end

    it 'should throw away unsaved changes when reloading itself' do
      bob = Person.where(name: 'Bob').first
      bob.teams << operations
      bob.save!

      bob.teams << dba << support
      bob.teams.reload # RELOAD THE ASSOCIATION

      bob.teams.should eq [operations]
      bob.teams.pending_creates.should be_empty
    end

    it 'should load changes saved on the other other side of the association' do
      bob = Person.where(name: 'Bob').first
      bob.team_ids = [operations.id, dba.id]
      bob.save!

      dba.reload
      expect(dba.person_ids).to eq [bob.id]

      # Change the association on the Team side.
      dba.people = []
      dba.save!

      bob.reload

      expect(bob.team_ids).to eq [operations.id]
      expect(bob.teams.pending_creates).to be_empty
    end

    it 'should load changes saved on the association' do
      bob = Person.where(name: 'Bob').first
      bob.teams << operations
      bob.save!

      # Note: Team has a regular HABTM association to Person, so there is no
      # need to explicitly save after shovelling the person into the team.
      dba = Team.where(name: 'Database Administration').first
      dba.people << bob

      bob.reload
      expect(bob.teams).to eq [operations, dba]
    end

    # TODO
    it 'resets the association' do
      p = Person.first
      p.teams << operations
      p.save!

      p.teams << dba << support
      p.teams.reset

      p.teams.should eq [operations]
      p.teams.pending_creates.should be_empty
    end

    it 'resets the association (2)' do
      p = Person.first
      p.teams << operations
      p.save!

      t = Team.where(name: 'Database Administration').first
      t.people << p

      p.teams.reset
      p.teams.should eq [operations, dba]
    end

  end


  describe 'enumerable methods that conflict with ActiveRecord' do

    describe '#select' do

      before do
        bob = Person.where(name: 'Bob').first
        bob.teams << dba << support << operations
        bob.save!
      end

      it 'selects specified columns directly from the database' do
        bob = Person.where(name: 'Bob').first
        teams = bob.teams.select('name')

        expect(teams.map(&:name)).to eq ['Database Administration', 'End-User Support', 'Operations']
        expect(teams.map(&:id)).to eq [nil, nil, nil]
      end

      it 'calls a block on the deferred associations' do
        bob = Person.where(name: 'Bob').first
        teams = bob.teams.select { |team| team.id == 1 }
        expect(teams.map(&:id)).to eq [1]
      end

    end

    describe 'find' do
      # TODO
    end

    describe 'first' do
      # TODO
    end

  end

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

  it 'should compact ids' do
    p = Person.first
    p.teams = [Team.first]
    expect(p.teams.length).to eq(1)
    p.team_ids = [Team.first.id, '']
    expect(p.teams.length).to eq(1)

    expect{ p.save }.to change{ Person.first.teams.size }.from(0).to(1)

    expect(p.teams[0]).to eq(Team.first)
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

  describe 'validations' do

    xit 'deferred habtm <=> regular habtm' do
      alice = Person.where(name: 'Alice').first
      bob = Person.where(name: 'Bob').first

      team = Team.first
      team.people << alice << bob
      team.save!

      bob.reload
      expect(bob.teams.size).to eq(1)

      alice.reload
      expect(alice.teams.size).to eq(1)

      team.people.create!(name: 'Chuck')
      expect(team).to_not be_valid

      bob.reload
      alice.reload

      expect(bob).to_not be_valid
      expect(alice).to_not be_valid

      expect(bob.save).to be_false
      expect(alice.save).to be_false
    end

    # deferred_has_and_belongs_to_many :holidays, :uniq => true,
    #                                             :validate => false,
    #                                             :autosave => true,
    #                                             :order => "start_at"

    it 'should add invalid record when validate: false' do
      alice = Person.where(name: 'Alice').first
      alice.teams << dba
      alice.save!

      bob = Person.where(name: 'Bob').first
      bob.teams << dba
      bob.save!
      expect(bob.teams).to eq [dba]

      chuck = Person.create!(name: 'Chuck')
      chuck.teams << dba
      expect(chuck.teams).to eq [dba]
      expect(chuck.save).to be_true
    end
  end

  it 'checks' do
    bob = Person.where(name: 'Bob').first
    bob.teams_checked = [dba.id, operations.id]
    bob.save!

    bob.reload

    expect(bob.teams).to eq [dba, operations]
  end


end
