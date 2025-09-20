class SubdomainRequiredConstraint
  def matches?(request)
    sub = request.subdomains.first
    return false if sub.blank?
    return false if Tenant::RESERVED.include?(sub)
    true
  end
end
