class MultiLogger
  def initialize(*loggers)
    @loggers = loggers
  end

  def method_missing(method, *args, &block)
    @loggers.each do |logger|
      logger.send(method, *args, &block) if logger.respond_to?(method)
    end
  end

  def respond_to_missing?(method, include_private = false)
    @loggers.any? { |logger| logger.respond_to?(method, include_private) }
  end

  def write(message)
    @loggers.each { |logger| logger.write(message) if logger.respond_to?(:write) }
  end

  def close
    @loggers.each { |logger| logger.close if logger.respond_to?(:close) }
  end

  def level=(level)
    @loggers.each { |logger| logger.level = level }
  end

  def level
    @loggers.first&.level
  end

  def formatter=(formatter)
    @loggers.each { |logger| logger.formatter = formatter }
  end

  def formatter
    @loggers.first&.formatter
  end
end