class CreateAreaCachedObjs < ActiveRecord::Migration[5.0]
  def change
    create_table :area_cached_objs do |t|
      t.references :area, null: false, foreign_key: true
      t.text :obj_data, null: false, default: ''
      t.timestamps
    end
  end
end
