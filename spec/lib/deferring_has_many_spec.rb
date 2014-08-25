require 'spec_helper'

RSpec.describe 'deferred has_many associations' do

  before(:each) do
    Person.create!(name: 'Alice')
    Person.create!(name: 'Bob')

    Issue.create!(subject: 'Printer PRT-001 jammed')
    Issue.create!(subject: 'Database server DB-1337 down')
    Issue.create!(subject: 'Make me a sandwich!')
  end

  let(:printer_issue) { Issue.where(subject: 'Printer PRT-001 jammed').first }
  let(:db_issue) { Issue.where(subject: 'Database server DB-1337 down').first }
  let(:sandwich_issue) { Issue.where(subject: 'Make me a sandwich!').first }

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
  end

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
  end

end
