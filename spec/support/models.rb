# encoding: UTF-8

class Person < ActiveRecord::Base
  deferred_has_and_belongs_to_many :teams, autosave: false,
                                           before_add: :add_team,
                                           after_add: :added_team
  set_callback :deferred_team_remove, :before, lambda { |r| before_removing_team(r) }
  set_callback :deferred_team_remove, :after, lambda { |r| after_removing_team(r) }

  deferred_accepts_nested_attributes_for :teams, allow_destroy: true

  validates_presence_of :name

  deferred_has_many :issues, before_add: :before_adding_issue,
                             after_add: :after_adding_issue
  set_callback :deferred_issue_remove, :before, lambda { |r| before_removing_issue(r) }
  set_callback :deferred_issue_remove, :after, lambda { |r| after_removing_issue(r) }

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

  def before_removing_team(team)
    log("Before removing team #{team.id}")
  end

  def after_removing_team(team)
    log("After removing team #{team.id}")
  end

  def before_adding_issue(issue)
    log("Before removing issue #{issue.id}")
  end

  def after_adding_issue(issue)
    log("After removing issue #{issue.id}")
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
