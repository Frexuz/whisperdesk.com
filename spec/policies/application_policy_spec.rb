require "rails_helper"

RSpec.describe ApplicationPolicy do
  subject(:policy_scope) { described_class::Scope.new(nil, User).resolve }

  it "returns all records for nil user" do
    expect(policy_scope).to eq(User.all)
  end
end
