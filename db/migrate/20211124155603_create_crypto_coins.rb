class CreateCryptoCoins < ActiveRecord::Migration[6.1]
  def change
    create_table :crypto_coins do |t|
      t.string :key
      t.string :name, null: false
      t.decimal :single_cost, null: false
      t.decimal :multisig_cost

      t.timestamps
    end
    add_index :crypto_coins, :key, unique: true
  end
end
