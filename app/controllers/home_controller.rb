class HomeController < ApplicationController
  def index
    @crypto_coins = CryptoCoin.all.sort_by(&:name)
  end
end
