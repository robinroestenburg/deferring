require 'spec_helper'

RSpec.describe 'deferred accepts_nested_attributes' do

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

end
