require_relative "vnum_section"
require_relative "line_by_line_object"
require_relative "../helpers/tilde"
require_relative "../helpers/has_quoted_keywords"
require_relative "../helpers/bits"

class Rooms < VnumSection

  @section_delimiter = "#0" # N.B. some valid vnums regrettably begin with a 0

  def child_class
    Room
  end

  def child_regex
    /^(?=#\d\S*)/
  end

  def initialize(options)
    super(options)
  end

  def to_s
    "#ROOMS: #{self.rooms.size} entries, line #{self.line_number}"
  end

end

class Room < LineByLineObject
  include HasQuotedKeywords

  ATTRIBUTES = [:vnum, :name, :description, :roomflags, :sector, :doors,
                :edesc, :align, :klass]

  @ERROR_MESSAGES = {
    continues_after_delimiter: "Room definition continues after terminating S",
    invalid_field: "Invalid field (expecting D#, A, C, E, or S)",
    visible_tab: "Visible text contains a tab character",
    forgot_tilde?: "This doesn't look like part of a description. Forget a terminating ~ above?",
    bad_roomflag_line: "Line should match: 0 <roomflags> <sector>",
    bad_door_locks_line: "Line should match: <locks> <key> <to_vnum>",
    flag_not_power_of_two: "%s flag is not a power of 2",
    bad_roomflag: "Invalid roomflag field",
    sector_out_of_bounds: "Room sector out of bounds 0 to #{SECTOR_MAX}",
    bad_sector: "Invalid sector field",
    door_duplicate_dir: "Duplicate exit direction in room",
    door_invalid_text: "Invalid text after exit header",
    door_bad_dir: "Invalid exit direction",
    door_bad_flag: "Doesn't look like a valid flag. Mix up your door's keyword and desc lines?",
    door_bad_destination: "Invalid door destination field",
    door_bad_key: "Invalid door key field",
    door_bad_lock: "Invalid door lock field",
    door_lock_out_of_bounds: "Door lock type out of bounds 0 to #{LOCK_MAX}",
    invalid_text_after: "Invalid text after room %s",
    invalid_alignment_line: "Invalid alignment restriction line",
    invalid_class_line: "Invalid class restriction line",
    edesc_keywords_spans: "Edesc keywords span multiple lines"
  }

  attr_reader :line_number, *ATTRIBUTES

  def initialize(options)
    super(options)

    @description = ""
    @doors = {}
    @edesc = {}

    # temporary vars
    # @recent_door
  end

  def to_s
    "<Room: vnum #{self.vnum}, #{self.name}, line #{self.line_number}>"
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
    self
  end

  private

  def parse_vnum line
    m = line.match(/#(?<vnum>\d+)/)
    # To even be created, a Room needs to have a valid vnum
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
    @name = line[/\A[^~]*/]
    expect :description
  end

  def parse_description line
    ugly(@current_line, line, Room.err_msg(:visible_tab)) if line.include?("\t")

    if line =~ /^\d+ +#{Bits.insert} +\d+ *$/
      err(@current_line, line, Room.err_msg(:forgot_tilde?))
      # Set code block to expect the next line (which is the line we just found)
      # and redo the block on the current line
      expect :roomflags_sector
      return :redo
    else
      @description << line << "\n"
    end
    if has_tilde? line
      validate_tilde(
        line: line,
        line_number: @current_line,
        present: false,
        should_be_alone: true
      )
      expect :roomflags_sector
    end
  end

  def parse_roomflags_sector line
    return if invalid_blank_line? line

    zero, roomflags, sector, error = line.strip.split
    if error || zero =~ /\D/
      err(@current_line, line, Room.err_msg(:bad_roomflag_line))
    end
    if roomflags =~ Bits.pattern
      @roomflags = Bits.new(roomflags)
      err(@current_line, line, Room.err_msg(:flag_not_power_of_two) & "Room") if @roomflags.error?
    else
      err(@current_line, line, Room.err_msg(:bad_roomflag))
    end
    if sector =~ /\d+\b/
      @sector = sector
      err(@current_line, line, Room.err_msg(:sector_out_of_bounds)) unless @sector.to_i.between?(0, SECTOR_MAX)
    else
      err(@current_line, line, Room.err_msg(:bad_sector))
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

        err(@current_line, line, Room.err_msg(:door_duplicate_dir)) unless self.doors[direction].nil?
        err(@current_line, line, Room.err_msg(:door_invalid_text)) unless line =~ /^D\d$/
        err(@current_line, line, Room.err_msg(:door_bad_dir)) unless direction.between?(0,5)

        @recent_door = new_door(direction) # temp variable
      else
        err(@current_line, line, Room.err_msg(:invalid_room_field))
      end
      expect :door_desc

    when "E"
      expect :edesc_keywords

    when "A"
      if m = line.match(/^A +(#{Bits.insert})/)
        @align = Bits.new(m[1])
        err(@current_line, line, Room.err_msg(:flag_not_power_of_two, "Alignment restriction")) if @align.error?
        err(@current_line, line, Room.err_msg(:invalid_text_after, "alignment restriction")) unless line =~ /^A +#{Bits.insert}$/
      else
        err(@current_line, line, Room.err_msg(:invalid_alignment_line))
      end
      expect :misc

    when "C"
      if m = line.match(/^C +(#{Bits.insert})/)
        @klass = Bits.new(m[1])
        err(@current_line, line, Room.err_msg(:flag_not_power_of_two, "Class restriction")) if klass.error?
        err(@current_line, line, Room.err_msg(:invalid_text_after, "class restriction")) unless line =~ /^C +#{Bits.insert}$/
      else
        err(@current_line, line, Room.err_msg(:invalid_class_line))
      end
      expect :misc

    when "S"
      # Ends the room definition
      expect :end

    else
      if line =~ /\Adoor\b/
        warn(@current_line, line, Room.err_msg(:door_bad_flag))
      else
        err(@current_line, line, Room.err_msg(:invalid_field))
      end
    end
  end

  def parse_door_desc line
    @recent_door[:description] << line[/[^~]*/] << "\n"
    ugly(@current_line, line, Room.err_msg(:visible_tab)) if line.include?("\t")

    if has_tilde? line
      expect :door_keyword
      validate_tilde(
        line: line,
        line_number: @current_line,
        should_be_alone: true,
        present: false
      )
    end
  end

  def parse_door_keyword line
    return if invalid_blank_line? line

    @recent_door[:keywords] = parse_quoted_keywords(line[/^[^~]*/], line)

    validate_tilde(
      line: line,
      line_number: @current_line,
      might_span_lines: true
    )

    expect :door_locks
  end

  def parse_door_locks line

    locks, key, to_vnum, error = line.split
    # Make sure the right number of items are on the line
    unless error || [locks, key, to_vnum].any? { |el| el.nil? }
      @recent_door[:lock_line_number] = @current_line unless @recent_door.nil?
      if locks =~ /^\d+$/
        locks = locks.to_i
        @recent_door[:lock] = locks unless @recent_door.nil?
        err(@current_line, line, Room.err_msg(:door_lock_out_of_bounds)) unless locks.between?(0,LOCK_MAX)
      else
        err(@current_line, line, Room.err_msg(:door_bad_lock))
      end
      if key =~ /^-1$|^\d+$/
        # Valid values for keys are -1, 0, or any positive number.
        @recent_door[:key] = key.to_i unless @recent_door.nil?
      else
        err(@current_line, line, Room.err_msg(:door_bad_key))
      end
      if to_vnum =~ /^-1$|^\d+$/
        # Valid values for destinations are -1, or any positive number.
        @recent_door[:dest] = to_vnum.to_i unless @recent_door.nil?
      else
        err(@current_line, line, Room.err_msg(:door_bad_destination))
      end
      self.doors[@recent_door[:direction]] = @recent_door
      @recent_door = nil
    else
      err(@current_line, line, Room.err_msg(:bad_door_locks_line))
    end

    expect :misc
  end

  def parse_edesc_keywords line
    if line.empty?
      err(@current_line, line, Room.err_msg(:edesc_keywords_spans))
      return
    end

    keywords = parse_quoted_keywords(line[/[^~]*/], line)
    @recent_keywords = keywords
    @edesc[keywords] = ""

    validate_tilde(
      line: line,
      line_number: @current_line,
      might_span_lines: true
    )

    @last_multiline = @current_line
    expect :multiline_edesc
  end

  def parse_multiline_edesc line
    ugly(@current_line, line, Room.err_msg(:visible_tab)) if line.include?("\t")
    @edesc[@recent_keywords] << line[/[^~]*/] << "\n"

    if has_tilde? line
      expect :misc
      @recent_keywords = nil
      validate_tilde(
        line: line,
        line_number: @current_line,
        present: false,
        should_be_alone: true
      )
    end
  end

  def parse_end line
    err(@current_line, line, Room.err_msg(:continues_after_delimiter))
    return :break
  end

  def new_door direction
    {direction: direction, description: ""}
  end

end
