module RequiresTenant
  extend ActiveSupport::Concern

  included do
    before_action :ensure_current_tenant!
  end

  private

  def ensure_current_tenant!
    raise Tenant::NotFound unless Current.tenant
  end
end
