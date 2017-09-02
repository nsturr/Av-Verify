require_relative "avcolors"

module Parsable

  def self.included(base)
    base.extend(ParsableErrors)
  end

  module ParsableErrors
    def err_msg(message, *vars)
      unless @ERROR_MESSAGES
        # Propogate up hierarchy if one class doesn't have its own error messages
        superclass.err_msg(message, *vars)
      else
        raise ArgumentError.new "Error message #{message} not found" unless @ERROR_MESSAGES.key?(message)
        @ERROR_MESSAGES[message] % vars
      end
    end
  end

  attr_accessor :errors

  def parsed?
    @parsed || false
  end

  # have to use @errors rather than self.errors for the next few methods,
  # on account that Area#errors (possibly more in the future) is actually
  # a computed value, and doesn't read straight from @errors

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

  def valid?
    self.errors.none? { |error| error.type == :error }
  end

  def error_report(nocolor=false)
    error_list = self.errors
    unless error_list.empty?
      nocolor = @flags ? @flags.include?(:nocolor) : nocolor

      errors, warnings, notices, cosmetic = 0, 0, 0, 0
      error_list.each do |item|
        errors += 1 if item.type == :error
        warnings += 1 if item.type == :warning
        notices += 1 if item.type == :nb
        cosmetic += 1 if item.type == :ugly
      end

      text_intro = errors > 0 ? "Someone's been a NAUGHTY builder!" : "Error report:"
      text_error = errors == 1 ? "1 error" : "#{errors} errors"
      text_warning = warnings == 1 ? "1 warning" : "#{warnings} warnings"
      text_cosmetic = cosmetic == 1 ? "1 cosmetic issue" : "#{cosmetic} cosmetic issues"
      text_notice = notices == 1 ? "1 notice" : "#{notices} notices"

      unless nocolor
        text_error.BR!
        text_warning.R!
        text_cosmetic.C!
        text_notice.Y!
      end

      summary = "#{text_intro} #{text_error}, #{text_warning}."
      if cosmetic > 0
        summary.chop!
        summary << ", #{text_cosmetic}."
      end
      if notices > 0
        summary.chop!
        summary << ", #{text_notice}."
      end
      puts summary

      suppressed = 0
      error_list.each do |error|
        if error.type == :error
          puts error.to_s(nocolor)
        elsif error.type == :warning
          puts error.to_s(nocolor)
        elsif error.type == :nb
          puts error.to_s(nocolor)
        elsif error.type == :ugly
          puts error.to_s(nocolor)
        else
          suppressed += 1
        end
      end
      puts "Suppressed #{suppressed} items." if suppressed > 0
    else
      puts "Nothing found to report."
    end
  end

  class Error
    attr_accessor :line, :type, :context, :description

    # The CC! method takes a symbol to to determine its color.
    # Maps color to error type.
    COLOR = {
      warning: :R,
      error: :BR,
      nb: :Y,
      ugly: :C
    }

    TYPES = {
      warning: "Warning",
      error: "Error",
      nb: "Notice",
      ugly: "Cosmetic issue"
    }

    def initialize(line, type, context, description)
      @line, @type, @context, @description = line, type, context, description
    end

    def to_s(nocolor=false)
      # Error reports will look like this by default:
      # Line NNNN: Description of error
      # --> The offending line [only displayed if error[:context] is not nil]

      text_line = "#{TYPES[self.type]} on line #{self.line}:"
      text_indent = "-->"
      unless nocolor
        text_line.CC!(COLOR[self.type])
        text_indent.CC!(COLOR[self.type])
      end
      formatted = "#{text_line} #{self.description}\n"
      formatted += "#{text_indent} #{self.context}\n" unless self.context.nil?
      formatted + "\n"
    end
  end

end
