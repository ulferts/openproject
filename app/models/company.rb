class Company < ApplicationRecord
  belongs_to :owner, class_name: 'User'

  def owning_users
    [owner]
  end
end
