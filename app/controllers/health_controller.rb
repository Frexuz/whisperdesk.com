class HealthController < ActionController::API
  def show
    render json: { status: "ok", timestamp: Time.current.utc.iso8601 }
  end
end
