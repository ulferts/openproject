class Company < ApplicationRecord
  belongs_to :owner, class_name: 'User'

  has_many :issued_shares, -> { where(active: true) }, foreign_key: 'child_id', inverse_of: :child, class_name: 'Share'
  has_many :parents, through: :issued_shares

  has_many :owned_shares, -> { where(active: true) }, foreign_key: 'parent_id', inverse_of: :parent, class_name: 'Share'
  has_many :children, through: :owned_shares

  # The set of owning users are those users, that are owners of companies,
  # which are parents (or any ancestor) to the company being represented.
  #
  # Those owners then overrule any owner directly linked to the represented
  # company. This overruling takes place on every level of ancestry.
  #
  # E.g. In a set of companies
  #
  # grandparent - (owner A)
  # parent - (owner B)
  # child - (owner C)
  #
  # the owning user of child is A.
  #
  # The overruling only takes place if the share is active.
  # So in the example above, with the share between parent and grandparent not
  # being active, the owning user of child would be B.
  #
  # If a company has no parent or only has parents on inactive shares, the
  # owning user is the user of the company. Referring to the example again, if
  # the share between child and parent were to be inactive (or to not exist at
  # all), the owning user of child would be C.
  #
  # Since a company can have multiple parents, there can also be multiple owning
  # users
  #
  # E.g. in a set of companies
  #
  #                                  grandgrandparent 1 (parent to grandparent 2) - (owner A)
  # grandparent 1 - (owner B)        grandparent 2 - (owner C)
  #                  parent - (owner D)
  #                  child - (owner E)
  #
  # assuming that every share is active, the owning users of child would be A and B.
  def owning_users
    @owning_users ||= begin
      return [owner] if parents.none?

      parents.map do |parent|
        parent.owning_users
      end.flatten
    end
  end
end
