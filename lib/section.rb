require_relative 'modules/parsable.rb'

class Section
  include Parsable

  attr_reader :line_number, :name

  def initialize(contents, line_number=1)
    @line_number = line_number
    @current_line = line_number
    @contents = contents.rstrip
    @errors = []
  end

  def parse
    puts "#{self.class} doesn't implement a parse method. Notify your nearest Scevine immediately."
  end

  def slice_first_line
    @contents.slice!(/\A.*(?:\n|\Z)/)
  end

  def slice_delimeter(delim)
    @contents.slice!(/^#{delim}.*\z/m)
  end

  # returns an array of offending line and line number
  def invalid_text_after_delimeter(line_number, text, delim)
    unless text =~ /#{delim}\s*?$/
      offending_text = text[/\A.*$/]
    else
      offending_text = text.rstrip
      # This slices off the delimeter line, leaving the \n at the end, which is good
      offending_text.slice!(/#{delim}.*$/)
      # This finds up to the first line with non-whitespace on it
      offending_text = offending_text[/\A.*?\S[^\n]*$/m]
      line_number += offending_text.count("\n")
      offending_text.lstrip!
    end
    return [line_number, offending_text]
  end

end
