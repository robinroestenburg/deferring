require 'spec_helper'

RSpec.describe 'deferred has-and-belongs-to-many associations' do

  before :each do
    Person.create!(name: 'Alice')
    Person.create!(name: 'Bob')

    Team.create!(name: 'Database Administration')
    Team.create!(name: 'End-User Support')
    Team.create!(name: 'Operations')
  end

  let(:bob) { Person.where(name: 'Bob').first }

  let(:dba) { Team.where(name: 'Database Administration').first }
  let(:support) { Team.where(name: 'End-User Support').first }
  let(:operations) { Team.where(name: 'Operations').first }

  describe 'deferring' do

    it 'does not create a link until parent is saved' do
      bob.teams << dba << support
      expect{ bob.save! }.to change{ Person.find(bob.id).teams.size }.from(0).to(2)
    end

    it 'does not unlink until parent is saved' do
      bob.team_ids = [dba.id, support.id, operations.id]
      bob.save!

      bob.teams.delete([
        Team.find(dba.id),
        Team.find(operations.id)
      ])

      expect{ bob.save }.to change{ Person.find(bob.id).teams.size }.from(3).to(1)
    end

    it 'does not create a link when parent is not valid' do
      bob.name = nil # Person.name should be present, Person should not be saved.
      bob.teams << dba

      expect{ bob.save }.not_to change{ Person.find(bob.id).teams.size }
    end

    it 'replaces existing records when assigning a new set of records' do
      bob.teams = [dba]

      # A mistake was made, Bob belongs to Support and Operations instead.
      bob.teams = [support, operations]

      # The initial assignment of Bob to the DBA team did not get saved, so
      # at this moment Bob is not assigned to any team in the database.
      expect{ bob.save }.to change{ Person.find(bob.id).teams.size }.from(0).to(2)
    end

    describe '#collection_singular_ids' do

      it 'returns ids of saved & unsaved associated records' do
        bob.teams = [dba, operations]
        expect(bob.team_ids.size).to eq(2)
        expect(bob.team_ids).to eq [dba.id, operations.id]

        expect{ bob.save }.to change{ Person.find(bob.id).team_ids.size }.from(0).to(2)

        expect(bob.team_ids.size).to eq(2)
        expect(bob.team_ids).to eq [dba.id, operations.id]
      end

    end

    describe '#collections_singular_ids=' do

      it 'sets associated records' do
        bob.team_ids = [dba.id, operations.id]
        bob.save
        expect(bob.teams).to eq [dba, operations]
        expect(bob.team_ids).to eq [dba.id, operations.id]

        bob.reload
        expect(bob.teams).to eq [dba, operations]
        expect(bob.team_ids).to eq [dba.id, operations.id]
      end

      it 'replace existing records when assigning a new set of ids of records' do
        bob.teams = [dba]

        # A mistake was made, Bob belongs to Support and Operations instead. The
        # teams are assigned through the singular collection ids method. Note
        # that, this also updates the teams association.
        bob.team_ids = [support.id, operations.id]
        expect(bob.teams.length).to eq(2)

        expect{ bob.save }.to change{ Person.find(bob.id).teams.size }.from(0).to(2)
      end

      it 'clears empty values from the ids to be assigned' do
        bob.team_ids = [dba.id, '']
        expect(bob.teams.length).to eq(1)

        expect{ bob.save }.to change{ Person.where(name: 'Bob').first.teams.size }.from(0).to(1)
      end

      describe '#collection_checked=' do

        it 'set associated records' do
          bob.teams_checked = [dba.id, operations.id]

          expect{ bob.save }.to change{ Person.where(name: 'Bob').first.teams.size }.from(0).to(2)
        end

      end

    end

  end

  describe 'validating' do

    xit 'does not add duplicate values' do
      pending 'uniq does not work correctly yet' do
        dba = Team.first
        dba.people = [Person.first, Person.find(2), Person.last]

        expect(dba.people.size).to eq 2
        expect(dba.person_ids).to eq [1,2]
      end
    end

  end

  describe 'preloading' do

    before do
      bob.teams << dba << support
      bob.save!
    end

    if rails30 # old-style preload
      it 'loads the association' do
        person = Person.where(name: 'Bob').first
        Person.send(:preload_associations, person, [:teams])
        expect(person.teams.loaded?).to be_truthy
        expect(person.team_ids).to eq [dba.id, support.id]
      end
    end

    if rails32 || rails4
      it 'loads the association when pre-loading' do
        person = Person.preload(:teams).where(name: 'Bob').first
        expect(person.teams.loaded?).to be_truthy
        expect(person.team_ids).to eq [dba.id, support.id]
      end

      it 'loads the association when eager loading' do
        person = Person.eager_load(:teams).where(name: 'Bob').first
        expect(person.teams.loaded?).to be_truthy
        expect(person.team_ids).to eq [dba.id, support.id]
      end

      it 'loads the association when joining' do
        person = Person.includes(:teams).where(name: 'Bob').first
        expect(person.teams.loaded?).to be_truthy
        expect(person.team_ids).to eq [dba.id, support.id]
      end
    end

    it 'does not load the association when using a regular query' do
      person = Person.where(name: 'Bob').first
      expect(person.teams.loaded?).to be_falsey
    end

  end

  describe 'reloading' do

    before do
      bob.teams << operations
      bob.save!
    end

    it 'throws away unsaved changes when reloading the parent' do
      # Assign Bob to some teams, but reload Bob before saving. This should
      # remove the unsaved teams from the list of teams Bob is assigned to.
      bob.teams << dba << support
      bob.reload

      expect(bob.teams).to eq [operations]
      expect(bob.teams.pending_creates).to be_empty
    end

    it 'throws away unsaved changes when reloading the association' do
      # Assign Bob to some teams, but reload the association before saving Bob.
      bob.teams << dba << support
      bob.teams.reload

      expect(bob.teams).to eq [operations]
      expect(bob.teams.pending_creates).to be_empty
    end

    it 'loads changes saved on the other side of the association' do
      # The DBA team will add Bob to their team, without him knowing it!
      dba.people << bob

      # Bob does not know about the fact that he has been added to the DBA team.
      expect(bob.teams).to eq [operations]

      # After resetting Bob, the teams are retrieved from the database and Bob
      # finds out he is now also a team-member of team DBA!
      bob.teams.reload
      expect(bob.teams).to eq [operations, dba]
    end
  end

  describe 'resetting' do

    before do
      bob.teams << operations
      bob.save!
    end

    it 'throws away unsaved changes when resetting the association' do
      # Assign Bob to some teams, but reset the association before saving Bob.
      bob.teams << dba << support
      bob.teams.reset

      expect(bob.teams).to eq [operations]
      expect(bob.teams.pending_creates).to be_empty
    end

    it 'loads changes saved on the other side of the association' do
      # The DBA team will add Bob to their team, without him knowing it!
      dba.people << bob

      # Bob does not know about the fact that he has been added to the DBA team.
      expect(bob.teams).to eq [operations]

      # After resetting Bob, the teams are retrieved from the database and Bob
      # finds out he is now also a team-member of team DBA!
      bob.teams.reset
      expect(bob.teams).to eq [operations, dba]
    end

  end

  describe 'enumerable methods that conflict with ActiveRecord' do

    describe '#select' do
      before do
        bob.teams << dba << support << operations
        bob.save!
      end

      it 'selects specified columns directly from the database' do
        teams = bob.teams.select('name')

        expect(teams.map(&:name)).to eq ['Database Administration', 'End-User Support', 'Operations']
        expect(teams.map(&:id)).to eq [nil, nil, nil]
      end

      it 'calls a block on the deferred associations' do
        teams = bob.teams.select { |team| team.id == 1 }
        expect(teams.map(&:id)).to eq [1]
      end
    end

    describe 'find' do
      # TODO: Write some tests.
    end

    describe 'first' do
      # TODO: Write some tests.
    end

  end

  describe 'callbacks' do

    before(:example) do
      bob = Person.first
      bob.teams = [Team.find(3)]
      bob.save!
    end

    it 'calls the link callbacks when adding a record using <<' do
      bob = Person.first
      bob.teams << Team.find(1)

      expect(bob.audit_log.length).to eq(2)
      expect(bob.audit_log).to eq([
        'Before linking team 1',
        'After linking team 1'
      ])
    end

    it 'calls the link callbacks when adding a record using push' do
      bob = Person.first
      bob.teams.push(Team.find(1))

      expect(bob.audit_log.length).to eq(2)
      expect(bob.audit_log).to eq([
        'Before linking team 1',
        'After linking team 1'
      ])
    end

    it 'calls the link callbacks when adding a record using append' do
      bob = Person.first
      bob.teams.append(Team.find(1))

      expect(bob.audit_log.length).to eq(2)
      expect(bob.audit_log).to eq([
        'Before linking team 1',
        'After linking team 1'
      ])
    end

    it 'only calls the Rails callbacks when creating a record on the association using create' do
      bob = Person.first
      bob.teams.create(name: 'HR')

      expect(bob.audit_log.length).to eq(2)
      expect(bob.audit_log).to eq([
        'Before adding new team',
        'After adding team 4'
      ])
    end

    it 'only calls the Rails callbacks when creating a record on the association using create!' do
      bob = Person.first
      bob.teams.create!(name: 'HR')

      expect(bob.audit_log.length).to eq(2)
      expect(bob.audit_log).to eq([
        'Before adding new team',
        'After adding team 4'
      ])
    end

    it 'calls the unlink callbacks when removing a record using delete' do
      bob = Person.first
      bob.teams.delete(Team.find(3))

      expect(bob.audit_log.length).to eq(2)
      expect(bob.audit_log).to eq([
        'Before unlinking team 3',
        'After unlinking team 3'
      ])
    end

    it 'only calls the rails callbacks when removing a record using destroy' do
      bob = Person.first
      bob.teams.destroy(3)

      expect(bob.audit_log.length).to eq(2)
      expect(bob.audit_log).to eq([
        'Before removing team 3',
        'After removing team 3'
      ])
    end

    it 'calls the regular Rails callbacks after saving' do
      bob = Person.first
      bob.teams = [Team.find(1), Team.find(3)]
      bob.save!

      bob = Person.first
      bob.teams.delete(Team.find(1))
      bob.teams << Team.find(2)
      bob.save!

      expect(bob.audit_log.length).to eq(8)
      expect(bob.audit_log).to eq([
        'Before unlinking team 1', 'After unlinking team 1',
        'Before linking team 2', 'After linking team 2',
        'Before removing team 1',
        'After removing team 1',
        'Before adding team 2',
        'After adding team 2'
      ])
    end

  end

  describe 'pending creates & deletes (aka links and unlinks)' do

    describe 'pending creates' do

      it 'returns newly build records' do
        bob.teams.build(name: 'Service Desk')
        expect(bob.teams.pending_creates.size).to eq(1)
      end

      it 'does not return newly created records' do
        bob.teams.create!(name: 'Service Desk')
        expect(bob.teams.pending_creates).to be_empty
      end

      it 'returns associated records that need to be linked to parent' do
        bob.teams = [dba]
        expect(bob.teams.pending_creates).to eq [dba]
      end

      it 'does not return associated records that already have a link' do
        bob.teams = [dba]
        bob.save!

        bob.teams << operations

        expect(bob.teams.pending_creates).to_not include dba
        expect(bob.teams.pending_creates).to include operations
      end

      it 'does not return associated records that are to be deleted' do
        bob.teams = [dba, operations]
        bob.save!
        bob.teams.delete(dba)

        expect(bob.teams.pending_creates).to be_empty
      end

      it 'does not return a record that has just been removed (and has not been saved)' do
        bob.teams = [dba]
        bob.save!

        bob.teams.delete(dba)
        bob.teams << dba

        expect(bob.teams.pending_deletes).to be_empty
        expect(bob.teams.pending_creates).to be_empty
      end
    end

    describe 'pending deletes' do

      it 'returns associated records that need to be unlinked from parent' do
        bob.teams = [dba]
        bob.save!
        bob.teams.delete(dba)

        expect(bob.teams.pending_deletes).to eq [dba]
      end

      it 'returns an empty array when no records are to be deleted' do
        bob.teams = [dba]
        bob.save!

        expect(bob.teams.pending_deletes).to be_empty
      end

      it 'does not return a record that has just been added (and has not been saved)' do
        bob.teams = [dba]
        bob.teams.delete(dba)

        expect(bob.teams.pending_deletes).to be_empty
        expect(bob.teams.pending_creates).to be_empty
      end

    end

  end

  # TODO: Clean up tests.

  describe 'active record api' do

    # it 'should execute first on deferred association' do
    #   p = Person.first
    #   p.team_ids = [dba.id, support.id, operations.id]
    #   expect(p.teams.first).to eq(dba)
    #   p.save!
    #   expect(Person.first.teams.first).to eq(dba)
    # end

    # it 'should execute last on deferred association' do
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

    it 'should find one without loading collection' do
      p = Person.first
      p.teams = [Team.first, Team.find(3)]
      p.save
      teams = Person.first.teams
      expect(teams.loaded?).to eq(false)
      expect(teams.find(3)).to eq(Team.find(3))
      expect(teams.first).to eq(Team.first)
      expect(teams.last).to eq(Team.find(3))
      expect(teams.loaded?).to eq(false)
    end

  end

  describe 'accepts_nested_attributes' do
    # TODO: Write more tests.
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
      expect(p.teams.length).to eq(1)
      expect(p.team_ids.sort).to eq([1])

      Person.first
      expect(Person.first.teams.length).to eq(3)
      expect(Person.first.team_ids.sort).to eq([1,2,3])

      p.save!

      p = Person.first
      expect(p.teams.length).to eq(1)
      expect(p.team_ids.sort).to eq([1])
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
      expect(p.teams.length).to eq(1)
      expect(p.team_ids.sort).to eq([1])

      Person.first
      expect(Person.first.teams.length).to eq(3)
      expect(Person.first.team_ids.sort).to eq([1,2,3])

      p.save!

      p = Person.first
      expect(p.teams.length).to eq(1)
      expect(p.team_ids.sort).to eq([1])
    end
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

      expect(bob.save).to be_falsey
      expect(alice.save).to be_falsey
    end

    xit 'does not validate records when validate: false' do
      pending 'validate: false does not work' do
        alice = Person.where(name: 'Alice').first
        alice.teams.build(name: nil)
        alice.save!

        expect(alice.teams.size).to eq 1
      end
    end
  end

end
