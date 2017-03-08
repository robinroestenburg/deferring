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

    it 'drops nil records' do
      bob.issues << nil
      expect(bob.issues).to be_empty

      bob.issues = [nil]
      expect(bob.issues).to be_empty

      bob.issues.delete(nil)
      expect(bob.issues).to be_empty

      bob.issues.destroy(nil)
      expect(bob.issues).to be_empty
    end

    describe 'validations' do
      xit 'does not create a link when parent is not valid'

      context 'with invalid child and validate: true' do
        it 'returns false when validating' do
          bob.issues = [Issue.new]
          expect(bob.valid?).to eq(false)
        end

        it 'returns false when saving' do
          bob.issues = [Issue.new]
          expect(bob.save).to eq(false)
        end

        it 'does not create a link' do
          bob.issues = [Issue.new]
          expect{ bob.save }.to_not change{ Person.find(bob.id).issues.size }
        end
      end

      context 'with valid child and validate: true' do
        it 'returns true when validating' do
          bob.issues = [Issue.new(subject: 'Valid!')]
          expect(bob.valid?).to eq(true)
        end

        it 'validates the child' do
          bob.issues = [Issue.new]
          bob.valid?
          expect(bob.issues.first.validation_log).to eq([
            'Validating new issue'
          ])
        end

        it 'returns true when saving' do
          bob.issues = [Issue.new(subject: 'Valid!')]
          expect(bob.save).to eq(true)
        end

        it 'creates a link' do
          bob.issues = [Issue.new(subject: 'Valid!')]
          expect{ bob.save }.to change{ Person.find(bob.id).issues.size }.from(0).to(1)
        end
      end

      context 'with invalid child and validate: false' do
        it 'returns true when validating' do
          bob.non_validated_issues = [NonValidatedIssue.new]
          expect(bob.valid?).to eq(true)
        end

        it 'does not validate the child' do
          bob.non_validated_issues = [NonValidatedIssue.new]
          bob.valid?
          expect(bob.non_validated_issues.first.validation_log).to eq([])
        end

        unless rails30 # rails 3.0 does not return a error
          it 'fails when trying to save the parent' do
            bob.non_validated_issues = [NonValidatedIssue.new]

            # Rails will raise the following error:
            # - ActiveRecord::RecordNotSaved:
            #     Failed to replace non_validated_issues because one or more of the new records could not be saved.
            #
            # This behaviour is different from the default Rails behaviour.
            # Rails will normally just save the parent and not save the
            # association.
            #
            # Two ways to avoid this error (using the Deferring gem):
            # - always use validate: true when user input is involved (e.g.
            #   using nested attributes to update the association),
            # - add validations to the parent to check validness of the
            #   children when a child record can be valid on itself but invalid
            #   when added to the parent
            expect{ bob.save }.to raise_error(ActiveRecord::RecordNotSaved)
          end
        end
      end

      context 'with valid child and validate: false' do
        it 'returns true when validating' do
          bob.non_validated_issues = [NonValidatedIssue.new(subject: 'Valid!')]
          expect(bob.valid?).to eq(true)
        end

        it 'returns true when saving' do
          bob.non_validated_issues = [NonValidatedIssue.new(subject: 'Valid!')]
          expect(bob.save).to eq(true)
        end

        it 'creates a link' do
          bob.non_validated_issues = [NonValidatedIssue.new(subject: 'Valid!')]
          expect{ bob.save }.to change{ Person.find(bob.id).non_validated_issues.size }.from(0).to(1)
        end
      end
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
    it 'sets associated records when posting an array of hashes' do
      p = Person.first
      p.attributes = {
        issues_attributes: [
          { id: printer_issue.id },
          { subject: 'Kapow!' },
        ]
      }
      expect(p.issues.length).to eq(2)
      expect(p.issue_ids).to eq([printer_issue.id, nil])

      expect{ p.save! }.to change{ Person.first.issues.size }.from(0).to(2)
    end

    it 'sets associated records when posting a hash of hashes' do
      p = Person.first
      p.attributes = {
        issues_attributes: {
          first: { subject: 'Kapow!' },
          second: { id: printer_issue.id }
        }
      }
      expect(p.issues.length).to eq(2)
      expect(p.issue_ids).to eq([nil, printer_issue.id])

      expect{ p.save! }.to change{ Person.first.issues.size }.from(0).to(2)
    end

    it 'updates associated records' do
      p = Person.first
      p.issues << printer_issue << db_issue << sandwich_issue
      p.save

      # Update printer issue.
      p = Person.first
      p.attributes = {
        issues_attributes: [{ id: printer_issue.id, subject: 'Toner low!' }]
      }
      p.save!

      expect(Issue.find(printer_issue.id).subject).to eq 'Toner low!'
    end

    it 'sets the belongs_to association of the associated record' do
      expect(printer_issue.person).to be_nil
      bob.attributes = {
        issues_attributes: [{ id: printer_issue.id }]
      }
      expect(bob.issues.first.person).to eq bob
    end

    it 'destroys an associated record when :allow_destroy is true' do
      p = Person.first
      p.issues << printer_issue << db_issue << sandwich_issue
      p.save

      # Destroy db and sandwich issues. Keep printer issue and create a new one.
      p = Person.first
      p.attributes = {
        issues_attributes: [{ id: sandwich_issue.id, _destroy: '1' }]
      }

      expect(p.issues.length).to eq(2)
      expect(p.issue_ids).to eq([printer_issue.id, db_issue.id])

      expect(p.issues.unlinks.first).to eq(sandwich_issue)

      expect{ p.save! }.to change{ Issue.count }.from(3).to(2)
    end

    it 'does not destroy an associated record when :allow_destroy is false' do
      Person.deferred_accepts_nested_attributes_for :issues, allow_destroy: false

      p = Person.first
      p.issues << printer_issue << db_issue << sandwich_issue
      p.save

      # Destroy db and sandwich issues. Keep printer issue and create a new one.
      p = Person.first
      p.attributes = {
        issues_attributes: [{ id: sandwich_issue.id, _destroy: '1' }]
      }

      expect(p.issues.length).to eq(3)
      expect(p.issue_ids).to eq([printer_issue.id, db_issue.id, sandwich_issue.id])

      expect(p.issues.unlinks.size).to eq(0)

      expect{ p.save! }.to_not change{ Issue.count }

      Person.deferred_accepts_nested_attributes_for :issues, allow_destroy: true
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
        people = Person.includes(:issues).to_a
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

  describe 'polymorphic association' do
    it 'sets the parent on the associated record before saving' do
      bob = Person.where(name: 'Bob').first
      bob.addresses << Address.new(street: '221B Baker St.')

      address = bob.addresses[0]
      expect(address.addressable).to eq(bob)
      expect(address.addressable_id).to eq(bob.id)
      expect(address.addressable_type).to eq('Person')
    end

    it 'adds the associated record' do
      bob = Person.where(name: 'Bob').first
      bob.addresses << Address.new(street: '221B Baker St.')
      bob.save!

      bob.reload
      address = bob.addresses[0]
      expect(address.street).to eq('221B Baker St.')
    end

    context 'when using nested attributes' do
      it 'sets the parent on the associated record before saving' do
        bob = Person.where(name: 'Bob').first
        bob.attributes = {
          addresses_attributes: [{ street: '221B Baker St.' }]
        }

        address = bob.addresses[0]
        expect(address.addressable).to eq(bob)
        expect(address.addressable_id).to eq(bob.id)
        expect(address.addressable_type).to eq('Person')
        expect(address.street).to eq('221B Baker St.')
      end
    end
  end
end
