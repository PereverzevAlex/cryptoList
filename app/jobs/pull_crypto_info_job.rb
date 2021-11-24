require 'open-uri'
require 'json'

class PullCryptoInfoJob < ApplicationJob
  queue_as :default
  
  COINCAP_URL = "http://api.coincap.io/v2/assets"
  BLOCKCHAIN_INFO_URL = "https://api.blockchain.info/mempool/fees"
  ETHERSCAN_INFO_URL = "https://api.etherscan.io/api?module=gastracker&action=gasoracle&apikey=YourApiKeyToken"
  BSCSCAN_URL = "https://api.bscscan.com/api?module=gastracker&action=gasoracle&apikey=YourApiKeyToken"
  MAPITAAL_URL = "https://mapi.taal.com/mapi/feeQuote"
  
  def perform(*args)
    logger.debug "---> RUN CRON"
    coinCapResp = JSON.parse URI.open(COINCAP_URL).read
    btcFeeResp = JSON.parse URI.open(BLOCKCHAIN_INFO_URL).read
    ethGasResp = JSON.parse URI.open(ETHERSCAN_INFO_URL).read
    bscResp = JSON.parse URI.open(BSCSCAN_URL).read
    mapiTaalResp = JSON.parse URI.open(MAPITAAL_URL).read
    
    data = coinCapResp["data"]
    bscData = bscResp["result"]
    if data
      bitcoinData = data.select{|crypto| crypto["id"] == "bitcoin"}.try(:first)
      ethereumData = data.select{|crypto| crypto["id"] == "ethereum"}.try(:first)
      bitcoinSVData = data.select{|crypto| crypto["id"] == "bitcoin-sv"}.try(:first)
     
      logger.debug "#{bitcoinData.to_s}"
      logger.debug "#{ethereumData.to_s}"
      logger.debug "#{bitcoinSVData.to_s}"

      if bitcoinData
        btcRate = bitcoinData["priceUsd"].to_f
        btcTransFee = singleBTCTransaction(btcFeeResp, btcRate)
        logger.debug "btcTransFee #{btcTransFee}"
      end

      if ethereumData
        ethRate = ethereumData["priceUsd"].to_f
        ethTransFee = singleEthTransaction(ethGasResp, ethRate)
        logger.debug "ethTransFee #{ethTransFee}"
      end

      if bitcoinSVData
        bsvRate = bitcoinSVData["priceUsd"].to_f
        bsvTransFee = singleBSVTransaction(mapiTaalResp, bsvRate)
        logger.debug "bsvTransFee #{bsvTransFee}"
      end
    end

    if bscData
      bscFee = bscData["SafeGasPrice"].to_i
      bscRate = bscData["UsdPrice"].to_f
      bscTransFee = singleBCSTransaction(bscFee, bscRate)
      logger.debug "bscTransFee #{bscTransFee}"
    end
  end

  private
  
  def singleBTCTransaction(btcFeeResp, rate)
    fee = btcFeeResp["regular"]
    btcBsvFormula(fee, rate)
  end
  
  def singleBSVTransaction(btcFeeResp, rate)
    feeData = JSON.parse(btcFeeResp["payload"])["fees"].select{|gas| gas["feeType"] == "standard"}.try(:first)
    if feeData
      feePair = feeData["relayFee"]
      fee = feePair["satoshis"].to_f / feePair["bytes"].to_i
      btcBsvFormula(fee, rate)
    end
  end

  def singleEthTransaction(ethGasResp, rate)
    ethFee = ethGasResp["result"]["suggestBaseFee"].to_i
    bscEthFormula(ethFee, rate)
  end

  def singleBCSTransaction(bscFee, bscRate)
    bscEthFormula(bscFee, bscRate)
  end

  def bscEthFormula(fee, rate)
    if fee && rate
      21000 * fee * rate * 10**-9
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