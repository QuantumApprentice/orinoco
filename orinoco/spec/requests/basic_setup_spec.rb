require 'rails_helper'

RSpec.describe "BasicSetups", type: :request do
  describe "GET /index" do
    it "returns http success" do
      get "/basic_setup/index"
      expect(response).to have_http_status(:success)
    end
  end

end
