require "rails_helper"

RSpec.describe "Health Endpoint", type: :request do
  describe "GET /health" do
    it "returns ok JSON payload" do
      get "/health"
      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json["status"]).to eq("ok")
      expect(json).to have_key("timestamp")
    end
  end
end
