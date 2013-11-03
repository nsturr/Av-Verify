require_relative 'section'
require_relative '../helpers/avconstants'
require_relative '../helpers/bits'

class AreaData < Section

  @ERROR_MESSAGES = {
    invalid_line: "Invalid AREADATA line, expected P, F, O, K, M, G, S",
    continues_after_delimiter: "Section continues after 'S' delimiter",
    no_delimiter: "#AREADATA lacks terminating S",
    duplicate: "Duplicate '%s' line in #AREADATA",
    invalid_extra_text: "Invalid text after #AREADATA %s",
    invalid_plane_0: "Invalid area plane: 0",
    invalid_field: "Invalid (non-numeric) %s field",
    plane_out_of_range: "Areadata plane out of bounds #{PLANE_MIN} to #{PLANE_MAX}",
    zone_out_of_range: "Areadata zone out of bounds 0 to #{ZONE_MAX}",
    bad_bit: "%s not a power of 2",
    bad_line: "Bad %s line in #AREADATA",
    kspawn_no_tilde: "Kspawn lacks terminating ~",
    kspawn_extra_tilde: "Misplaced tildes in Kspawn line",
    kspawn_text_after_tilde: "Invalid text on kspawn line after terminating ~",
    not_enough_tokens: "Not enough tokens on #AREADATA %s line"
  }

  @section_delimiter = "^S"

  attr_reader :plane, :zone, :flags, :outlaw, :kspawn, :modifier, :group_exp

  def initialize(contents, line_number=1)
    super(contents, line_number)
    @id = "areadata"

    @used_lines = []
    @kspawn_multiline = false
    slice_first_line
  end

  def to_hash
    {
      plane: @plane, zone: @zone, flags: @flags, outlaw: @outlaw,
      kspawn: @kspawn, modifier: @modifier, group_exp: @group_exp
    }
  end

  def parse
    section_end = false

    @contents.rstrip.each_line do |line|
      @current_line += 1
      line.rstrip!

      next if line.empty?

      # If we're following a kspawn line without a tilde, then this line is purely
      # text and shouldn't be parsed. If this line does contain a tilde, though,
      # then the text ends.
      if @kspawn_multiline
        # I'm cool with letting this hit a No Method on Nilclass error, since the
        # only way this could execute is if we already stuck text into the kspawn hash
        @kspawn[:text] << line
        if line.include?("~")
          @kspawn_multiline = false
          # However nothing but whitespace can follow that tilde!
          err(@current_line, line, AreaData.err_msg(:kspawn_text_after_tilde)) if line =~ /~.*?\S/
        end
        next
      end

      # If the "S" section has been parsed, then this line comes after the section
      # formally ends.
      if section_end
        err(@current_line, line, AreaData.err_msg(:continues_after_delimiter))
        break #Only need to throw this error once
      end

      if @used_lines.include? line[0]
        err(@current_line, line, AreaData.err_msg(:duplicate) % line[0])
      end

      case line[0]
      when "P"
        parse_plane_line line
      when "F"
        parse_flags_line line
      when "O"
        parse_outlaw_line line
      when "K"
        parse_kspawn_line line
      when "M"
        parse_modifier_line line
      when "G"
        parse_group_exp_line line
      when "S"
        section_end = true
      else
        err(@current_line, line, AreaData.err_msg(:invalid_line))
      end

    end
    err(@current_line, nil, AreaData.err_msg(:kspawn_no_tilde)) if @kspawn_multiline
    err(@current_line, nil, AreaData.err_msg(:no_delimiter)) unless section_end

    self
  end # parse

  private

  def ensure_numeric(token, line, name)
    if token =~ /\A-?\d+\z/
      token = token.to_i
    else
      token = nil
      err(@current_line, line, AreaData.err_msg(:invalid_field) % name)
    end
    token
  end

  def parse_plane_line line
    # Plane should match: P # #
    @used_lines << "P"

    plane, zone, error = line.split(" ", 4)[1..-1]
    if error
      err(@current_line, line, AreaData.err_msg(:invalid_extra_text) % "plane")
    end

    if plane && plane =~ /^-?\d+$/
      @plane = plane.to_i
      err(@current_line, line, AreaData.err_msg(:invalid_plane_0)) if @plane == 0
      err(@current_line, line, AreaData.err_msg(:plane_out_of_range)) unless @plane.between?(PLANE_MIN, PLANE_MAX)
    else
      err(@current_line, line, AreaData.err_msg(:invalid_field) % "area plane")
    end

    if zone
      if zone =~ /^-?\d+$/
        @zone = zone.to_i
        err(@current_line, line, AreaData.err_msg(:zone_out_of_range)) unless @zone.between?(0, ZONE_MAX)
      else
        err(@current_line, line, AreaData.err_msg(:invalid_field) % "area zone")
      end
    end
  end

  def parse_flags_line line
    # Areaflags should match: F #|#
    @used_lines << "F"

    flags, error = line.split(" ", 3)[1..-1]
    if flags =~ Bits.pattern
      @flags = Bits.new(flags)
      err(@current_line, line, AreaData.err_msg(:bad_bit) % "Area flags") if @flags.error?
    else
      err(@current_line, line, AreaData.err_msg(:bad_line) % "area flags")
    end
    err(@current_line, line, AreaData.err_msg(:invalid_extra_text) % "area flags") if error
  end

  def parse_outlaw_line line
    # Outlaw should match: O # # # # #
    @used_lines << "O"
    line_name = "outlaw"

    dump, jail, death_row, executioner, justice, error = line.split(" ", 7)[1..-1]

    if error
      err(@current_line, line, AreaData.err_msg(:invalid_extra_text) % line_name)
    elsif justice.nil?
      err(@current_line, line, AreaData.err_msg(:not_enough_tokens) % line_name)
    end

    # This will set the strings to an integer, or to nil if they're invalid
    dump = ensure_numeric(dump, line, line_name)
    jail = ensure_numeric(jail, line, line_name)
    death_row = ensure_numeric(death_row, line, line_name)
    executioner = ensure_numeric(executioner, line, line_name)
    justice = ensure_numeric(justice, line, line_name)


    @outlaw = {
      dump_vnum: dump, jail_vnum: jail, death_row_vnum: death_row,
      executioner_vnum: executioner, justice_factor: justice
    }
  end

  def parse_kspawn_line line
    # Kspawn should match: K # # # # text~
    # The text can span multiple lines, which makes this silly tricky,
    # not to mention ugly...
    @used_lines << "K"
    line_name = "seeker"

    condition, command, mob_vnum, room_vnum, text = line.split("\s", 6)[1..-1]

    # Check to see if the text ends on this line or continues on
    if text
      if text.include?("~")
        err(@current_line, line, AreaData.err_msg(:kspawn_extra_tilde)) unless text =~ /^[^~]*~$/
      else
        @kspawn_multiline = true
      end
    else
      err(@current_line, line, AreaData.err_msg(:not_enough_tokens) % "seeker")
    end

    condition = ensure_numeric(condition, line, line_name)
    command = ensure_numeric(command, line, line_name)
    mob_vnum = ensure_numeric(mob_vnum, line, line_name)
    room_vnum = ensure_numeric(room_vnum, line, line_name)

    @kspawn = {
      condition: condition, command: command, mob_vnum: mob_vnum,
      room_vnum: room_vnum, text: text[/^[^~]*/]
    }
  end

  def parse_modifier_line line
    # Modifiers should match: M # # # # # # 0 0
    @used_lines << "M"
    line_name = "area modifier"

    xpgain_mod, hp_regen_mod, mana_regen_mod, move_regen_mod, statloss_mod,
      respawn_room, zero, zero_two, error = line.split(" ", 10)[1..-1]

    if error
      err(@current_line, line, AreaData.err_msg(:invalid_extra_text) % line_name)
    elsif zero_two.nil?
      err(@current_line, line, AreaData.err_msg(:not_enough_tokens) % line_name)
    end

    xpgain_mod = ensure_numeric(xpgain_mod, line, line_name)
    hp_regen_mod = ensure_numeric(hp_regen_mod, line, line_name)
    mana_regen_mod = ensure_numeric(mana_regen_mod, line, line_name)
    move_regen_mod = ensure_numeric(move_regen_mod, line, line_name)
    statloss_mod = ensure_numeric(statloss_mod, line, line_name)
    respawn_room = ensure_numeric(respawn_room, line, line_name)

    @modifier = {
      xpgain_mod: xpgain_mod, hp_regen_mod: hp_regen_mod,
      mana_regen_mod: mana_regen_mod, move_regen_mod: move_regen_mod,
      statloss_mod: statloss_mod, respawn_room: respawn_room
    }
  end

  def parse_group_exp_line line
    # Group exp should match: G # # # # # # # 0
    @used_lines << "G"
    line_name = "group exp"

    pct0, num1, pct1, num2, pct2, pct3, div, zero, error = line.split(" ", 10)[1..-1]

    if error
      err(@current_line, line, AreaData.err_msg(:invalid_extra_text) % line_name)
    elsif zero.nil?
      err(@current_line, line, AreaData.err_msg(:not_enough_tokens) % line_name)
    end

    pct0 = ensure_numeric(pct0, line, line_name)
    num1 = ensure_numeric(num1, line, line_name)
    pct1 = ensure_numeric(pct1, line, line_name)
    num2 = ensure_numeric(num2, line, line_name)
    pct2 = ensure_numeric(pct2, line, line_name)
    pct3 = ensure_numeric(pct3, line, line_name)
    div = ensure_numeric(div, line, line_name)
    # Have to check zero for numericity (that even a word?)
    # even though it is a placeholder.
    zero = ensure_numeric(zero, line, line_name)

    @group_exp = {
      pct0: pct0, num1: num1, pct1: pct1, num2: num2, pct2: pct2,
      pct3: pct3, diversity: div
    }
  end

end
