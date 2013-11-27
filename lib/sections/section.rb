require_relative '../helpers/parsable'
require_relative '../helpers/tilde'

class Section
  include Parsable
  include TheTroubleWithTildes

  attr_reader :line_number, :id, :contents

  def self.delimiter(*options)
    if @section_delimiter
      delim = @section_delimiter.dup
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

  def parse
    super
  end

  def slice_first_line!
    @contents.slice!(/\A.*(?:\n|\Z)/)
  end

  def slice_leading_whitespace!
    blank_lines = @contents.slice!(/\A\s*/m)
    @current_line += blank_lines.count("\n")
  end

  def slice_delimiter!
    @contents.slice!(/^#{self.class.delimiter}.*\z/m)
  end

  # returns an array of offending line and line number
  def invalid_text_after_delimiter(line_number, text)
    unless text =~ /#{self.class.delimiter(:string)}\s*?$/
      offending_text = text[/\A.*$/]
    else
      offending_text = text.rstrip
      # This slices off the delimiter line, leaving the \n at the end, which is good
      offending_text.slice!(/#{self.class.delimiter(:string)}.*$/)
      # This finds up to the first line with non-whitespace on it
      offending_text = offending_text[/\A.*?\S[^\n]*$/m]
      line_number += offending_text.count("\n")
      offending_text.lstrip!
    end
    return [line_number, offending_text]
  end

end
