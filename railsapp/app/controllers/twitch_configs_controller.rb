class TwitchConfigsController < ApplicationController
  before_action :set_twitch_config, only: %i[ show edit update destroy ]

  # GET /twitch_configs or /twitch_configs.json
  def index
    @twitch_configs = TwitchConfig.all
  end

  # GET /twitch_configs/1 or /twitch_configs/1.json
  def show
  end

  # GET /twitch_configs/new
  def new
    @twitch_config = TwitchConfig.new
  end

  # GET /twitch_configs/1/edit
  def edit
  end

  # POST /twitch_configs or /twitch_configs.json
  def create
    @twitch_config = TwitchConfig.new(twitch_config_params)

    respond_to do |format|
      if @twitch_config.save
        format.html { redirect_to @twitch_config, notice: "Twitch config was successfully created." }
        format.json { render :show, status: :created, location: @twitch_config }
      else
        format.html { render :new, status: :unprocessable_entity }
        format.json { render json: @twitch_config.errors, status: :unprocessable_entity }
      end
    end
  end

  # PATCH/PUT /twitch_configs/1 or /twitch_configs/1.json
  def update
    respond_to do |format|
      if @twitch_config.update(twitch_config_params)
        format.html { redirect_to @twitch_config, notice: "Twitch config was successfully updated.", status: :see_other }
        format.json { render :show, status: :ok, location: @twitch_config }
      else
        format.html { render :edit, status: :unprocessable_entity }
        format.json { render json: @twitch_config.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /twitch_configs/1 or /twitch_configs/1.json
  def destroy
    @twitch_config.destroy!

    respond_to do |format|
      format.html { redirect_to twitch_configs_path, notice: "Twitch config was successfully destroyed.", status: :see_other }
      format.json { head :no_content }
    end
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_twitch_config
      @twitch_config = TwitchConfig.find(params.expect(:id))
    end

    # Only allow a list of trusted parameters through.
    def twitch_config_params
      params.require(:twitch_config).permit(:channel_name)
    end
end
