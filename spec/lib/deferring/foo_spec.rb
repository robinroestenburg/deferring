require 'spec_helper'

module Deferring
  describe Foo do

    before do
      Person.create!(name: 'Bob')

      Team.create!(name: 'Database Administration')
      Team.create!(name: 'End-User Support')
      Team.create!(name: 'Operations')
    end

    describe '#pending_creates' do

      it 'returns associated records that need to be linked to parent' do
        bob = Person.first
        bob.teams = [Team.first]

        expect(bob.teams.pending_creates).to eq [Team.first]
      end

      it 'does not return associated records that already have a link' do
        bob = Person.first
        bob.teams = [Team.first]
        bob.save!

        bob.teams << Team.last

        expect(bob.teams.pending_creates).to_not include Team.first
        expect(bob.teams.pending_creates).to include Team.last
      end

      it 'does not return associated records that are to be deleted' do
        bob = Person.first
        bob.teams = [Team.first, Team.last]
        bob.save!
        bob.teams.delete(Team.first)

        expect(bob.teams.pending_creates).to be_empty
      end

    end
  end
end
