class ApplicationController < ActionController::Base
  allow_browser versions: :modern unless Rails.env.test?

  stale_when_importmap_changes

  before_action :ensure_obs_config!

  private

  def ensure_obs_config!
    return if Rails.env.test?
    return if obs_config_present?

    redirect_to basic_setup_index_path(return_to: request.fullpath)
  end

  def obs_config_present?
    ObsConfig.exists?
  end
end
