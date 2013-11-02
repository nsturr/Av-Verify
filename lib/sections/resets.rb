require_relative "section"
require_relative "../helpers/parsable"

class Resets < Section

  attr_reader :resets, :reset_counts, :errors

  @section_delimeter = "^S"

  def initialize(contents, line_number)
    super(contents, line_number)
    @id = "RESETS"

    @resets = []
    @reset_counts = Hash.new(0)

    @recent_mob_reset
    @recent_container_reset
    @previous_reset_type = :null

    slice_first_line
    split_resets
  end

  def split_resets
    @delimeter = slice_delimeter

    # Conveniently has a line-by-line structure to it. Easy street.
    @contents.each_line do |line|
      @current_line += 1
      next if line.strip.empty?
      next if line.strip.start_with? "*"
      @resets << Reset.new(line.rstrip, @current_line)
    end

  end

  def parse

    @resets.each do |reset|

      reset.parse
      @errors += reset.errors

      # This relates to attaching equip and inventory resets to mob resets,
      # and container resets to objects
      case reset.type
      when :mobile
        @recent_mob_reset = reset
        @previous_reset_type = :mobile
        if @reset_counts[reset.vnum] >= reset.limit
          warn(reset.line_number, reset.line, "Mob reset limit is #{reset.limit}, but #{@reset_counts[reset.vnum]} mobs load before it.")
        end
        @reset_counts[reset.vnum] += 1

      when :equipment
        if @recent_mob_reset
          if @recent_mob_reset.attachments.any? { |el| el.target == reset.target && el.slot == reset.slot}
            err(reset.line_number, reset.line, "Wear location already filled on this mob reset.")
          end
          @recent_mob_reset.attachments << reset
        end
        unless @previous_reset_type == :mobile
          warn(reset.line_number, reset.line, "Equipment reset doesn't immediately follow a mob")
        end

      when :inventory
        @recent_mob_reset.attachments << reset if @recent_mob_reset
        unless @previous_reset_type == :mobile
          warn(reset.line_number, reset.line, "Inventory reset doesn't immediately follow a mob")
        end

      else
        @previous_reset_type = :null
      end
    end

    @current_line += 1
    if @delimeter.nil?
      err(@current_line, nil, "#RESETS section lacks terminating S")
    else
      unless @delimeter.rstrip =~ /#{Resets.delimeter(:start)}\z/
        line_num, bad_line = invalid_text_after_delimeter(@current_line, @delimeter)
        err(line_num, bad_line, "#RESETS section continues after terminating S")
      end
    end

  end

end

class Reset
  include Parsable

  attr_reader :line_number, :line, :vnum, :type, :target, :limit, :slot, :errors,
    :attachments

  def initialize(line, line_number)
    @line = line
    @line_number = line_number
    @type = case line.lstrip[0]
      when "M" then :mobile
      when "G" then :inventory
      when "E" then :equipment
      when "O" then :object
      when "P" then :container
      when "D" then :door
      when "R" then :random
      else :invalid
      end
    @attachments = []
    @errors = []
  end

  def parse
    if self.type == :invalid
      err(@line_number, @line, "Invalid reset (expecting M, G, E, O, P, D, R)")
    else
      self.send("parse_#{self.type}")
    end
  end

  def parse_mobile
    # Line syntax: M 0 mob_VNUM limit room_VNUM comments
    zero, vnum, limit, room, comment = line.split(" ", 6)[1..-1]
    unless [vnum, limit, room].any? { |el| el.nil? }

      unless zero =~ /^-?\d+$/
        err(@line_number, @line, "Line should match: M 0 <vnum> <limit> <room>")
      end

      if vnum =~ /^-?\d+$/
        @vnum = vnum.to_i
        err(@line_number, @line, "Mob VNUM can't be 0 or negative") if @vnum < 1
      else
        err(@line_number, @line, "Invalid mob VNUM")
      end

      if limit =~ /^-?\d+$/
        @limit = limit.to_i
        err(@line_number, @line, "Mob limit can't be negative") if @limit < 0
      else
        err(@line_number, @line, "Invalid mob limit")
      end

      # Sometimes comments starting with * are smooshed up against the room vnum
      if room =~ /^-?\d+\*?$/
        @target = room[/^[^\*]*/].to_i
        err(@line_number, @line, "Target spawn room can't be negative") if @target < 0
      else
        err(@line_number, @line, "Invalid room VNUM")
      end

    else
      err(@line_number, @line, "Not enough tokens on in mob reset line")
    end

  end

  def parse_inventory
    # Line syntax: G <0 or -#> obj_VNUM 0
    limit, vnum, zero, comment = line.split(" ", 5)[1..-1]
    unless [limit, vnum, zero].any? { |el| el.nil? }

      if limit =~ /^-?\d+$/
        @limit = limit.to_i
      else
        err(@line_number, @line, "Invalid inventory spawn limit")
      end

      if vnum =~ /^-?\d+$/
        @vnum = vnum.to_i
        err(@line_number, @line, "Object VNUM can't be negative") if @vnum < 0
      else
        err(@line_number, @line, "Invalid object VNUM")
      end

      # The zero doesn't actually need to be a zero, just needs to be there
      unless zero =~ /^-?\d+\*?$/
        err(@line_number, @line, "Line should match: G <0 or -#> <vnum> 0")
      end
    else
      err(@line_number, @line, "Not enough tokens in inventory reset line")
    end
  end

  def parse_equipment
    # Line syntax: E <0 or -#> <vnum> 0 <wear>
    limit, vnum, zero, wear, comment = line.split(" ", 6)[1..-1]
    unless [limit, vnum, zero, wear].any? { |el| el.nil? }

      if limit =~ /^-?\d+$/
        @limit = limit.to_i
      else
        err(@line_number, @line, "Invalid first token")
      end

      if vnum =~ /^-?\d+$/
        @vnum = vnum.to_i
        err(@line_number, @line, "Object VNUM can't be negative") if @vnum < 0
      else
        err(@line_number, @line, "Invalid object VNUM")
      end

      # The zero doesn't need to be a zero, it just needs to be there
      unless zero =~ /^-?\d+$/
        err(@line_number, @line, "Line should match: E <0 or -#> <vnum> 0 <wear>")
      end

      if wear =~ /^-?\d+\*?$/
        @slot = wear[/[^\*]*/].to_i
        err(@line_number, @line, "Wear location out of bounds 0 to #{WEAR_MAX}") unless @slot.between?(0,WEAR_MAX)
      else
        err(@line_number, @line, "Invalid wear location")
      end
    else
      err(@line_number, @line, "Not enough tokens in equipment reset line")
    end
  end

  def parse_object
    # Line syntax: O 0 <vnum> 0 <room>
    zero, vnum, zero_two, room, comment = line.split(" ", 6)[1..-1]
    unless [zero, vnum, zero_two, room].any? { |el| el.nil? }

      # MOOOOOOON ZEEEERO TWOOOOOO!
      unless zero =~ /^-?\d+$/ && zero_two =~ /^-?\d+$/
        err(@line_number, @line, "Line should match: O 0 <vnum> 0 <room>")
      end

      if vnum =~ /^-?\d+$/
        @vnum = vnum.to_i
        err(@line_number, @line, "Object VNUM can't be negative") if @vnum < 0
      else
        err(@line_number, @line, "Invalid object VNUM")
      end

      if room =~ /^-?\d+\*?$/
        @target = room[/[^\*]*/].to_i
        err(@line_number, @line, "Target room VNUM can't be negative") if @target < 0
      else
        err(@line_number, @line, "Invalid target room VNUM")
      end
    else
      err(@line_number, @line, "Not enough tokens in object reset line")
    end
  end

  def parse_container
    # Line syntax: P 0 <vnum> 0 <container>
    zero, vnum, zero_two, container, comment = line.split(" ", 6)[1..-1]
    unless [zero, vnum, zero_two, container].any? { |el| el.nil? }

      # MOOOOOOON ZEEEERO TWOOOOOO!
      unless zero =~ /^-?\d+$/ && zero_two =~ /^-?\d+$/
        err(@line_number, @line, "Line should match: O 0 <vnum> 0 <room>")
      end

      if vnum =~ /^-?\d+$/
        @vnum = vnum.to_i
        err(@line_number, @line, "Object VNUM can't be negative") if @vnum < 0
      else
        err(@line_number, @line, "Invalid object VNUM")
      end

      if container =~ /^-?\d+\*?$/
        @target = container[/^[^*]*/].to_i
        err(@line_number, @line, "Target container VNUM can't be negative") if @target < 0
      else
        err(@line_number, @line, "Invalid target container VNUM")
      end
    else
      err(@line_number, @line, "Not enough tokens in container reset line")
    end
  end

  def parse_door
    # Line syntax: D 0 <room> <direction> <state>
    zero, vnum, direction, state, comment = line.split(" ", 6)[1..-1]

    unless [zero, vnum, direction, state].any? { |el| el.nil? }

      if vnum =~ /^-?\d+$/
        @vnum = vnum.to_i
        err(@line_number, @line, "Room VNUM can't be negative") if @vnum < 0
      else
        err(@line_number, @line, "Invalid room VNUM")
      end

      if direction =~ /^-?\d+$/
        @target = direction.to_i
        err(@line_number, @line, "Door number out of bounds 0 to 5") unless @target.between?(0,5)
      else
        err(@line_number, @line, "Invalid door direction")
      end

      if state =~ /^-?\d+\*?$/
        @slot = state[/~[^\*]*/].to_i
        err(@line_number, @line, "Door state out of bounds 0 to 8") unless @slot.between?(0,8)
      else
        err(@line_number, @line, "Invalid door state")
      end
    else
      err(@line_number, @line, "Not enough tokens in door reset line")
    end
  end

  def parse_random
    # Line syntax: R 0 vnum number_of_exits
    # drop the leading R and the comment
    zero, target, number_of_exits, comment = line.split(" ", 5)[1..-2]
    unless [zero, target, number_of_exits].any? { |el| el.nil? }

      unless zero =~ /^-?\d+$/
        err(@line_number, @line, "Line should match: R 0 <vnum> <number_of_exits>")
      end

      if target =~ /^-?\d+$/
        @target = target.to_i
        err(@line_number, @line, "Room VNUM can't be negative") if @target < 0
      else
        err(@line_number, @line, "Invalid target room VNUM")
      end

      if number_of_exits =~ /^-?\d+\*?$/
        @slot = number_of_exits.to_i
        err(@line_number, @line, "Number of exits out of bounds 0 to 6") unless @slot.between?(0,6)
      else
        err(@line_number, @line, "Invalid number of exits")
      end
    else
      err(@line_number, @line, "Not enough tokens in random reset line")
    end
  end

end
