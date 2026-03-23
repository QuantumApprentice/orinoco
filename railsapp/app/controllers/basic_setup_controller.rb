class BasicSetupController < ApplicationController
  skip_before_action :ensure_obs_config!

  def index
    @obs_config=ObsConfig.first_or_initialize

  end
end
