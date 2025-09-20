require 'rails_helper'

RSpec.describe 'Tenant routing & middleware', type: :request do
  before { @tenant = Tenant.create!(subdomain: 'acme') }

  def host_for(sub)
    "#{sub}.lvh.me" # lvh.me resolves to 127.0.0.1 and preserves subdomain
  end

  it 'returns 200 for valid subdomain route' do
    host! host_for('acme')
    get '/tenant_health'
    expect(response).to have_http_status(:ok)
  end

  it '404 for unknown subdomain' do
    host! host_for('unknown')
    get '/tenant_health'
    expect(response).to have_http_status(:not_found)
  end

  it '404 for reserved subdomain' do
    host! host_for('www')
    get '/tenant_health'
    expect(response).to have_http_status(:not_found)
  end

  it '404 for apex domain on tenant route' do
    host! 'lvh.me'
    get '/tenant_health'
    expect(response).to have_http_status(:not_found)
  end

  it 'JSON 404 for unknown subdomain with JSON accept' do
    host! host_for('nope')
    get '/tenant_health', headers: { 'ACCEPT' => 'application/json' }
    expect(response).to have_http_status(:not_found)
    expect(JSON.parse(response.body)['error']).to eq('Not Found')
  end

  it '403 for cross-tenant record access' do
    other = Tenant.create!(subdomain: 'beta')
    item = SampleItem.create!(tenant: other, name: 'Hidden')
    host! host_for('acme')
    get "/sample_items/#{item.id}", headers: { 'ACCEPT' => 'application/json' }
    expect(response).to have_http_status(:forbidden)
  end

  it 'clears Current.tenant between requests' do
    host! host_for('acme')
    get '/tenant_health'
    expect(Current.tenant).to be_nil
    Tenant.create!(subdomain: 'beta')
    host! host_for('beta')
    get '/tenant_health'
    expect(Current.tenant).to be_nil
  end
end
