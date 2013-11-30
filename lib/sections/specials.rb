require_relative 'section'
require_relative '../helpers/avconstants'

class Specials < Section

  @section_delimiter = /^S/

  @ERROR_MESSAGES = {
    no_delimiter: "#SPECIALS section lacks terminating S",
    continues_after_delimiter: "#SPECIALS section continues after terminating S",
    duplicate_spec: "This will override mob's existing special: %s"
  }

  def child_class
    Special
  end

  def child_regex
    /\n/
  end

  def self.valid_special
    Proc.new do |special|
      line = special.lstrip
      skip_line = false
      skip_line = true if line.empty? || line.start_with?("*")

      !skip_line
    end
  end

  attr_reader :specials

  def initialize(contents, line_number=1)
    super(contents, line_number)
    @id = "specials"

    @children = []
    slice_first_line!
  end

  def to_s
    "#SPECIALS: #{self.specials.size} entries, line #{self.line_number}"
  end

  def include?(vnum)
    self.children.any? { |special| special.vnum == vnum }
  end

  def [](vnum)
    self.children.find { |special| special.vnum == vnum }
  end

  def each(&prc)
    self.children.each(&prc)
  end

  def length
    @specials.length
  end

  def size
    length
  end

  def parse
    @parsed = true

    split_children(Specials.valid_special)

    self.children.each do |special|
      special.parse
      vnum = special.vnum
      existing_entry = self[vnum]
      unless existing_entry.equal? special
        warn(special.line_number, special.line, Specials.err_msg(:duplicate_spec, self[vnum].spec))
      end
      @errors += special.errors
    end

    # TODO: should be able to dry up the code below. Into Section maybe?

    verify_delimiter
    # @current_line += 1
    # if @delimiter.nil?
    #   err(@current_line, nil, Specials.err_msg(:no_delimiter))
    # else
    #   unless @delimiter.rstrip =~ /#{Specials.delimiter(:start)}\z/
    #     line_num, bad_line = invalid_text_after_delimiter(@current_line, @delimiter)
    #     err(line_num, bad_line, Specials.err_msg(:continues_after_delimiter))
    #   end
    # end
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
    @parsed = true

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
