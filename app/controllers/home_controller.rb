class HomeController < ApplicationController

    def index
        @cryptoCoins = CryptoCoin.all
    end
end