
class PullCryptoInfoJob < ApplicationJob
  queue_as :default

  def perform(*args)
    logger.debug "----> CRON"
  end
end