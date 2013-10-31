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

  def slice_first_line
    @contents.slice!(/\A.*(?:\n|\Z)/)
  end

  def slice_delimeter(delim)
    @contents.slice!(/^#{delim}.*\z/m)
  end

end
