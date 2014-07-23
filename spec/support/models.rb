# encoding: UTF-8

class Person < ActiveRecord::Base

  deferred_has_and_belongs_to_many :teams, before_link: :link_team,
                                           after_link: :linked_team,
                                           before_unlink: :unlink_team,
                                           after_unlink: :unlinked_team,
                                           before_add: :add_team,
                                           after_add: :added_team,
                                           before_remove: :remove_team,
                                           after_remove: :removed_team

  deferred_accepts_nested_attributes_for :teams, allow_destroy: true

  deferred_has_many :issues, before_remove: :remove_issue,
                             after_remove: :removed_issue

  validates_presence_of :name

  def audit_log
    @audit_log ||= []
  end

  def log(audit_line)
    audit_log << audit_line
    audit_log
  end

  def link_team(team)
    log("Before linking team #{team.id}")
  end

  def linked_team(team)
    log("After linking team #{team.id}")
  end

  def unlink_team(team)
    log("Before unlinking team #{team.id}")
  end

  def unlinked_team(team)
    log("After unlinking team #{team.id}")
  end

  def add_team(team)
    log("Before adding team #{team.id}")
  end

  def added_team(team)
    log("After adding team #{team.id}")
  end

  def remove_team(team)
    log("Before removing team #{team.id}")
  end

  def removed_team(team)
    log("After removing team #{team.id}")
  end

  def add_issue(issue)
    log("Before removing issue #{issue.id}")
  end

  def added_issue(issue)
    log("After removing issue #{issue.id}")
  end
end

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

class Issue < ActiveRecord::Base
  belongs_to :person
end
