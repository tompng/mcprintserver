class CreateDemoAccounts < ActiveRecord::Migration[5.0]
  def change
    create_table :demo_accounts do |t|
      t.references :area, null: false, foreign_key: true
      t.string :username, null: false
    end
  end
end
