class Team < ActiveRecord::Base
  has_and_belongs_to_many :people

  validates :name, presence: true
  validate :no_more_than_two_people_per_team

  def no_more_than_two_people_per_team
    if people.length > 2
      errors.add(:people, "A maximum of two persons per team is allowed")
    end
  end
end
