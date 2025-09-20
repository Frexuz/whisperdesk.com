require 'rails_helper'

RSpec.describe 'SampleItems', type: :request do
  it 'shows item for owning tenant' do
    tenant = Tenant.create!(subdomain: 'acme')
    item = SampleItem.create!(tenant: tenant, name: 'Widget')
    host! 'acme.lvh.me'
    get "/sample_items/#{item.id}", headers: { 'ACCEPT' => 'application/json' }
    expect(response).to have_http_status(:ok)
    json = JSON.parse(response.body)
    expect(json['name']).to eq('Widget')
  end
end
