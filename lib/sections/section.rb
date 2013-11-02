require_relative '../helpers/parsable'

class Section
  include Parsable

  attr_reader :line_number, :id

  def self.err_msg(message=nil)
    return @ERROR_MESSAGES.keys unless message
    raise ArgumentError.new "Error message #{message} not found" unless @ERROR_MESSAGES.key?(message)
    @ERROR_MESSAGES[message]
  end

  def self.delimeter(*options)
    if @section_delimeter
      delim = @section_delimeter
      delim.prepend("\\A") if options.include? :start
      options.include?(:string) ? delim : /#{delim}/
    end
  end

  def initialize(contents, line_number=1)
    @line_number = line_number
    @current_line = line_number
    @contents = contents.rstrip
    @errors = []
  end

  def slice_first_line
    @contents.slice!(/\A.*(?:\n|\Z)/)
  end

  def slice_delimeter
    @contents.slice!(/^#{self.class.delimeter}.*\z/m)
  end

  # returns an array of offending line and line number
  def invalid_text_after_delimeter(line_number, text)
    unless text =~ /#{self.class.delimeter(:string)}\s*?$/
      offending_text = text[/\A.*$/]
    else
      offending_text = text.rstrip
      # This slices off the delimeter line, leaving the \n at the end, which is good
      offending_text.slice!(/#{self.class.delimeter(:string)}.*$/)
      # This finds up to the first line with non-whitespace on it
      offending_text = offending_text[/\A.*?\S[^\n]*$/m]
      line_number += offending_text.count("\n")
      offending_text.lstrip!
    end
    return [line_number, offending_text]
  end

end
