class Issue < ActiveRecord::Base
  belongs_to :person

  validates_presence_of :subject
  validate :dummy_validation

  def validation_log
    @validation_log ||= []
  end

  def log(validation_line)
    validation_log << validation_line
    validation_log
  end

  def dummy_validation
    if new_record?
      log("Validating new issue")
    else
      log("Validating issue #{id}")
    end
  end
end

