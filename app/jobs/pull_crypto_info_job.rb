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
    coinCapResp = fetchData(COINCAP_URL)
    btcFeeResp = fetchData(BLOCKCHAIN_INFO_URL)
    ethGasResp = fetchData(ETHERSCAN_INFO_URL)
    bscResp = fetchData(BSCSCAN_URL)
    mapiTaalResp = fetchData(MAPITAAL_URL)

    data = coinCapResp['data']
    bscData = bscResp['result']
    if data
      bitcoinData = fetchCryptoInfo(data, 'bitcoin')
      ethereumData = fetchCryptoInfo(data, 'ethereum')
      bitcoinSVData = fetchCryptoInfo(data, 'bitcoin-sv')

      logger.debug bitcoinData.to_s
      logger.debug ethereumData.to_s
      logger.debug bitcoinSVData.to_s

      if bitcoinData
        btcRate = bitcoinData['priceUsd'].to_f
        btcName = bitcoinData['name'].to_s
        btcTransFee = singleBTCTransaction(btcFeeResp, btcRate)
        logger.debug "btcTransFee #{btcTransFee}"
      end

      if ethereumData
        ethRate = ethereumData['priceUsd'].to_f
        ethName = ethereumData['name'].to_s
        ethTransFee = singleEthTransaction(ethGasResp, ethRate)
        logger.debug "ethTransFee #{ethTransFee}"
      end

      if bitcoinSVData
        bsvRate = bitcoinSVData['priceUsd'].to_f
        bsvName = bitcoinSVData['name'].to_s
        bsvTransFee = singleBSVTransaction(mapiTaalResp, bsvRate)
        logger.debug "bsvTransFee #{bsvTransFee}"
      end
    end

    if bscData
      bscFee = bscData['SafeGasPrice'].to_i
      bscRate = bscData['UsdPrice'].to_f
      bscTransFee = singleBCSTransaction(bscFee, bscRate)
      logger.debug "bscTransFee #{bscTransFee}"
    end

    updateDB('bitcoin', btcName, btcTransFee, 2)
    updateDB('ethereum', ethName, ethTransFee, 20)
    updateDB('bitcoin-sv', bsvName, bsvTransFee, 20)
    updateDB(BSC_KEY, BSC_NAME, bscTransFee, 0)
  end

  private

  def fetchData(url)
    JSON.parse URI.open(url).read
  end

  def fetchCryptoInfo(data, id)
    data.select { |crypto| crypto['id'] == id }.try(:first)
  end

  def singleBTCTransaction(btcFeeResp, rate)
    fee = btcFeeResp['regular']
    btcBsvFormula(fee, rate)
  end

  def singleBSVTransaction(btcFeeResp, rate)
    feeData = JSON.parse(btcFeeResp['payload'])['fees'].select { |gas| gas['feeType'] == 'standard' }.try(:first)
    if feeData
      feePair = feeData['relayFee']
      feePerByte = feePair['satoshis'].to_f / feePair['bytes'].to_i
      btcBsvFormula(feePerByte, rate)
    end
  end

  def singleEthTransaction(ethGasResp, rate)
    ethFee = ethGasResp['result']['suggestBaseFee'].to_i
    bscEthFormula(ethFee, rate)
  end

  def singleBCSTransaction(bscFee, bscRate)
    bscEthFormula(bscFee, bscRate)
  end

  def updateDB(id, name, singleTransactionFee, factor)
    if singleTransactionFee > 0
      CryptoCoin.find_or_initialize_by(key: id).update(key: id, name: name, single_cost: singleTransactionFee,
                                                       multisig_cost: singleTransactionFee * factor)
    end
  end

  def bscEthFormula(fee, rate)
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
