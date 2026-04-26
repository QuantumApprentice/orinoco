class ObsConfig < ApplicationRecord
  after_initialize :set_defaults, if: :new_record?

  private
  def set_defaults
    self.host ||= "localhost.docker.internal"
    self.port ||= 4455
  end

end
