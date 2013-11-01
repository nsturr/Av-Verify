require_relative "vnum_section.rb"
require_relative "modules/tilde.rb"
require_relative "line_by_line_object.rb"
require_relative "bits.rb"

class Mobiles < VnumSection

  @section_delimeter = "^#0\\b" # N.B. some valid vnums regrettably begin with a 0

  def self.child_class
    Mobile
  end

  def initialize(contents, line_number)
    super(contents, line_number)
    @name = "MOBILES"
  end

end

class Mobile < LineByLineObject

  ATTRIBUTES = [:vnum, :name, :short_desc, :long_desc, :description, :act, :aff,
    :align, :level, :sex, :race, :klass, :apply, :team, :kspawn]

  attr_reader(:line_number, *ATTRIBUTES)

  def initialize(contents, line_number=1)
    super(contents, line_number)
    @long_line = 0 # For determining how many lines the long_desc spans
  end

  def parse_vnum line
    m = line.match(/#(?<vnum>\d+)/)
    if m
      @vnum = m[:vnum].to_i
      err(@current_line, line, "Invalid text before VNUM") if m.pre_match =~ /\S/
      err(@current_line, line, "Invalid text after VNUM") if m.post_match =~ /\S/
    else
      err(@current_line, line, "Invalid VNUM line")
    end
    @expectation = :name
  end

  def parse_name line
    return if invalid_blank_line? line
    if has_tilde? line
      err(@current_line, line, tilde(:extra_text, "Mob name")) unless trailing_tilde? line
    else
      err(@current_line, line, tilde(:absent_or_spans, "Mob name"))
    end
    @name = line[/\A[^~]*/].split
    @expectation = :short_desc
  end

  def parse_short_desc line
    if line.empty?
      err(@current_line, nil, "Mobile short desc spans multiple lines")
    else
      ugly(@current_line, line, "Visible text contains a tab character") if line.include?("\t")
      if has_tilde? line
        err(@current_line, line, tilde(:extra_text, "Short desc")) unless trailing_tilde? line
      else
        err(@current_line, line, tilde(:absent_or_spans, "Short desc"))
      end
      @short_desc = line[/\A[^~]*/]
      @expectation = :long_desc
    end
  end

  def parse_long_desc line
    ugly(@current_line, line, "Visible text contains a tab character") if line.include?("\t")
    @long_line += 1

    @long_desc ||= ""
    @long_desc << line

    if has_tilde? line
      @expectation = :description
      if line =~ /~./
        err(@current_line, line, "Invalid text after terminating ~")
      elsif line.length > 1
        ugly(@current_line, line, "Terminating ~ should be on its own line")
      end
    elsif @long_line == 2
      ugly(@current_line, line, "Long desc has more than one line of text")
    end
  end

  def parse_description line
    ugly(@current_line, line, "Visible text contains a tab character") if line.include?("\t")
    # Firstly, try to match the <act> <aff> <align> S line
    # If it matches exactly, it's a safe bet that the description section lacks a
    # ~ and we just bled into it.
    if line =~ /^#{Bits.insert} +#{Bits.insert} +-?\d+ +S/
      err(@current_line, line, "This doesn't look like part of a description. Forget a terminating ~ above?")
      # Set code block to expect the next line (which is the line we just found)
      # and redo the block on the current line
      @expectation = :act_aff_align
      return :redo
    else
      @description ||= ""
      @description << line
    end
    if has_tilde? line
      @expectation = :act_aff_align
      if trailing_tilde? line
        ugly(@current_line, line, tilde(:not_alone)) unless isolated_tilde? line
      else
        err(@current_line, line, tilde(:extra_text, "Description"))
      end
    end
  end

  def parse_act_aff_align line
    return if invalid_blank_line? line

    err(@current_line, line, "Line lacks terminating S") unless line.end_with?("S")
    items = line.split
    if items.length == 4
      if items[0] =~ Bits.pattern
        @act = Bits.new(items[0])
        warn(@current_line, line, "ACT_NPC is not set") unless @act.bit? 1
        err(@current_line, line, "Act flag is not a power of 2") if @act.error?
      else
        err(@current_line, line, "Bad act flags")
      end
      if items[1] =~ Bits.pattern
        @aff = Bits.new(items[1])
        err(@current_line, line, "Affect flag is not a power of 2") if @aff.error?
      else
        err(@current_line, line, "Bad affect flags")
      end
      if m = items[2].match(/(-?\d+\b)/)
        @align = m[1].to_i
        err(@current_line, line, "Alignment out of bounds -1000 to 1000") unless @align.between?(-1000, 1000)
      else
        err(@current_line, line, "Bad alignment")
      end
    else
      err(@current_line, line, "Line should read: <act> <aff> <align> S")
    end

    @expectation = :level
  end

  def parse_level line
    return if invalid_blank_line? line
    if m = line.match(/^(\d+) +\d+ +\d+$/)
      @level = m[1].to_i
    else
      unless line =~ /^\d+\b/
        err(@current_line, line, "Bad \"level\" field")
      else
        err(@current_line, line, "Line should follow syntax: <level:#> 0 0")
      end
    end
    @expectation = :constant
  end

  def parse_constant line
    return if invalid_blank_line? line
    # Technically the line doesn't have to read 0d0+0 0d0+0 0 0, any numbers
    # will do, though they have no effect.
    unless line =~ /^\d+d\d+\+\d+ +\d+d\d+\+\d+ +\d+ +\d+$/i
      err(@current_line, line, "Line should read: 0d0+0 0d0+0 0 0")
    end
    @expectation = :sex
  end

  def parse_sex line
    return if invalid_blank_line? line
    if m = line.match(/^\d+ +\d+ +(\d+)$/)
      @sex = m[1].to_i
      err(@current_line, line, "Sex out of bounds 0 to 2") unless @sex.between?(0,SEX_MAX)
    else
      err(@current_line, line, "Line should follow syntax: 0 0 <sex:#>")
    end
    @expectation = :misc
  end

  def parse_misc line

  end

  def parse_kspawn line

  end

end
