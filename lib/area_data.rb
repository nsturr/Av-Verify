require_relative 'parsable.rb'

class AreaData
  include Parsable

  def initialize(contents, line_number=1)
    @line_number = line_number
    @current_line = line_number
    @contents = contents
    @errors = []

    @used_lines = []
    @kspawn_multiline = false
  end

  def parse

    @contents.rstrip.each_line do |line|
      line.rstrip!

      if line.empty?
        current_line += 1
        next
      end

      # If we're following a kspawn line without a tilde, then this line is purely
      # text and shouldn't be parsed. If this line does contain a tilde, though,
      # then the text ends.
      if @kspawn_multiline
        if line.include?("~")
          @kspawn_multiline = false
          # However nothing but whitespace can follow that tilde!
          err(current_line, line, "Invalid text on kspawn line after terminating ~") if line =~ /~.*?\S/
        end
        # If we haven't found any tildes in this line, then the text must be continuing.
        # Onward to the next line!
        @current_line += 1
        next
      end

      # If the "S" section has been parsed, then this line comes after the section
      # formally ends.
      if @used_lines.include? "S"
        err(current_line, line, "Section continues after 'S' delimeter")
        break #Only need to throw this error once
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
      else
        err(current_line, line, "Invalid AREADATA line")
      end

      @current_line += 1

      err(@current_line, nil, "Kspawn line lacks terminating ~") if @kspawn_multiline
      @errors
    end
  end # parse

  private

  def parse_plane_line line
    # Plane should match: P # #
    if used_lines.include? "P"
      err(@current_line, line, "Duplicate \"Plane\" line in #AREADATA")
    else
      @used_lines << "P"
      items = line.split(" ", 4)
      if items.length > 3
        err(@current_line, line, "Invalid text after #AREADATA plane line")
      end

      if items.length > 1 && items[1] =~ /^-?\d+$/
        err(@current_line, line, "Invalid area plane: 0") if items[1].to_i == 0
        err(@current_line, line, "Areadata plane out of bounds #{PLANE_MIN} to #{PLANE_MAX}") unless items[1].to_i.between?(PLANE_MIN, PLANE_MAX)
      else
        err(@current_line, line, "Invalid (non-numeric) area plane")
      end
      # Only bother checking for the zone field if there are enough bits in the line
      if items.length > 2
        if items[2] =~ /^-?\d+$/
          err(@current_line, line, "Areadata zone out of bounds 0 to #{ZONE_MAX}") unless items[2].to_i.between?(0, ZONE_MAX)
        else
          err(@current_line, line, "Invalid (non-numeric) area zone")
        end
      end
    end
  end

  def parse_flags_line line
    # Areaflags should match: F #|#
    if @used_lines.include? "F"
      err(@current_line, line, "Duplicate \"Areaflags\" line in #AREADATA")
    else
      @used_lines << "F"
      items = line.split(" ", 3)
      if items[1] =~ Bits.pattern
        err(@current_line, line, "Areaflags not a power of 2") if Bits.new(items[1]).error?
      else
        err(@current_line, line, "Bad \"Areaflags\" line in #AREADATA")
      end
      err(@current_line, line, "Invalid text after #AREADATA area flags") if items.length > 2
    end
  end

  def parse_outlaw_line line
    # Outlaw should match: O # # # # #
    if @used_lines.include? "O"
      err(current_line, line, "Duplicate \"Outlaw\" line in #AREADATA")
    else
      @used_lines << "O"
      unless line =~ /^O(\s+-?\d+){5}$/
        err(current_line, line, "Bad \"Outlaw\" line in #AREADATA")
      end
    end
  end

  def parse_kspawn_line line
    # Kspawn should match: K # # # # text~
    # The text can span multiple lines, which makes this silly tricky,
    # not to mention ugly...
    if @used_lines.include? "K"
      err(current_line, line, "Duplicate \"Kspawn\" line in #AREADATA")
    else
      @used_lines << "K"
      unless line =~ /^K\s+\d+\s+\d+\s+-?\d+\s+-?\d+/
        err(current_line, line, "Bad \"Kspawn\" line in #AREADATA")
      end

      if line.include?("~")
        err(current_line, line, "Misplaced tildes in Kspawn line") unless line =~ /^K[^~]*~$/
      else
        @kspawn_multiline = true
      end
    end
  end

  def parse_modifier_line line
    # Modifiers should match: M # # # # # # 0 0
    if @used_lines.include? "M"
      err(current_line, line, "Duplicate \"Area modifier\" line in #AREADATA")
    else
      @used_lines << "M"
      unless line =~ /^M(\s+(-|\+)?\d+){8}$/
        err(current_line, line, "Bad \"Area modifier\" line in #AREADATA")
      end
    end
  end

  def parse_group_exp_line line
    # Group exp should match: G # # # # # # # 0
    if @used_lines.include? "G"
      err(current_line, line, "Duplicate \"Group exp\" line in #AREADATA")
    else
      @used_lines << "G"
      unless line =~ /^G(\s+\d+){8}$/
        err(current_line, line, "Bad \"Group exp\" line in #AREADATA")
      end
    end
  end

end
