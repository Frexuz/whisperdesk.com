class Current < ActiveSupport::CurrentAttributes
  attribute :tenant, :user, :request_id

  def tenant_id
    tenant&.id
  end
end
