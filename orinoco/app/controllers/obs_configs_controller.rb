class ObsConfigsController < ApplicationController
  skip_before_action :ensure_obs_config!

  def edit
    @obs_config = ObsConfig.first_or_initialize
  end

  def update
    @obs_config = ObsConfig.first_or_initialize

    if @obs_config.update(obs_config_params)
      redirect_to edit_obs_config_path, notice: "OBS config saved."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  private

  def obs_config_params
    params.expect(obs_config: [:host, :port])
  end
end