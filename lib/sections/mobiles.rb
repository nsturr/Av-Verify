require_relative "vnum_section"
require_relative "line_by_line_object"

require_relative "../helpers/tilde"
require_relative "../helpers/has_apply_flag"
require_relative "../helpers/has_quoted_keywords"
require_relative "../helpers/bits"

class Mobiles < VnumSection

  @section_delimiter = /^#0\b/ # N.B. some valid vnums regrettably begin with a 0

  def child_class
    Mobile
  end

  def initialize(contents, line_number=1)
    super(contents, line_number)
    @id = "mobiles"
  end

  def to_s
    "#MOBILES: #{self.mobiles.size} entries, line #{self.line_number}"
  end

  def mobiles
    @entries
  end

end

class Mobile < LineByLineObject
  include HasApplyFlag
  include HasQuotedKeywords

  @ERROR_MESSAGES = {
    visible_tab: "Visible text contains a tab character",
    invalid_text_after: "Invalid text after %s",
    short_desc_spans: "Mob short desc spans multiple lines",
    long_desc_spans: "Long desc has more than one line of text",
    description_no_tilde: "This doesn't look like part of a description. Forget a terminating ~ above?",
    no_terminating: "Line lacks terminating %s",
    act_not_npc: "ACT_NPC is not set",
    bad_bit: "%s flag is not a power of 2",
    bad_field: "Bad %s field",
    bad_align_range: "Alignment out of bounds -1000 to 1000",
    act_aff_align_matches: "Line should read: <act> <aff> <align> S",
    level_matches: "Line should follow syntax: <level:#> 0 0",
    constant_matches: "Line should read: 0d0+0 0d0+0 0 0",
    bad_sex_range: "Sex out of bounds 0 to 2",
    sex_matches: "Line should read: 0 0 <sex:#>",
    race_duplicated: "Mob's race already defined",
    race_out_of_bounds: "Mob race out of bounds 0 to #{RACE_MAX}",
    class_duplicated: "Mob's class already defined",
    non_numeric: "Invalid (non-numeric) %s field",
    class_out_of_bounds: "Mob class out of bounds 0 to #{CLASS_MAX}",
    team_duplicated: "Mob's team already defined",
    team_out_of_bounds: "Mob team out of bounds 0 to #{TEAM_MAX}",
    kspawn_duplicated: "Mob's kspawn already defined",
    kspawn_no_tilde: "Killspawn lacks terminating ~ between lines %s and %s",
    non_numeric_or_neg: "Invalid (negative or non-numeric) %s",
    invalid_extra_field: "Invalid extra field (expecting R, C, L, A, or K)",
    not_enough_tokens: "Not enough tokens in kspawn line"
  }

  ATTRIBUTES = [:vnum, :name, :short_desc, :long_desc, :description, :act, :aff,
    :align, :level, :sex, :race, :klass, :apply, :team, :kspawn]

  attr_reader(:line_number, *ATTRIBUTES)

  def initialize(contents, line_number=1)
    super(contents, line_number)
    @long_line = 0 # For determining how many lines the long_desc spans

    # Need the following instantiated as we'll be adding to them later
    @long_desc = ""
    @description = ""
    @apply = Hash.new(0)
  end

  def to_s
    "<Mobile: vnum #{self.vnum}, #{self.short_desc}, line #{self.line_number}>"
  end

  def parse
    super
    if @expectation == :multiline_kspawn
      err(@current_line, nil, Mobile.err_msg(:kspawn_no_tilde) % [@last_multiline, @current_line])
    end
    self
  end

  def parse_vnum line
    m = line.match(/#(?<vnum>\d+)/)
    # To even be created, a Mobile needs to have a valid vnum
    @vnum = m[:vnum].to_i
    expect :name
  end

  def parse_name line
    return if invalid_blank_line? line
    validate_tilde(
      line: line,
      line_number: @current_line,
      might_span_lines: true
      )

    @name = parse_quoted_keywords(line[/\A[^~]*/], line, true, "mob")
    expect :short_desc
  end

  def parse_short_desc line
    if line.empty?
      err(@current_line, nil, Mobile.err_msg(:short_desc_spans))
    else
      ugly(@current_line, line, Mobile.err_msg(:visible_tab)) if line.include?("\t")
      validate_tilde(
        line: line,
        line_number: @current_line,
        might_span_lines: true
      )
      @short_desc = line[/\A[^~]*/]
      expect :long_desc
    end
  end

  def parse_long_desc line
    ugly(@current_line, line, Mobile.err_msg(:visible_tab)) if line.include?("\t")
    @long_line += 1

    @long_desc << line << "\n"

    if has_tilde? line
      expect :description
      validate_tilde(
        line: line,
        line_number: @current_line,
        should_be_alone: true
      )
    elsif @long_line == 2
      ugly(@current_line, line, Mobile.err_msg(:long_desc_spans))
    end
  end

  def parse_description line
    ugly(@current_line, line, Mobile.err_msg(:visible_tab)) if line.include?("\t")
    # Firstly, try to match the <act> <aff> <align> S line
    # If it matches exactly, it's a safe bet that the description section lacks a
    # ~ and we just bled into it.
    if line =~ /^#{Bits.insert} +#{Bits.insert} +-?\d+ +S/
      err(@current_line, line, Mobile.err_msg(:description_no_tilde))
      # Set code block to expect the next line (which is the line we just found)
      # and redo the block on the current line
      expect :act_aff_align
      return :redo
    else
      @description << line << "\n"
    end
    if has_tilde? line
      expect :act_aff_align
      validate_tilde(
        line: line,
        line_number: @current_line,
        should_be_alone: true
      )
    end
  end

  def parse_act_aff_align line
    return if invalid_blank_line? line

    # TODO: handle an S smooshed up against align.
    # this method might let ' act aff 1000S S  ' with an extra S pass

    err(@current_line, line, Mobile.err_msg(:no_terminating) % "S") unless line.end_with?("S")
    items = line.split
    if items.length >= 3
      if items[0] =~ Bits.pattern
        @act = Bits.new(items[0])
        warn(@current_line, line, Mobile.err_msg(:act_not_npc)) unless @act.bit? 1
        err(@current_line, line, Mobile.err_msg(:bad_bit) % "Act") if @act.error?
      else
        err(@current_line, line, Mobile.err_msg(:bad_field) % "act flags")
      end
      if items[1] =~ Bits.pattern
        @aff = Bits.new(items[1])
        err(@current_line, line, Mobile.err_msg(:bad_bit) % "Affect") if @aff.error?
      else
        err(@current_line, line, Mobile.err_msg(:bad_field) % "affect flags")
      end
      if m = items[2].match(/(-?\d+(?:\b|S))/)
        @align = m[1].to_i
        err(@current_line, line, Mobile.err_msg(:bad_align_range)) unless @align.between?(-1000, 1000)
      else
        err(@current_line, line, Mobile.err_msg(:bad_field) % "align")
      end
    else
      err(@current_line, line, Mobile.err_msg(:act_aff_align_matches))
    end

    expect :level
  end

  def parse_level line
    return if invalid_blank_line? line
    if m = line.match(/^(\d+) +\d+ +\d+$/)
      @level = m[1].to_i
    else
      unless line =~ /^\d+\b/
        err(@current_line, line, Mobile.err_msg(:bad_field) % "level")
      else
        err(@current_line, line, Mobile.err_msg(:level_matches))
      end
    end
    expect :constant
  end

  def parse_constant line
    return if invalid_blank_line? line
    # Technically the line doesn't have to read 0d0+0 0d0+0 0 0, any numbers
    # will do, though they have no effect.
    unless line =~ /^\d+d\d+\+\d+ +\d+d\d+\+\d+ +\d+ +\d+$/i
      err(@current_line, line, Mobile.err_msg(:constant_matches))
    end
    expect :sex
  end

  def parse_sex line
    return if invalid_blank_line? line
    if m = line.match(/^\d+ +\d+ +(\d+)$/)
      @sex = m[1].to_i
      err(@current_line, line, Mobile.err_msg(:bad_sex_range)) unless @sex.between?(0,SEX_MAX)
    else
      err(@current_line, line, Mobile.err_msg(:sex_matches))
    end
    expect :misc
  end

  # This method parses Race, Class, Team, Apply, and Kspawn lines, as
  # they can occur in any order (for kspawn, it hands off to another method)
  def parse_misc line
    return if invalid_blank_line? line

    case line.lstrip[0]
    when "R"
      err(@current_line, line, Mobile.err_msg(:race_duplicated)) && return if self.race
      race, error = line.split[1..-1]
      if race =~ /\A\d+\z/
        @race = race.to_i
        err(@current_line, line, Mobile.err_msg(:race_out_of_bounds)) unless @race.between?(0, RACE_MAX)
      else
        err(@current_line, line, Mobile.err_msg(:non_numeric) % "race")
      end
      err(@current_line, line, Mobile.err_msg(:invalid_text_after) % "race") unless error.nil?

    when"C"
      err(@current_line, line, Mobile.err_msg(:class_duplicated)) && return if self.klass
      klass, error = line.split[1..-1]
      if klass =~ /\A\d+\z/
        @klass = klass.to_i
        err(@current_line, line, Mobile.err_msg(:class_out_of_bounds)) unless @klass.between?(0, CLASS_MAX)
      else
        err(@current_line, line, Mobile.err_msg(:non_numeric) % "class")
      end
      err(@current_line, line, Mobile.err_msg(:invalid_text_after) % "class") unless error.nil?

    when "L"
      err(@current_line, line, Mobile.err_msg(:team_duplicated)) && return if self.team
      team, error = line.split[1..-1]
      if team =~ /\A\d+\z/
        @team = team.to_i
        err(@current_line, line, Mobile.err_msg(:team_out_of_bounds)) unless @team.between?(0, TEAM_MAX)
      else
        err(@current_line, line, Mobile.err_msg(:non_numeric) % "team")
      end
      err(@current_line, line, Mobile.err_msg(:invalid_text_after) % "team") unless error.nil?

    when "A"
      # see HasApplyFlag module for this
      apply_key, apply_value = parse_apply_flag(line, @current_line)
      unless apply_key.nil?
        @apply[apply_key] += apply_value
      end

    when "K"
      err(@current_line, line, Mobile.err_msg(:kspawn_duplicated)) && return if self.kspawn
      @last_multiline = @current_line
      # Split line into: K condition type spawn mob text...
      # Also toss out the leading 'K'

      # TODO: Fix tildes being smooshed up against room vnum (it's valid,
      # but throws an error)
      condition, type, spawn, room, text = line.split(" ", 6)[1..-1]
      @kspawn = {
        condition: condition,
        type: Bits.new(type),
        spawn: spawn,
        room: room,
        text: text || ""
      }

      if [condition, type, spawn, room].any? { |el| el.nil? }
        err(@current_line, line, Mobile.err_msg(:not_enough_tokens))
      else
        unless self.kspawn[:condition] =~ /^\d+$/
          err(@current_line, line, Mobile.err_msg(:non_numeric_or_neg) % "kspawn condition")
        end

        if self.kspawn[:type].error?
          err(@current_line, line, Mobile.err_msg(:bad_bit) % "Kspawn type")
        end

        unless self.kspawn[:spawn] =~ /^-1$|^\d+$/
          err(@current_line, line, Mobile.err_msg(:non_numeric) % "kspawn vnum")
        end

        unless self.kspawn[:room] =~ /^-1$|^\d+$/
          err(@current_line, line, Mobile.err_msg(:non_numeric_or_neg) % "kspawn location")
        end
      end

      # The line's last field is text with can span multiple lines. If there's no tilde,
      # expect the next line to just be more text that can be ignored until a tilde
      # is found.
      expect :multiline_kspawn unless line.end_with?("~")
    else
      err(@current_line, line, Mobile.err_msg(:invalid_extra_field))
    end

  end

  def parse_multiline_kspawn line
    self.kspawn[:text] << "\n" + line
    ugly(@current_line, line, Mobile.err_msg(:visible_tab)) if line.include?("\t")
    # This type is only ever expected if a killspawn text field spans multiple lines
    if has_tilde?(line)
      validate_tilde(line: line, line_number: @current_line, present: false)
      expect :misc
    end
  end

end
