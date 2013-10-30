require_relative 'parsable.rb'

class Section
  include Parsable

  def initialize(contents, line_number=1)
    @line_number = line_number
    @current_line = line_number
    @contents = contents
    @errors = []
  end

end
