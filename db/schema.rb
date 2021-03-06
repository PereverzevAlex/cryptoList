# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema.define(version: 20_211_124_155_603) do
  # These are extensions that must be enabled in order to support this database
  enable_extension 'plpgsql'

  create_table 'crypto_coins', force: :cascade do |t|
    t.string 'key'
    t.string 'name', null: false
    t.decimal 'single_cost', null: false
    t.decimal 'multisig_cost'
    t.datetime 'created_at', precision: 6, null: false
    t.datetime 'updated_at', precision: 6, null: false
    t.index ['key'], name: 'index_crypto_coins_on_key', unique: true
  end
end
