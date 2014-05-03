# encoding: UTF-8

class Person < ActiveRecord::Base
  deferred_has_and_belongs_to_many :teams, before_add: :before_adding_team,
                                           after_add: :after_adding_team,
                                           before_remove: :before_removing_team,
                                           after_remove: :after_removing_team

  deferred_accepts_nested_attributes_for :teams, allow_destroy: true

  validates_presence_of :name

  has_many :issues

  def audit_log
    @audit_log ||= []
  end

  def log(audit_line)
    audit_log << audit_line
    audit_log
  end

  def before_adding_team(team)
    log("Before adding team #{team.id}")
  end

  def after_adding_team(team)
    log("After adding team #{team.id}")
  end

  def before_removing_team(team)
    log("Before removing team #{team.id}")
  end

  def after_removing_team(team)
    log("After removing team #{team.id}")
  end
end

class Team < ActiveRecord::Base
  has_and_belongs_to_many :people
end

class Issue < ActiveRecord::Base
  belongs_to :person
end
