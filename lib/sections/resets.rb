require_relative "section"
require_relative "../helpers/parsable"
require_relative "../helpers/avconstants"

class Resets < Section

  attr_reader :resets, :reset_counts, :errors

  @section_delimiter = "S"

  @ERROR_MESSAGES = {
    reset_limit: "Mob reset limit is %i, but %i mobs load before it.",
    wear_loc_filled: "Wear location already filled on this mob reset.",
    reset_doesnt_follow_mob: "%s reset doesn't immediately follow a mob",
    no_delimiter: "#RESETS section lacks terminating S",
    continues_after_delimiter: "#RESETS section continues after terminating S"
  }

  def child_class
    Reset
  end

  def child_regex
    /\n/
  end

  def self.valid_reset
    Proc.new do |reset|
      line = reset.lstrip
      skip_line = false
      skip_line = true if line.empty? || line.start_with?("*")

      !skip_line
    end
  end

  def initialize(contents, line_number=1)
    super(contents, line_number)
    @id = "resets"

    @children = []
    @reset_counts = Hash.new(0)

    @recent_mob_reset
    @recent_container_reset
    @previous_reset_type = :null

    slice_first_line!
  end

  def [](index)
    self.children[index]
  end

  def <<(reset)
    self.children << reset
  end

  def each(&prc)
    self.children.each(&prc)
  end

  def to_s
    "#RESETS: #{self.resets.size} entries, line #{self.line_number}"
  end

  def parse
    @parsed = true

    split_children(Resets.valid_reset)

    self.children.each do |reset|

      reset.parse
      @errors += reset.errors

      # This relates to attaching equip and inventory resets to mob resets,
      # and container resets to objects
      case reset.type
      when :mobile
        @recent_mob_reset = reset
        @previous_reset_type = :mobile
        if @reset_counts[reset.vnum] >= reset.limit
          warn(reset.line_number, reset.line, Resets.err_msg(:reset_limit, reset.limit, @reset_counts[reset.vnum]))
        end
        @reset_counts[reset.vnum] += 1

      when :equipment
        if @recent_mob_reset
          if @recent_mob_reset.attachments.any? { |el| el.target == reset.target && el.slot == reset.slot}
            err(reset.line_number, reset.line, Resets.err_msg(:wear_loc_filled))
          end
          @recent_mob_reset.attachments << reset
        end
        unless @previous_reset_type == :mobile
          warn(reset.line_number, reset.line, Resets.err_msg(:reset_doesnt_follow_mob, "Equipment"))
        end

      when :inventory
        @recent_mob_reset.attachments << reset if @recent_mob_reset
        unless @previous_reset_type == :mobile
          warn(reset.line_number, reset.line, Resets.err_msg(:reset_doesnt_follow_mob, "Inventory"))
        end

      else
        @previous_reset_type = :null
      end
    end

    verify_delimiter

    self.resets
  end

end

class Reset
  include Parsable

  @ERROR_MESSAGES = {
    invalid_reset: "Invalid reset (expecting M, G, E, O, P, D, R)",
    reset_m_matches: "Line should match: M 0 <vnum> <limit> <room>",
    reset_g_matches: "Line should match: G <0 or -#> <vnum> 0",
    reset_e_matches: "Line should match: E <0 or -#> <vnum> 0 <wear>",
    reset_o_matches: "Line should match: O 0 <vnum> 0 <room>",
    reset_p_matches: "Line should match: O 0 <vnum> 0 <room>",
    reset_d_matches: "Line should match: D 0 <room> <direction> <state>",
    reset_r_matches: "Line should match: R 0 <vnum> <number_of_exits>",
    negative: "%s can't be negative",
    zero_or_negative: "%s can't be 0 or negative",
    invalid_vnum: "Invalid %s VNUM",
    invalid_limit: "Invalid %s spawn limit",
    invalid_field: "Invalid %s",
    not_enough_tokens: "Not enough tokens on in %s reset line",
    wear_loc_out_of_bounds: "Wear location out of bounds 0 to #{WEAR_MAX}",
    door_out_of_bounds: "Door number out of bounds 0 to 5",
    bad_door_direction: "Invalid door direction",
    door_state_out_of_bounds: "Door state out of bounds 0 to 8",
    bad_door_state: "Invalid door state",
    number_of_exits: "Number of exits out of bounds 0 to 6",
    bad_number_of_exits: "Invalid number of exits"
  }

  attr_reader :line_number, :line, :vnum, :type, :target, :limit, :slot, :errors,
    :attachments

  def initialize(line, line_number=1)
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

  def to_s
    "<Reset: #{self.type}, #{self.vnum}, line #{self.line_number}>"
  end

  def parse
    @parsed = true

    if self.type == :invalid
      err(@line_number, @line, Reset.err_msg(:invalid_reset))
    else
      self.send("parse_#{self.type}")
    end
    self
  end

  def parse_mobile
    # Line syntax: M 0 mob_VNUM limit room_VNUM comments
    zero, vnum, limit, room, comment = line.split(" ", 6)[1..-1]
    unless [vnum, limit, room].any? { |el| el.nil? }

      unless zero =~ /^-?\d+$/
        err(@line_number, @line, Reset.err_msg(:reset_m_matches))
      end

      if vnum =~ /^-?\d+$/
        @vnum = vnum.to_i
        err(@line_number, @line, Reset.err_msg(:zero_or_negative, "Mob VNUM")) if @vnum < 1
      else
        err(@line_number, @line, Reset.err_msg(:invalid_vnum, "mob"))
      end

      if limit =~ /^-?\d+$/
        @limit = limit.to_i
        err(@line_number, @line, Reset.err_msg(:negative, "Mob limit")) if @limit < 0
      else
        err(@line_number, @line, Reset.err_msg(:invalid_limit, "mob"))
      end

      # Sometimes comments starting with * are smooshed up against the room vnum
      if room =~ /^-?\d+\*?$/
        @target = room[/^[^\*]*/].to_i
        err(@line_number, @line, Reset.err_msg(:negative, "Target spawn room")) if @target < 0
      else
        err(@line_number, @line, Reset.err_msg(:invalid_vnum, "room"))
      end

    else
      err(@line_number, @line, Reset.err_msg(:not_enough_tokens, "mob"))
    end

  end

  def parse_inventory
    # Line syntax: G <0 or -#> obj_VNUM 0
    limit, vnum, zero, comment = line.split(" ", 5)[1..-1]
    unless [limit, vnum, zero].any? { |el| el.nil? }

      if limit =~ /^-?\d+$/
        @limit = limit.to_i
      else
        err(@line_number, @line, Reset.err_msg(:invalid_limit, "inventory"))
      end

      if vnum =~ /^-?\d+$/
        @vnum = vnum.to_i
        err(@line_number, @line, Reset.err_msg(:negative, "Object VNUM")) if @vnum < 0
      else
        err(@line_number, @line, Reset.err_msg(:invalid_vnum, "object"))
      end

      # The zero doesn't actually need to be a zero, just needs to be there
      unless zero =~ /^-?\d+\*?$/
        err(@line_number, @line, Reset.err_msg(:reset_g_matches))
      end
    else
      err(@line_number, @line, Reset.err_msg(:not_enough_tokens, "inventory"))
    end
  end

  def parse_equipment
    # Line syntax: E <0 or -#> <vnum> 0 <wear>
    limit, vnum, zero, wear, comment = line.split(" ", 6)[1..-1]
    unless [limit, vnum, zero, wear].any? { |el| el.nil? }

      if limit =~ /^-?\d+$/
        @limit = limit.to_i
      else
        err(@line_number, @line, Reset.err_msg(:invalid_limit, "equipment"))
      end

      if vnum =~ /^-?\d+$/
        @vnum = vnum.to_i
        err(@line_number, @line, Reset.err_msg(:negative, "Object VNUM")) if @vnum < 0
      else
        err(@line_number, @line, Reset.err_msg(:invalid_vnum, "object"))
      end

      # The zero doesn't need to be a zero, it just needs to be there
      unless zero =~ /^-?\d+$/
        err(@line_number, @line, Reset.err_msg(:reset_e_matches))
      end

      if wear =~ /^-?\d+\*?$/
        @slot = wear[/[^\*]*/].to_i
        err(@line_number, @line, Reset.err_msg(:wear_loc_out_of_bounds)) unless @slot.between?(0,WEAR_MAX)
      else
        err(@line_number, @line, Reset.err_msg(:invalid_field, "wear location"))
      end
    else
      err(@line_number, @line, Reset.err_msg(:not_enough_tokens, "equipment"))
    end
  end

  def parse_object
    # Line syntax: O 0 <vnum> 0 <room>
    zero, vnum, zero_two, room, comment = line.split(" ", 6)[1..-1]
    unless [zero, vnum, zero_two, room].any? { |el| el.nil? }

      # MOOOOOOON ZEEEERO TWOOOOOO!
      unless zero =~ /^-?\d+$/ && zero_two =~ /^-?\d+$/
        err(@line_number, @line, Reset.err_msg(:reset_o_matches))
      end

      if vnum =~ /^-?\d+$/
        @vnum = vnum.to_i
        err(@line_number, @line, Reset.err_msg(:negative, "Object VNUM")) if @vnum < 0
      else
        err(@line_number, @line, Reset.err_msg(:invalid_vnum, "object"))
      end

      if room =~ /^-?\d+\*?$/
        @target = room[/[^\*]*/].to_i
        err(@line_number, @line, Reset.err_msg(:negative, "Target room VNUM")) if @target < 0
      else
        err(@line_number, @line, Reset.err_msg(:invalid_vnum, "room"))
      end
    else
      err(@line_number, @line, Reset.err_msg(:not_enough_tokens, "object"))
    end
  end

  def parse_container
    # Line syntax: P 0 <vnum> 0 <container>
    zero, vnum, zero_two, container, comment = line.split(" ", 6)[1..-1]
    unless [zero, vnum, zero_two, container].any? { |el| el.nil? }

      # MOOOOOOON ZEEEERO TWOOOOOO!
      unless zero =~ /^-?\d+$/ && zero_two =~ /^-?\d+$/
        err(@line_number, @line, Reset.err_msg(:reset_p_matches))
      end

      if vnum =~ /^-?\d+$/
        @vnum = vnum.to_i
        err(@line_number, @line, Reset.err_msg(:negative, "Object VNUM")) if @vnum < 0
      else
        err(@line_number, @line, Reset.err_msg(:invalid_vnum, "object"))
      end

      if container =~ /^-?\d+\*?$/
        @target = container[/^[^*]*/].to_i
        err(@line_number, @line, Reset.err_msg(:negative, "Target container VNUM")) if @target < 0
      else
        err(@line_number, @line, Reset.err_msg(:invalid_vnum, "container"))
      end
    else
      err(@line_number, @line, Reset.err_msg(:not_enough_tokens, "container"))
    end
  end

  def parse_door
    # Line syntax: D 0 <room> <direction> <state>
    zero, vnum, direction, state, comment = line.split(" ", 6)[1..-1]

    unless [zero, vnum, direction, state].any? { |el| el.nil? }

      unless zero =~ /\A\d+\z/
        err(@line_number, @line, Reset.err_msg(:reset_d_matches))
      end

      if vnum =~ /^-?\d+$/
        @vnum = vnum.to_i
        err(@line_number, @line, Reset.err_msg(:negative, "Room VNUM")) if @vnum < 0
      else
        err(@line_number, @line, Reset.err_msg(:invalid_vnum, "room"))
      end

      if direction =~ /^-?\d+$/
        @target = direction.to_i
        err(@line_number, @line, Reset.err_msg(:door_out_of_bounds)) unless @target.between?(0,5)
      else
        err(@line_number, @line, Reset.err_msg(:bad_door_direction))
      end

      if state =~ /^-?\d+\*?$/
        @slot = state[/^[^\*]*/].to_i
        err(@line_number, @line, Reset.err_msg(:door_state_out_of_bounds)) unless @slot.between?(0,8)
      else
        err(@line_number, @line, Reset.err_msg(:bad_door_state))
      end
    else
      err(@line_number, @line, Reset.err_msg(:not_enough_tokens, "door"))
    end
  end

  def parse_random
    # Line syntax: R 0 vnum number_of_exits
    # drop the leading R and the comment
    zero, vnum, number_of_exits, comment = line.split(" ", 5)[1..-1]
    unless [zero, vnum, number_of_exits].any? { |el| el.nil? }

      unless zero =~ /^-?\d+$/
        err(@line_number, @line, Reset.err_msg(:reset_r_matches))
      end

      if vnum =~ /^-?\d+$/
        @vnum = vnum.to_i
        err(@line_number, @line, Reset.err_msg(:negative, "Room VNUM")) if @vnum < 0
      else
        err(@line_number, @line, Reset.err_msg(:invalid_vnum, "room"))
      end

      if number_of_exits =~ /^-?\d+\*?$/
        @slot = number_of_exits.to_i
        err(@line_number, @line, Reset.err_msg(:number_of_exits)) unless @slot.between?(0,6)
      else
        err(@line_number, @line, Reset.err_msg(:bad_number_of_exits))
      end
    else
      err(@line_number, @line, Reset.err_msg(:not_enough_tokens, "random"))
    end
  end

end
