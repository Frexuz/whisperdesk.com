require "rails_helper"

RSpec.describe User, type: :model do
  it "is valid with email and password" do
    user = User.new(email: "spec@example.com", password: "Password123!", password_confirmation: "Password123!")
    expect(user).to be_valid
  end
end
