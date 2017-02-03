# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# Note that this schema.rb definition is the authoritative source for your
# database schema. If you need to create the application database on another
# system, you should be using db:schema:load, not running all the migrations
# from scratch. The latter is a flawed and unsustainable approach (the more migrations
# you'll amass, the slower it'll run and the greater likelihood for issues).
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema.define(version: 20170203144848) do

  create_table "areas", force: :cascade do |t|
    t.integer  "coord_i",    null: false
    t.integer  "coord_j",    null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["coord_i", "coord_j"], name: "index_areas_on_coord_i_and_coord_j", unique: true
  end

  create_table "demo_accounts", force: :cascade do |t|
    t.integer "area_id",  null: false
    t.string  "username", null: false
    t.index ["area_id", "username"], name: "index_demo_accounts_on_area_id_and_username", unique: true
    t.index ["area_id"], name: "index_demo_accounts_on_area_id"
  end

end
