class CreateShares < ActiveRecord::Migration[6.1]
  def change
    create_table :shares do |t|
      t.boolean :active
      t.references :parent, null: false, foreign_key: { to_table: :companies }, index: true
      t.references :child, null: false, foreign_key: { to_table: :companies }, index: true

      t.timestamps
    end
  end
end
