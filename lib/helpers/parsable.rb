require_relative "avcolors"

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
    self.errors.none? { |error| error.type == :error }
  end

  class Error
    attr_accessor :line, :type, :context, :description

    COLOR = {
      warning: :R,
      error: :BR,
      nb: :Y,
      ugly: :CC
    }

    def initialize(line, type, context, description)
      @line, @type, @context, @description = line, type, context, description
    end

    def to_pretty
      to_s(true)
    end

    def to_s(color=false)
      # Error reports will look like this by default:
      # Line NNNN: Description of error
      # --> The offending line [only displayed if error[:context] is not nil]

      text_line = "Line #{self.line}:"
      text_indent = "-->"
      if color
        text_line.CC!(COLOR[self.type])
        text_indent.CC!(COLOR[self.type])
      end
      formatted = "#{text_line} #{self.description}\n"
      formatted += "#{text_indent} #{self.context}\n" unless self.context.nil?
      formatted + "\n"
    end
  end

end
