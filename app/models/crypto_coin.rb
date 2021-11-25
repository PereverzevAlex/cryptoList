class CryptoCoin < ApplicationRecord
  after_create_commit { broadcast_prepend_to 'crypto_coins' }
  after_update_commit { broadcast_prepend_to 'crypto_coins' }
end
