# A line by line object simply takes the contents of an entry and parses
# it line by line, comparing the structure of the current line to the
# structure of the expected line.

class LineByLineObject
  include Parsable
  include TheTroubleWithTildes

  def initialize(contents, line_number=1)
    @contents = contents.rstrip
    @line_number = line_number
    @current_line = line_number
    @errors = []
    @expectation = :vnum
  end

  def parse
    @contents.each_line do |line|
      result = self.send("parse_#{@expectation}", line.rstrip)
      redo if result == :redo # If we discovered it's probably a different line type
      @current_line += 1
    end
  end

  def invalid_blank_line? line
    if line.empty?
      err(@current_line, nil, "Invalid blank line in #{self.class.name} definition")
      return true
    end
    false
  end

end
