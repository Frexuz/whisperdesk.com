require 'rails_helper'

RSpec.describe Tenant, type: :model do
  it 'downcases subdomain' do
    t = Tenant.create!(subdomain: 'AcMe')
    expect(t.reload.subdomain).to eq('acme')
  end

  it 'enforces uniqueness case-insensitive' do
    Tenant.create!(subdomain: 'demo')
    dup = Tenant.new(subdomain: 'DEMO')
    expect(dup).not_to be_valid
  end

  it 'rejects reserved subdomains' do
    t = Tenant.new(subdomain: 'www')
    expect(t).not_to be_valid
  end
end
