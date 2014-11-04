class NonValidatedIssue < ActiveRecord::Base
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
      log("Validating new non validated issue")
    else
      log("Validating non validated issue #{id}")
    end
  end

end
