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

  LINES = [:vnum, :name, :short_desc, :long_desc, :description, :act, :aff,
    :align, :level, :sex, :race, :klass, :apply, :team, :kspawn]

  def self.LINES
    LINES
  end

  attr_reader(:line_number, *LINES)

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
    if line.empty?
      err(@current_line, nil, "Invalid blank line in mob keywords")
      @current_line += 1
    else
      if has_tilde? line
        err(@current_line, line, tilde(:extra_text, "Mob name")) unless trailing_tilde? line
      else
        err(@current_line, line, tilde(:absent_or_spans, "Mob name"))
      end
      @name = line[/\A[^~]*/].split
    end
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
    end
    if trailing_tilde? line
      ugly(@current_line, line, tilde(:not_alone)) unless isolated_tilde? line
    end
    @expectation = :act_aff_align if has_tilde? line
  end

  def parse_act_aff_align line

    @expectation = :level
  end

  def parse_level line

    @expectation = :constant
  end

  def parse_constant line

    @expectation = :sex
  end

  def parse_sex line

    @expectation = :misc
  end

  def parse_misc line

  end

  def parse_kspawn line

  end

end
