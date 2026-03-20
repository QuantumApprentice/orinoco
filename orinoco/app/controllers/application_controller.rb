class ApplicationController < ActionController::Base
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  # Changes to the importmap will invalidate the etag for HTML responses
  stale_when_importmap_changes

  before_action :ensure_obs_config!

  private

  def ensure_obs_config!
    return if obs_config_present?

    redirect_to basic_setup_index_path(return_to: request.fullpath)
  end

  def obs_config_present?
    ObsConfig.exists?
  end
end
