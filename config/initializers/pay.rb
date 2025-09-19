# Basic Pay gem configuration
Pay.setup do |config|
  config.default_product_name = "WhisperDesk Subscription"
  config.default_plan_name = "Standard"
  config.business_name = "WhisperDesk"
  config.business_address = "123 Internet Road"
  config.application_name = "WhisperDesk"
  config.support_email = ENV.fetch("SUPPORT_EMAIL", "support@example.com")
end
