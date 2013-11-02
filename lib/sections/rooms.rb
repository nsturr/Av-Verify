require "./sections/vnum_section"
require "./sections/line_by_line_object"
require "./helpers/tilde"
require "./helpers/has_quoted_keywords"
require "./helpers/bits"

class Rooms < VnumSection

  @section_delimeter = "^#0\\b" # N.B. some valid vnums regrettably begin with a 0

  def self.child_class
    Room
  end

  def initialize(contents, line_number)
    super(contents, line_number)
    @name = "ROOMS"
  end

  def rooms
    @entries
  end

end

class Room < LineByLineObject
  include HasQuotedKeywords

  ATTRIBUTES = [:vnum, :name, :description, :roomflags, :sector, :doors,
                :edesc, :align, :klass]

  attr_reader :line_number, *ATTRIBUTES

  def self.invalid_room_field
    "Invalid field (expecting D#, A, C, E, or S)"
  end

  def initialize(contents, line_number)
    super(contents, line_number)

    @description = ""
    @doors = {}
    @edesc = {}

    # temporary vars
    # @recent_door
  end

  def parse
    super
    if @expectation != :end
      whine = case @expectation
        when :door_desc
          "Room definition ends inside a door block"
        when :door_keywords
          "Room definition ends inside a door block"
        when :door_locks
          "Room definition ends inside a door block"
        when :edesc_keywords
          "Room definition ends inside an edesc"
        when :multiline_edesc
          "Room definition ends inside an edesc"
        when :misc
          "Room definition has no terminating S"
        end

      err(@current_line, nil, whine)
    end
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
    expect :name
  end

  def parse_name line
    return if invalid_blank_line? line
    if has_tilde? line
      err(@current_line, line, tilde(:extra_text, "Room name")) unless trailing_tilde? line
    else
      err(@current_line, line, tilde(:absent_or_spans, "Room name"))
    end
    @name = line[/\A[^~]*/]
    expect :description
  end

  def parse_description line
    ugly(@current_line, line, "Visible text contains a tab character") if line.include?("\t")

    if line =~ /^\d+ +#{Bits.insert} +\d+ *$/
      err(@current_line, line, "This doesn't look like part of a description. Forget a terminating ~ above?")
      # Set code block to expect the next line (which is the line we just found)
      # and redo the block on the current line
      expect :roomflags_sector
      return :redo
    else
      @description << line
    end
    if has_tilde? line
      expect :roomflags_sector
      if trailing_tilde? line
        ugly(@current_line, line, tilde(:not_alone)) unless isolated_tilde? line
      else
        err(@current_line, line, tilde(:extra_text, "Description"))
      end
    end
  end

  def parse_roomflags_sector line
    return if invalid_blank_line? line

    zero, roomflags, sector, error = line.strip.split
    if error || zero != "0"
      err(@current_line, line, "Line should match: 0 <roomflags> <sector>")
    end
    if roomflags =~ Bits.pattern
      @roomflags = Bits.new(roomflags)
      err(@current_line, line, "Room flag is not a power of 2") if @roomflags.error?
    else
      err(@current_line, line, "Invalid roomflag field")
    end
    if sector =~ /\d+\b/
      @sector = sector
      err(@current_line, line, "Room sector out of bounds 0 to #{SECTOR_MAX}") unless @sector.to_i.between?(0, SECTOR_MAX)
    else
      err(@current_line, line, "Invalid sector field")
    end

    expect :misc
  end

  def parse_misc line
    return if invalid_blank_line? line

    case line.lstrip[0]
    when "D"

      if m = line.match(/^D(?<direction>\d)/)
        @last_multiline = @current_line + 1 #Next line begins a multiline field
        direction = m[:direction].to_i

        err(@current_line, line, "Duplicate exit direction in room") unless self.doors[direction].nil?
        err(@current_line, line, "Invalid text after exit header") unless line =~ /^D\d$/
        err(@current_line, line, "Invalid exit direction") unless direction.between?(0,5)

        @recent_door = new_door(direction) # temp variable
      else
        err(@current_line, line, Room.invalid_room_field)
      end
      expect :door_desc

    when "E"
      expect :edesc_keywords

    when "A"
      if m = line.match(/^A +(#{Bits.insert})/)
        @align = Bits.new(m[1])
        err(@current_line, line, "Alignment restriction flag is not a power of 2") if @align.error?
        err(@current_line, line, "Invalid text after room alignment restriction") unless line =~ /^A +#{Bits.insert}$/
      else
        err(@current_line, line, "Invalid alignment restriction line")
      end
      expect :misc

    when "C"
      if m = line.match(/^C +(#{Bits.insert})/)
        @klass = Bits.new(m[1])
        err(@current_line, line, "Class restriction flag is not a power of 2") if klass.error?
        err(@current_line, line, "Invalid text after room class restriction") unless line =~ /^C +#{Bits.insert}$/
      else
        err(@current_line, line, "Invalid class restriction line")
      end
      expect :misc

    when "S"
      # Ends the room definition
      expect :end

    else
      err(@current_line, line, Room.invalid_room_field)
    end
  end

  def parse_door_desc line
    @recent_door[:description] << line[/[^~]*/]
    ugly(current_line, line, "Visible text contains a tab character") if line.include?("\t")

    if has_tilde? line
      expect :door_keyword
      err(@current_line, line, tilde(:extra_text, "Door desc")) unless trailing_tilde? line
      ugly(@current_line, line, tilde(:not_alone, "Door desc")) unless isolated_tilde? line
    end
  end

  def parse_door_keyword line
    return if invalid_blank_line? line

    @recent_door[:keywords] = parse_quoted_keywords(line[/^[^~]*/], line, true, "door")

    if line =~ /^[^~]*~$/
      #
    elsif line =~ /~./
      err(@current_line, line, "Invalid text after terminating ~")
    else
      err(@current_line, line, "Door keywords lack terminating ~ or spans multiple lines")
    end

    expect :door_locks
  end

  def parse_door_locks line

    locks, key, to_vnum, error = line.split
    # Make sure the right number of items are on the line
    unless error || [locks, key, to_vnum].any? { |el| el.nil? }
      if locks =~ /^\d+$/
        locks = locks.to_i
        @recent_door[:lock] = locks unless @recent_door.nil?
        err(@current_line, line, "Door lock type out of bounds 0 to #{LOCK_MAX}") unless locks.between?(0,LOCK_MAX)
      else
        err(@current_line, line, "Invalid door lock field")
      end
      if key =~ /^-1$|^\d+$/
        # Valid values for keys are -1, 0, or any positive number.
        @recent_door[:key] = key.to_i unless @recent_door.nil?
      else
        err(@current_line, line, "Invalid door key field")
      end
      if to_vnum =~ /^-1$|^\d+$/
        # Valid values for destinations are -1, or any positive number.
        @recent_door[:dest] = to_vnum.to_i unless @recent_door.nil?
      else
        err(@current_line, line, "Invalid door destination field")
      end
      self.doors[@recent_door[:direction]] = @recent_door
      @recent_door = nil
    else
      err(@current_line, line, "Line should match: <locks> <key> <to_vnum>")
    end

    expect :misc
  end

  def parse_edesc_keywords line
    if line.empty?
      err(@current_line, line, "Edesc keywords span multiple lines")
      return
    end

    keywords = parse_quoted_keywords(line[/[^~]*/], line)
    @recent_keywords = keywords
    @edesc[keywords] = ""

    @last_multiline = @current_line
    expect :multiline_edesc
  end

  def parse_multiline_edesc line
    ugly(current_line, line, "Visible text contains a tab character") if line.include?("\t")
    @edesc[@recent_keywords] << line[/[^~]*/]

    if has_tilde? line
      expect :misc
      @recent_keywords = nil
      err(@current_line, line, tilde(:extra_text, "Edesc body")) unless trailing_tilde? line
      ugly(@current_line, line, tilde(:not_alone, "Edesc body")) unless isolated_tilde? line
    end
  end

  def parse_end line
    err(@current_line, line, "Room definition continues after terminating S")
    return :break
  end

  private

  def new_door direction
    h = Hash.new
    h[:direction] = direction
    h[:description] = ""
    h
  end

end
