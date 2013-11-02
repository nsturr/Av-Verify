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
    invalid_field: "Invalid (non-numeric) %s",
    plane_out_of_range: "Areadata plane out of bounds #{PLANE_MIN} to #{PLANE_MAX}",
    zone_out_of_range: "Areadata zone out of bounds 0 to #{ZONE_MAX}",
    bad_bit: "%s not a power of 2",
    bad_line: "Bad %s line in #AREADATA",
    kspawn_no_tilde: "Kspawn lacks terminating ~",
    kspawn_extra_tilde: "Misplaced tildes in Kspawn line",
    kspawn_text_after_tilde: "Invalid text on kspawn line after terminating ~"
  }

  @section_delimiter = "^S"

  def initialize(contents, line_number=1)
    super(contents, line_number)
    @id = "AREADATA"

    @used_lines = []
    @kspawn_multiline = false
    slice_first_line
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

  def parse_plane_line line
    # Plane should match: P # #
    @used_lines << "P"
    items = line.split(" ", 4)
    if items.length > 3
      err(@current_line, line, AreaData.err_msg(:invalid_extra_text) % "plane")
    end

    if items.length > 1 && items[1] =~ /^-?\d+$/
      err(@current_line, line, AreaData.err_msg(:invalid_plane_0)) if items[1].to_i == 0
      err(@current_line, line, AreaData.err_msg(:plane_out_of_range)) unless items[1].to_i.between?(PLANE_MIN, PLANE_MAX)
    else
      err(@current_line, line, AreaData.err_msg(:invalid_field) % "area plane")
    end
    # Only bother checking for the zone field if there are enough bits in the line
    if items.length > 2
      if items[2] =~ /^-?\d+$/
        err(@current_line, line, AreaData.err_msg(:zone_out_of_range)) unless items[2].to_i.between?(0, ZONE_MAX)
      else
        err(@current_line, line, AreaData.err_msg(:invalid_field) % "area zone")
      end
    end
  end

  def parse_flags_line line
    # Areaflags should match: F #|#
    @used_lines << "F"
    items = line.split(" ", 3)
    if items[1] =~ Bits.pattern
      err(@current_line, line, AreaData.err_msg(:bad_bit) % "Area flags") if Bits.new(items[1]).error?
    else
      err(@current_line, line, AreaData.err_msg(:bad_line) % "area flags")
    end
    err(@current_line, line, AreaData.err_msg(:invalid_extra_text) % "area flags") if items.length > 2
  end

  def parse_outlaw_line line
    # Outlaw should match: O # # # # #
    @used_lines << "O"
    unless line =~ /^O(\s+-?\d+){5}$/
      err(@current_line, line, AreaData.err_msg(:bad_line) % "outlaw")
    end
  end

  def parse_kspawn_line line
    # Kspawn should match: K # # # # text~
    # The text can span multiple lines, which makes this silly tricky,
    # not to mention ugly...
    @used_lines << "K"
    unless line =~ /^K\s+\d+\s+\d+\s+-?\d+\s+-?\d+/
      err(@current_line, line, AreaData.err_msg(:bad_line) % "kspawn")
    end

    if line.include?("~")
      err(@current_line, line, AreaData.err_msg(:kspawn_extra_tilde)) unless line =~ /^K[^~]*~$/
    else
      @kspawn_multiline = true
    end
  end

  def parse_modifier_line line
    # Modifiers should match: M # # # # # # 0 0
    @used_lines << "M"
    unless line =~ /^M(\s+(-|\+)?\d+){8}$/
      err(@current_line, line, AreaData.err_msg(:bad_line) % "area modifier")
    end
  end

  def parse_group_exp_line line
    # Group exp should match: G # # # # # # # 0
    @used_lines << "G"
    unless line =~ /^G(\s+\d+){8}$/
      err(@current_line, line, AreaData.err_msg(:bad_line) % "group exp")
    end
  end

end
