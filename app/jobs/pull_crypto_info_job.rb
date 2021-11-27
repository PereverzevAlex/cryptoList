require 'open-uri'
require 'json'

class PullCryptoInfoJob < ApplicationJob
  queue_as :default

  COINCAP_URL = 'http://api.coincap.io/v2/assets'
  BLOCKCHAIN_INFO_URL = 'https://api.blockchain.info/mempool/fees'
  ETHERSCAN_INFO_URL = 'https://api.etherscan.io/api?module=gastracker&action=gasoracle&apikey=YourApiKeyToken'
  BSCSCAN_URL = 'https://api.bscscan.com/api?module=gastracker&action=gasoracle&apikey=YourApiKeyToken'
  MAPITAAL_URL = 'https://mapi.taal.com/mapi/feeQuote'
  # cannot retriev name or id for BSC from provided api coincap.io, so just hardcode it
  BSC_NAME = 'Binance Smart Chain'
  BSC_KEY = 'binance-smart-chain'

  def perform(*_args)
    logger.debug '---> RUN CRON'
    coin_cap_resp = fetch_data(COINCAP_URL)
    btc_fee_resp = fetch_data(BLOCKCHAIN_INFO_URL)
    eth_gas_resp = fetch_data(ETHERSCAN_INFO_URL)
    bsc_resp = fetch_data(BSCSCAN_URL)
    mapi_taal_resp = fetch_data(MAPITAAL_URL)

    data = coin_cap_resp['data']
    bsc_data = bsc_resp['result']
    if data
      bitcoin_data = fetch_crypto_info(data, 'bitcoin')
      ethereum_data = fetch_crypto_info(data, 'ethereum')
      bitcoin_sv_data = fetch_crypto_info(data, 'bitcoin-sv')

      logger.debug bitcoin_data.to_s
      logger.debug ethereum_data.to_s
      logger.debug bitcoin_sv_data.to_s

      if bitcoin_data
        btcRate = bitcoin_data['priceUsd'].to_f
        btcName = bitcoin_data['name'].to_s
        btcTransFee = single_btc_transaction(btc_fee_resp, btcRate)
        logger.debug "btcTransFee #{btcTransFee}"
      end

      if ethereum_data
        ethRate = ethereum_data['priceUsd'].to_f
        ethName = ethereum_data['name'].to_s
        ethTransFee = singleEthTransaction(eth_gas_resp, ethRate)
        logger.debug "ethTransFee #{ethTransFee}"
      end

      if bitcoin_sv_data
        bsvRate = bitcoin_sv_data['priceUsd'].to_f
        bsvName = bitcoin_sv_data['name'].to_s
        bsvTransFee = single_bsv_transaction(mapi_taal_resp, bsvRate)
        logger.debug "bsvTransFee #{bsvTransFee}"
      end
    end

    if bsc_data
      bscFee = bsc_data['SafeGasPrice'].to_i
      bscRate = bsc_data['UsdPrice'].to_f
      bscTransFee = single_bcs_transaction(bscFee, bscRate)
      logger.debug "bscTransFee #{bscTransFee}"
    end

    update_db('bitcoin', btcName, btcTransFee, 2)
    update_db('ethereum', ethName, ethTransFee, 20)
    update_db('bitcoin-sv', bsvName, bsvTransFee, 20)
    update_db(BSC_KEY, BSC_NAME, bscTransFee, 0)
  end

  private

  def fetch_data(url)
    JSON.parse URI.open(url).read
  end

  def fetch_crypto_info(data, id)
    data.select { |crypto| crypto['id'] == id }.try(:first)
  end

  def single_btc_transaction(btc_fee_resp, rate)
    fee = btc_fee_resp['regular']
    btcBsvFormula(fee, rate)
  end

  def single_bsv_transaction(btc_fee_resp, rate)
    feeData = JSON.parse(btc_fee_resp['payload'])['fees'].select { |gas| gas['feeType'] == 'standard' }.try(:first)
    if feeData
      fee_pair = feeData['relayFee']
      fee_per_byte = fee_pair['satoshis'].to_f / fee_pair['bytes'].to_i
      btcBsvFormula(fee_per_byte, rate)
    end
  end

  def singleEthTransaction(eth_gas_resp, rate)
    eth_fee = eth_gas_resp['result']['suggestBaseFee'].to_i
    bsc_eth_formula(eth_fee, rate)
  end

  def single_bcs_transaction(bscFee, bscRate)
    bsc_eth_formula(bscFee, bscRate)
  end

  def update_db(id, name, single_transaction_fee, factor)
    if single_transaction_fee > 0
      CryptoCoin.find_or_initialize_by(key: id).update(key: id, name: name, single_cost: single_transaction_fee,
                                                       multisig_cost: single_transaction_fee * factor)
    end
  end

  def bsc_eth_formula(fee, rate)
    if fee && rate
      21_000 * fee * rate * 10**-9
    else
      0
    end
  end

  def btcBsvFormula(fee, rate)
    if fee && rate
      fee * 192 * rate * 10**-8
    else
      0
    end
  end
end
