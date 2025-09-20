class ApplicationController < ActionController::Base
  include Pundit::Authorization
  # Include tenant requirement automatically for Tenanted namespace controllers
  include RequiresTenant, if: -> { tenant_scoped_controller? }

  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  rescue_from Pundit::NotAuthorizedError, with: :user_not_authorized
  rescue_from Tenant::AccessDenied, with: :tenant_access_denied if defined?(Tenant::AccessDenied)
  rescue_from Tenant::NotFound, with: :tenant_not_found if defined?(Tenant::NotFound)

  private

  def user_not_authorized
    respond_to do |format|
      format.html do
        redirect_to(request.referer.present? ? request.referer : root_path, alert: "You are not authorized to perform this action.")
      end
      format.json { render json: { error: "forbidden" }, status: :forbidden }
    end
  end

  def tenant_access_denied
    respond_to do |format|
      format.json { render json: { error: 'Forbidden' }, status: :forbidden }
      format.html { render file: Rails.root.join('public/403.html'), status: :forbidden, layout: false }
    end
  end

  def tenant_not_found
    respond_to do |format|
      format.json { render json: { error: 'Not Found' }, status: :not_found }
      format.html { render file: Rails.root.join('public/404.html'), status: :not_found, layout: false }
    end
  end

  # Helper to assert tenant ownership of a record
  def assert_tenant!(record)
    raise Tenant::AccessDenied unless record && record.respond_to?(:tenant_id) && record.tenant_id == Current.tenant&.id
  end

  def tenant_scoped_controller?
    self.class.name.start_with?('Tenanted::')
  end
end
