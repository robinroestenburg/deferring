require 'spec_helper'

RSpec.describe 'deferred has_many associations' do

  before(:each) do
    Person.create!(name: 'Alice')
    Person.create!(name: 'Bob')

    Issue.create!(subject: 'Printer PRT-001 jammed')
    Issue.create!(subject: 'Database server DB-1337 down')
    Issue.create!(subject: 'Make me a sandwich!')
  end

  let(:bob) { Person.where(name: 'Bob').first }

  let(:printer_issue) { Issue.where(subject: 'Printer PRT-001 jammed').first }
  let(:db_issue) { Issue.where(subject: 'Database server DB-1337 down').first }
  let(:sandwich_issue) { Issue.where(subject: 'Make me a sandwich!').first }

  describe 'deferring' do
    it 'does not create a link until parent is saved' do
      bob.issues << db_issue << printer_issue
      expect{ bob.save! }.to change{ Person.find(bob.id).issues.size }.from(0).to(2)
    end

    it 'does not unlink until parent is saved' do
      bob.issue_ids = [db_issue.id, printer_issue.id, sandwich_issue.id]
      bob.save!

      bob.issues.delete([
        Issue.find(db_issue.id),
        Issue.find(sandwich_issue.id)
      ])

      expect{ bob.save }.to change{ Person.find(bob.id).issues.size }.from(3).to(1)
    end

    xit 'does not create a link when parent is not valid'

    it 'replaces existing records when assigning a new set of records' do
      bob.issues = [db_issue]

      # A mistake was made, Bob wants to submit a printer and a sandwich issue.
      bob.issues = [printer_issue, sandwich_issue]

      expect{ bob.save }.to change{ Person.find(bob.id).issues.size }.from(0).to(2)
    end

    it 'sets the belongs_to association of the associated record' do
      bob.issues << printer_issue
      expect(bob.issues.first.person).to eq bob
    end

    describe '#collection_singular_ids' do
      it 'returns ids of saved & unsaved associated records' do
        bob.issues = [printer_issue, db_issue]
        expect(bob.issue_ids.size).to eq(2)
        expect(bob.issue_ids).to eq [printer_issue.id, db_issue.id]

        expect{ bob.save }.to change{ Person.find(bob.id).issue_ids.size }.from(0).to(2)

        expect(bob.issue_ids.size).to eq(2)
        expect(bob.issue_ids).to eq [printer_issue.id, db_issue.id]
      end # collection_singular_ids
    end

    describe '#collections_singular_ids=' do
      it 'sets associated records' do
        bob.issue_ids = [printer_issue.id, db_issue.id]
        bob.save
        expect(bob.issues).to eq [printer_issue, db_issue]
        expect(bob.issue_ids).to eq [printer_issue.id, db_issue.id]

        bob.reload
        expect(bob.issues).to eq [printer_issue, db_issue]
        expect(bob.issue_ids).to eq [printer_issue.id, db_issue.id]
      end

      it 'replace existing records when assigning a new set of ids of records' do
        bob.issues = [db_issue]

        bob.issue_ids = [printer_issue.id, sandwich_issue.id]
        expect(bob.issues.length).to eq(2)

        expect{ bob.save }.to change{ Person.find(bob.id).issues.size }.from(0).to(2)
      end

      it 'clears empty values from the ids to be assigned' do
        bob.issue_ids = [db_issue.id, '']
        expect(bob.issues.length).to eq(1)

        expect{ bob.save }.to change{ Person.where(name: 'Bob').first.issues.size }.from(0).to(1)
      end

      it 'sets the belongs_to association of the associated record' do
        expect(printer_issue.person).to be_nil
        bob.issue_ids = [printer_issue.id]
        expect(bob.issues.first.person).to eq bob
      end
    end # collections_singular_ids=
  end

  describe 'accepts_nested_attributes' do
    it 'should mass-assign' do
      p = Person.first
      p.issues << printer_issue << db_issue << sandwich_issue
      p.save

      # Destroy db and sandwich issues. Keep printer issue.
      p = Person.first
      p.attributes = {
        issues_attributes: [
          { id: printer_issue.id },
          { id: sandwich_issue.id, _destroy: true },
          { id: db_issue.id, _destroy: true }
        ]
      }
      expect(p.issues.length).to eq(1)
      expect(p.issue_ids.sort).to eq([1])

      expect{ p.save! }.to change{ Person.first.issues.size }.from(3).to(1)
    end

    it 'sets the belongs_to association of the associated record' do
      expect(printer_issue.person).to be_nil
      bob.attributes = {
        issues_attributes: [{ id: printer_issue.id }]
      }
      expect(bob.issues.first.person).to eq bob
    end
  end # accepts_nested_attributes

  describe 'preloading associations' do
    before do
      bob = Person.where(name: 'Bob').first
      bob.issues << printer_issue << db_issue
      bob.save!
    end

    if rails30 # old-style preload
      it 'should have loaded the association' do
        bob = Person.where(name: 'Bob').first
        Person.send(:preload_associations, bob, [:issues])
        expect(bob.issues.loaded?).to be_truthy
        expect(bob.issue_ids).to eq [printer_issue.id, db_issue.id]
      end
    end

    if rails32 || rails4
      it 'should have loaded the association when pre-loading' do
        people = Person.preload(:issues)
        expect(people[1].issues.loaded?).to be_truthy
        expect(people[1].issue_ids).to eq [printer_issue.id, db_issue.id]
      end

      it 'should have loaded the association when eager loading' do
        people = Person.eager_load(:issues)
        expect(people[1].issues.loaded?).to be_truthy
        expect(people[1].issue_ids).to eq [db_issue.id, printer_issue.id]
      end

      it 'should have loaded the association when joining' do
        people = Person.includes(:issues).all
        expect(people[1].issues.loaded?).to be_truthy
        expect(people[1].issue_ids).to eq [printer_issue.id, db_issue.id]
      end
    end

    it 'should not have loaded the association when using a regular query' do
      people = Person.all
      expect(people[1].issues.loaded?).to be_falsey
    end
  end # preloading associations

  describe 'active record api' do
    describe '#build' do
      it 'builds a new record' do
        bob = Person.where(name: 'Bob').first
        bob.issues.build(subject: 'I need coffee!')

        expect(bob.issues.last).to be_new_record
      end

      it 'sets the belongs_to association of the built record' do
        bob = Person.where(name: 'Bob').first
        bob.issues.build(subject: 'I need coffee!')

        expect(bob.issues.last.person).to eq bob
      end
    end
  end # active record api
end
