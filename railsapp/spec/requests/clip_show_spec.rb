require 'rails_helper'

RSpec.describe "ClipShows", type: :request do
  describe "GET /index" do
    it "returns http success" do
      get "/clip_show/index"
      expect(response).to have_http_status(:success)
    end
  end

  describe "GET /play" do
    it "returns http success" do
      get "/clip_show/play"
      expect(response).to have_http_status(:success)
    end
  end

end
