class SetCurrentTenant
  def initialize(app)
    @app = app
  end

  def call(env)
    request = ActionDispatch::Request.new(env)
    sub = request.subdomains.first
    if sub
      tenant = Tenant.find_by(subdomain: sub)
      raise Tenant::NotFound, "Unknown tenant" unless tenant
      Current.tenant = tenant
    end
    @app.call(env)
  rescue Tenant::NotFound
    not_found_response(request)
  ensure
    Current.reset
  end

  private

  def not_found_response(request)
    if request.format.json?
      [404, { 'Content-Type' => 'application/json' }, [{ error: 'Not Found' }.to_json]]
    else
      body = File.read(Rails.root.join('public/404.html'))
      [404, { 'Content-Type' => 'text/html' }, [body]]
    end
  end
end
