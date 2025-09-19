class User < ApplicationRecord
  # Include default devise modules. Others available are:
  # :lockable, :timeoutable, :omniauthable and :trackable
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable, :confirmable

  # Billing & subscriptions
  include Pay::Billable if defined?(Pay::Billable)
end
