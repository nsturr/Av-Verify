require './sections/section'

class Specials < Section

  @section_delimeter = "^S"

  attr_reader :specials, :line_number, :errors

  def initialize(contents, line_number=1)
    super(contents, line_number)
    @name = "SPECIALS"

    @specials = []

    slice_first_line
    split_specials
  end

  def split_specials
    @delimeter = slice_delimeter

    @contents.each_line do |line|
      @current_line += 1
      next if line.strip.empty?
      next if line.strip.start_with? "*"
      @specials << Special.new(line, @current_line)
    end
  end

  def parse

    @specials.each do |special|
      special.parse
      @errors += special.errors
    end

    # warn(current_line, line, "This will override mob's existing special: #{@specials[mob_vnum]}") if @specials.key? mob_vnum

    # TODO: should be able to dry up the code below. Into Section maybe?

    @current_line += 1
    if @delimeter.nil?
      err(@current_line, nil, "#SPECIALS section lacks terminating 0$~")
    else
      unless @delimeter.rstrip =~ /#{Specials.delimeter(:start)}\z/
        line_num, bad_line = invalid_text_after_delimeter(@current_line, @delimeter)
        err(line_num, bad_line, "#SPECIALS section continues after terminating S")
      end
    end

  end

end

class Special
  include Parsable

  attr_reader :line, :line_number, :vnum, :spec, :errors

  def initialize(line, line_number=1)
    @line = line
    @line_number = line_number
    @errors = []
  end

  def parse

    if self.line.start_with? "M\s"

      vnum, spec = self.line.split(" ", 4)[1..2] # Drop the comment at the end
      unless [vnum, spec].any? { |el| el.nil? }
        if vnum =~ /^\d+$/
          @vnum = vnum.to_i
          err(self.line_number, self.line, "Mob VNUM can't be negative") if @vnum < 0
        else
          err(self.line_number, self.line, "Invalid mob vnum")
        end

        # include potential comments starting with * smooshed up against the spec
        if spec =~ /^\w+(?:\*.*|$)/
          @spec = spec[/^[^\*]*/].downcase
          err(self.line_number, self.line, "Unknown SPEC_FUN") unless SPECIALS.include? @spec
        else
          err(self.line_number, self.line, "Invalid SPEC_FUN")
        end
      else
        err(self.line_number, self.line, "Not enough tokens in special line")
      end
    else
      err(self.line_number, self.line, "Invalid special line")
    end

  end

end
