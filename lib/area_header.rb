require_relative 'parsable.rb'

class AreaHeader
  include Parsable

  def initialize contents, line_number
    @line_number = line_number
    @contents = contents.rstrip
  end

  def parse
    @errors = []
    bracket_open = @contents.index("{")
    bracket_close = @contents.index("}")

    # Check the proper dimensions of the {LvlRng} section
    if bracket_open && bracket_close
      warn(@line_num, @contents, "Level range should be 8 chars long, including braces") if bracket_close - bracket_open != 7
    else
      warn(@line_num, @contents, "Level range not enclosed in braces { }")
    end

    if @contents.include? "\n"
      err(@line_num, @contents, "#AREA section spans more than one line")
    end
    if @contents.count("~") > 1
      err(@line_num, @contents, "#AREA section contains more than one ~")
    elsif @contents.count("~") == 0
      err(@line_num, @contents, "#AREA section contains no ~")
    end

    self
  end

end
