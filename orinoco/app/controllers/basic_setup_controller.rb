class BasicSetupController < ApplicationController
  def index
    @obs_config=ObsConfig.first_or_initialize

  end
end
