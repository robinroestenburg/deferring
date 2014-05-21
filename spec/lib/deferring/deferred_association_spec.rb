require 'spec_helper'

module Deferring
  describe DeferredAssociation do

    before do
      Person.create!(name: 'Bob')

      Team.create!(name: 'Database Administration')
      Team.create!(name: 'End-User Support')
      Team.create!(name: 'Operations')
    end

    describe '#pending_deletes' do

      it 'returns associated records that need to be unlinked from parent' do
        bob = Person.first
        bob.teams = [Team.first]
        bob.save!
        bob.teams.delete(Team.first)

        expect(bob.teams.pending_deletes).to eq [Team.first]
      end

      it 'returns an empty array when no records are to be deleted' do
        bob = Person.first
        bob.teams = [Team.first]
        bob.save!

        expect(bob.teams.pending_deletes).to be_empty
      end

      it 'does not return a record that has just been added (and has not been saved)' do
        bob = Person.first
        bob.teams = [Team.first]
        bob.teams.delete(Team.first)

        expect(bob.teams.pending_deletes).to be_empty
        expect(bob.teams.pending_creates).to be_empty
      end

    end
  end
end
