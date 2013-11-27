require_relative 'section'

class AreaHeader < Section

  @ERROR_MESSAGES = {
    bad_range: "Level range should be 8 chars long, including braces",
    no_braces: "Level range not enclosed in braces { }",
    multi_line: "#AREA section spans more than one line",
    # extra_tilde: "#AREA section contains more than one ~",
    # missing_tilde: "#AREA section contains no ~"
  }

  attr_reader :name, :level, :author

  def initialize(contents, line_number=1)
    super(contents, line_number)
    @id = "area"
  end

  def parse
    super # set parsed to true

    @errors = []
    bracket_open = @contents.index("{")
    bracket_close = @contents.index("}")

    # Check the proper dimensions of the {LvlRng} section
    if bracket_open && bracket_close
      @level = @contents[bracket_open+1...bracket_close] # strip off the braces now
      warn(@line_number, @contents, AreaHeader.err_msg(:bad_range)) if @level.length != 6
    else
      warn(@line_number, @contents, AreaHeader.err_msg(:no_braces))
    end

    if bracket_close
      byline = @contents[bracket_close+1..-1]
      @author, @name = byline[/^[^~\n]*/].split(" ", 2)
    end

    if @contents.include? "\n"
      err(@line_number, @contents, AreaHeader.err_msg(:multi_line))
    end

    validate_tilde(line: @contents, line_number: line_number)
    # if @contents.count("~") > 1
    #   err(@line_number, @contents, TheTroubleWithTildes.err_msg(:extra))
    # elsif @contents.count("~") == 0
    #   err(@line_number, @contents, TheTroubleWithTildes.err_msg(:absent))
    # end

    self
  end

  def to_hash
    {name: self.name, author: self.author, level: self.level}
  end

end
