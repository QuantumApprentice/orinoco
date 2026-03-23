class ObsConfigsController < ApplicationController
  skip_before_action :ensure_obs_config!

  def edit
    @obs_config = ObsConfig.first_or_initialize
  end

  def create
    @obs_config = ObsConfig.first_or_initialize
    @obs_config.assign_attributes(obs_config_params)

    if @obs_config.save
      redirect_to(safe_return_to || edit_obs_config_path, notice: "OBS config saved.")
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def update
    @obs_config = ObsConfig.first

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

  def safe_return_to
    uri = URI.parse(params[:return_to].to_s)
    uri.path if uri.host.nil?
  rescue URI::InvalidURIError
    nil
  end
end
