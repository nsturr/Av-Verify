require_relative 'section'
require_relative '../helpers/avconstants'

class Specials < Section

  @section_delimiter = "^S"

  @ERROR_MESSAGES = {
    no_delimiter: "#SPECIALS section lacks terminating S",
    continues_after_delimiter: "#SPECIALS section continues after terminating S",
    duplicate_spec: "This will override mob's existing special: %s"
  }

  def self.child_class
    Special
  end

  attr_reader :specials

  def initialize(contents, line_number=1)
    super(contents, line_number)
    @id = "specials"

    @raw_lines = []
    @specials = {}

    slice_first_line!
  end

  def has_children?
    true
  end

  def to_s
    "#SPECIALS: #{self.specials.size} entries, line #{self.line_number}"
  end

  def key?(vnum)
    @specials.key? vnum
  end

  def [](vnum)
    @specials[vnum]
  end

  def each(&prc)
    @specials.each_value(&prc)
  end

  def length
    @specials.length
  end

  def size
    length
  end

  def split_children
    @delimiter = slice_delimiter!

    @contents.each_line do |line|
      @current_line += 1
      next if line.strip.empty?
      next if line.strip.start_with? "*"
      @raw_lines << Special.new(line, @current_line)
    end
  end

  def parse
    super # set parsed to true
    # split_specials
    split_children

    @raw_lines.each do |special|
      special.parse
      vnum = special.vnum
      if @specials.key? vnum
        warn(special.line_number, special.line, Specials.err_msg(:duplicate_spec) % @specials[vnum].spec)
      end
      @specials[special.vnum] = special
      @errors += special.errors
    end

    # TODO: should be able to dry up the code below. Into Section maybe?

    @current_line += 1
    if @delimiter.nil?
      err(@current_line, nil, Specials.err_msg(:no_delimiter))
    else
      unless @delimiter.rstrip =~ /#{Specials.delimiter(:start)}\z/
        line_num, bad_line = invalid_text_after_delimiter(@current_line, @delimiter)
        err(line_num, bad_line, Specials.err_msg(:continues_after_delimiter))
      end
    end
    self.specials
  end

end

class Special
  include Parsable

  @ERROR_MESSAGES = {
    invalid_vnum: "Invalid mob vnum",
    negative_vnum: "Mob VNUM can't be negative",
    invalid_spec: "Invalid SPEC_FUN",
    unknown_spec: "Unknown SPEC_FUN",
    not_enough_tokens: "Not enough tokens in special line",
    invalid_line: "Invalid special line"
  }

  attr_reader :line, :line_number, :vnum, :spec, :errors

  def initialize(line, line_number=1)
    @line = line
    @line_number = line_number
    @errors = []
  end

  def to_s
    "<Special: vnum #{self.vnum}, #{self.spec}>"
  end

  def parse
    super # set parsed to true

    if self.line.start_with? "M\s"

      vnum, spec = self.line.split(" ", 4)[1..2] # Drop the comment at the end
      unless [vnum, spec].any? { |el| el.nil? }
        if vnum =~ /^-?\d+$/
          @vnum = vnum.to_i
          err(self.line_number, self.line, Special.err_msg(:negative_vnum)) if @vnum < 0
        else
          err(self.line_number, self.line, Special.err_msg(:invalid_vnum))
        end

        # include potential comments starting with * smooshed up against the spec
        if spec =~ /^\w+(?:\*.*|$)/
          @spec = spec[/^[^\*]*/].downcase
          err(self.line_number, self.line, Special.err_msg(:unknown_spec)) unless SPECIALS.include? @spec
        else
          err(self.line_number, self.line, Special.err_msg(:invalid_spec))
        end
      else
        err(self.line_number, self.line, Special.err_msg(:not_enough_tokens))
      end
    else
      err(self.line_number, self.line, Special.err_msg(:invalid_line))
    end
    self
  end

end
