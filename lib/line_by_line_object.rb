# A line by line object simply takes the contents of an entry and parses
# it line by line, comparing the structure of the current line to the
# structure of the expected line.

class LineByLineObject
  include Parsable
  include TheTroubleWithTildes

  def initialize(contents, line_number=1)
    @contents = contents.rstrip
    @line_number = line_number
    @expect = 0
  end

  def parse
    puts "#{@contents[/\A.*$/]} : #{@line_number}"
    line_type = self.class.LINES[@expect]
    self.send("parse_#{line_type}")
  end

end
