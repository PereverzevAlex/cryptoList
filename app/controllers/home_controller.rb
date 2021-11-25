class HomeController < ApplicationController
  def index
    @cryptoCoins = CryptoCoin.all.sort_by(&:name)
  end
end
