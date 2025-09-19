class ApplicationController < ActionController::Base
  include Pundit::Authorization

  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  rescue_from Pundit::NotAuthorizedError, with: :user_not_authorized

  private

  def user_not_authorized
    respond_to do |format|
      format.html do
        redirect_to(request.referer.present? ? request.referer : root_path, alert: "You are not authorized to perform this action.")
      end
      format.json { render json: { error: "forbidden" }, status: :forbidden }
    end
  end
end
