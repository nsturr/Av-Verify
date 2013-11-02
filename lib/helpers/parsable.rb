module Parsable

  def self.included(base)
    base.extend(ParsableErrors)
  end

  module ParsableErrors
    def err_msg(message=nil)
      return @ERROR_MESSAGES.keys unless message
      raise ArgumentError.new "Error message #{message} not found" unless @ERROR_MESSAGES.key?(message)
      @ERROR_MESSAGES[message]
    end
  end

  attr_reader :errors

  Error = Struct.new(:line, :type, :context, :description)

  def err(line, context, description)
    error = Error.new(line, :error, context, description)
    @errors << error
  end

  # Returns a new Error struct, but only for non-critical errors
  def warn(line, context, description)
    error = Error.new(line, :warning, context, description)
    @errors << error
  end

  # Nothing creates these yet, so ignore
  def nb(line, context, description)
    error = Error.new(line, :nb, context, description)
    @errors << error
  end

  # The least important errors, primarily cosmetic things
  def ugly(line, context, description)
    error = Error.new(line, :ugly, context, description)
    @errors << error
  end

  def errors
    @errors || []
  end

  def valid?
    self.errors.any? { |error| error[:type] == :error }
  end

end
