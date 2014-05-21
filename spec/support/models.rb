# encoding: UTF-8

class Person < ActiveRecord::Base
  deferred_has_and_belongs_to_many :teams, autosave: false,
                                           before_add: :add_team,
                                           after_add: :added_team
  set_callback :deferred_team_remove, :before, :before_removing_team
  set_callback :deferred_team_remove, :after, :after_removing_team

  deferred_accepts_nested_attributes_for :teams, allow_destroy: true

  validates_presence_of :name

  deferred_has_many :issues
  set_callback :deferred_issue_remove, :before, :before_removing_issue
  set_callback :deferred_issue_remove, :after, :after_removing_issue

  def audit_log
    @audit_log ||= []
  end

  def log(audit_line)
    audit_log << audit_line
    audit_log
  end

  def add_team(team)
    log("Before adding team #{team.id}")
  end

  def added_team(team)
    log("After adding team #{team.id}")
  end

  def before_removing_team
    log("Before removing team #{@deferred_team_remove.id}")
  end

  def after_removing_team
    log("After removing team #{@deferred_team_remove.id}")
  end

  def before_adding_issue
    log("Before removing issue #{@deferred_issue_add.id}")
  end

  def after_adding_issue
    log("After removing issue #{@deferred_issue_add.id}")
  end
end

class Team < ActiveRecord::Base
  has_and_belongs_to_many :people

  validate :no_more_than_two_people_per_team

  def no_more_than_two_people_per_team
    if people.length > 2
      errors.add(:people, "A maximum of two persons per team is allowed")
    end
  end
end

class Issue < ActiveRecord::Base
  belongs_to :person
end
