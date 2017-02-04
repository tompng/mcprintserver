class CreateAreas < ActiveRecord::Migration[5.0]
  def change
    create_table :areas do |t|
      t.integer :coord_i, null: false
      t.integer :coord_j, null: false
      t.timestamps
    end
    add_index :areas, [:coord_i, :coord_j], unique: true
  end
end
