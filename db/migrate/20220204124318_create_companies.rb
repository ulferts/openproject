class CreateCompanies < ActiveRecord::Migration[6.1]
  def change
    create_table :companies do |t|
      t.string :name
      t.references :owner, null: false, foreign_key: { to_table: :users }

      t.timestamps
    end
  end
end
