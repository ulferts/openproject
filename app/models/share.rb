class Share < ApplicationRecord
  belongs_to :parent, class_name: 'Company'
  belongs_to :child, class_name: 'Company'
end
