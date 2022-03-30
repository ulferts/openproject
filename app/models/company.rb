class Company < ApplicationRecord
  has_many :parent_shares, -> { where(active: true) }, foreign_key: 'child_id', class_name: 'Share'
  has_many :parents, through: :parent_shares

  has_many :children_shares, -> { where(active: true) }, foreign_key: 'parent_id', class_name: 'Share'
  has_many :children, through: :children_shares

  belongs_to :owner, class_name: 'User'

  def parents_users
    @parents_users ||= parents.exists? ? users : [owner]
  end

  private

  def users
    parents.map { |parent| parent.parents_users }.flatten
  end
end
