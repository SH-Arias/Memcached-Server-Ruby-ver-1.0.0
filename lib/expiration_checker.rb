# This functions allow some handler functions to check for expiration of keys
module ExpireHelper

    def self.check_if_expired(data, data_expiration, key)
      key_expiration = data_expiration[key]
      if key_expiration && key_expiration < Time.now.to_f * 1000
        logger.debug "purging #{ key }"
        data.delete(key)
        data_expiration.delete(key)
      end
    end
  
    def self.logger
      @logger ||= Logger.new(STDOUT).tap do |l|
        l.level = LOG_LEVEL
      end
    end
  end