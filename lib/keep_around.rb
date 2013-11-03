def parse_room(section, line_num)
  first_line = section.slice!(/\A.*?\n/).chomp #Slice off #VNUM

  current_line = line_num # Keep track of areafile line.

  if section.strip.empty? || first_line.nil?
    err(current_line, nil, "Mobile definition is empty!")
    return
  end

  vnum = first_line.match(/(\d+)/)[1].to_i

  if @rooms.key?(vnum)
    err(line_num, nil, "Duplicate room ##{vnum}, first appears on line #{@rooms[vnum][:line]}")
    return # If room is a dupe, no need to continue parsing it
  end
  err(line_num, first_line, "Invalid text on same line as VNUM") unless first_line =~ /^#\d+\s*$/

  room = Room.new(line_num, vnum) # This will eventually get added to the area's hash of rooms
  exits = {}
  exit = nil # Temporary var for an Exit object

  current_line = line_num + 1 # Keep track of areafile line. +1 because we've skipped #VNUM

  # List of each type of line we can parse in an object section.
  expectation = [ :name, :desc, :flags_sector, :misc, :door_desc,
                  :door_kword, :door_locks, :ekeyword, :edesc ]
  # This is an index for the previous array. Gets incremented as we proceed through
  # the lines of the section. expectation[expect] detemines what we'll try to parse
  expect = 0

  # Line number where the most recent multi-line field started
  last_multiline = nil

  # True when extra fields are parsed, after which door fields will be invalid
  #past_doors = false

  # True when the S line is found, indicating that the room section is ending
  section_end = false

  section.each_line do |line|
    line.rstrip!

    # First check to make sure that we haven't found the designated end of the room
    if section_end && line =~ /\S/
      err(current_line, line, "Room continues after its terminating S line")
      return # Return, because every subsequent line will just throw the same error
    end

    case expectation[expect]
    when :name
      if line.empty?
        err(current_line, nil, "Invalid blank line in room name")
        current_line += 1
        next
      end
      expect += 1
      if m = line.match(/^([^~]*)~$/)
        room[:name] = m[1]
      elsif line =~ /~./
        err(current_line, line, "Invalid text after terminating ~")
      else
        err(current_line, line, "Room name lacks terminating ~ or spans multiple lines")
      end
    when :desc
      ugly(current_line, line, "Visible text contains a tab character") if line.include?("\t")
      # If this line matches, it's practically guaranteed that we've left the description
      # and entered the next field due to lack of ~
      if line =~ /^\d+ +#{Bits.insert} +\d+ *$/
        err(current_line, line, "This doesn't look like part of a description. Forget a terminating ~ above?")
        expect += 1
        redo
      end
      # Basically ignore every line of the description that doesn't have a ~ in it
      if line.end_with?("~")
        expect += 1
        ugly(current_line, line, "Room desc terminating ~ should be on its own line.") if line.length > 1
      elsif line =~ /~./
        err(current_line, line, "Room desc continues after terminating ~")
        expect += 1
      end
    when :flags_sector
      if line.empty?
        err(current_line, nil, "Invalid blank line in room definition")
        current_line += 1
        next
      end
      expect += 1
      items = line.split
      err(current_line, line, "Too many fields on roomflag/sector line") if items.length > 3
      if items[1] =~ Bits.pattern
        err(current_line, line, "Room flag is not a power of 2") if Bits.new(items[1]).error?
      else
        err(current_line, line, "Invalid roomflag field")
      end
      if items[2] =~ /\d+\b/
        err(current_line, line, "Room sector out of bounds 0 to #{SECTOR_MAX}") unless items[2].to_i.between?(0, SECTOR_MAX)
      else
        err(current_line, line, "Invalid sector field")
      end
    when :misc
      if line.empty? && section_end == false
        err(current_line, nil, "Invalid blank line in room definition")
        current_line += 1
        next
      end
      if line.start_with?("D")
        #err(current_line, line, "Door field occurs after extra fields") if past_doors
        if m = line.match(/^D(\d+)/)
          expect += 1
          last_multiline = current_line + 1 #Next line begins a multiline field
          direction = m[1].to_i

          exit = Exit.new(direction)

          err(current_line, line, "Duplicate exit direction in room") unless exits[direction].nil?
          err(current_line, line, "Invalid text after exit header") unless line =~ /^D\d+$/
          err(current_line, line, "Invalid exit direction") unless direction.between?(0,5)
        else
          err(current_line, line, "Invalid field (expecting D#, A, C, E, or S)")
        end
      elsif line.start_with?("A")
        if m = line.match(/^A +(#{Bits.insert})/)
          #past_doors = true
          align_excl = Bits.new(m[1])
          room[:align_excl] = align_excl.to_a
          err(current_line, line, "Alignment restriction flag is not a power of 2") if align_excl.error?
          err(current_line, line, "Invalid text after room alignment restriction") unless line =~ /^A +#{Bits.insert}$/
        else
          err(current_line, line, "Invalid alignment restriction line")
        end
      elsif line.start_with?("C")
        if m = line.match(/^C +(#{Bits.insert})/)
          #past_doors = true
          class_excl = Bits.new(m[1])
          room[:class_excl] = class_excl.to_a
          err(current_line, line, "Class restriction flag is not a power of 2") if class_excl.error?
          err(current_line, line, "Invalid text after room class restriction") unless line =~ /^C +#{Bits.insert}$/
        else
          err(current_line, line, "Invalid class restriction line")
        end
      elsif line.start_with?("E")
        if line.length == 1
          #past_doors = true
          expect += 4 #Expect a keyword line next
        else
          err(current_line, line, "Invalid field (expecting D#, A, C, E, or S)")
        end
      elsif line.start_with?("S")
        if expectation[expect] == :edesc || expectation[expect] == :door_desc
          err(current_line, nil, "Extra/door desc lacks terminating ~ between lines #{last_multiline} and #{current_line}")
        end
        section_end = true
        err(current_line, line, "Invalid text after terminating S") unless line =~ /^S$/
      elsif section_end == false
        err(current_line, line, "Invalid field (expecting D#, A, C, E, or S)")
      end
    when :door_desc
      if line.empty?
        current_line += 1
        next
      end
      ugly(current_line, line, "Visible text contains a tab character") if line.include?("\t")
      # Basically ignore every line of the description that doesn't have a ~ in it
      if line.end_with?("~")
        expect += 1
        ugly(current_line, line, "Door desc terminating ~ should be on its own line.") if line.length > 1
      elsif line =~ /~./
        err(current_line, line, "Door desc continues after terminating ~")
        expect += 1
      end
    when :door_kword
      if line.empty?
        err(current_line, nil, "Invalid blank line in room exit keywords")
        current_line += 1
        next
      end
      expect += 1
      if line =~ /^[^~]*~$/
        #
      elsif line =~ /~./
        err(current_line, line, "Invalid text after terminating ~")
      else
        err(current_line, line, "Door keywords lack terminating ~ or spans multiple lines")
      end
    when :door_locks
      expect -= 3 # Go back to expecting a misc line
      items = line.split
      # Make sure the right number of items are on the line
      if items.length == 3
        if items[0] =~ /^\d+$/
          exit[:lock] = items[0].to_i unless exit.nil?
          err(current_line, line, "Door lock type out of bounds 0 to #{LOCK_MAX}") unless items[0].to_i.between?(0,LOCK_MAX)
        else
          err(current_line, line, "Invalid door lock field")
        end
        if items[1] =~ /^-1$|^\d+$/
          # Valid values for keys are -1, 0, or any positive number.
          exit[:key] = items[1].to_i unless exit.nil?
        else
          err(current_line, line, "Invalid door key field")
        end
        if items[2] =~ /^-1$|^\d+$/
          # Valid values for destinations are -1, or any positive number.
          exit[:dest] = items[2].to_i unless exit.nil?
        else
          err(current_line, line, "Invalid door destination field")
        end
        exits[exit[:dir]] = exit if exits[exit[:dir]].nil?
        exit = nil
      else
        err(current_line, line, "Invalid door locks line")
      end
    when :ekeyword
      if line.empty?
        err(current_line, nil, "Room edesc keywords span multiple lines")
        current_line += 1
        next
      end
      expect += 1
      # Mark the following line as the start of a multiline field
      last_multiline = current_line + 1
      if line =~ /^[^~]*~$/
        #
      elsif line =~ /~./
        err(current_line, line, "Invalid text after terminating ~")
      else
        err(current_line, line, "Edesc keywords lack terminating ~ or spans multiple lines")
      end
    when :edesc
      ugly(current_line, line, "Visible text contains a tab character") if line.include?("\t")
      # Basically ignore every line of the description that doesn't have a ~ in it
      if line.end_with?("~")
        expect -= 5
        ugly(current_line, line, "Room edesc terminating ~ should be on its own line.") if line.length > 1
      elsif line =~ /~./
        err(current_line, line, "Room edesc continues after terminating ~")
        expect -= 5
      end
    end
    current_line += 1
  end

  err(current_line, nil, "Edesc lacks terminating ~ between lines #{last_multiline} and #{current_line}") if expectation[expect] == :edesc
  err(current_line, nil, "Room section lacks terminating S") unless section_end

  room[:exits] = exits unless exits.empty?

  @rooms[vnum] = room
end


def parse_section_resets(section)

    current_line = section[:line]
    # Set to true when the "S" line is detected
    section_end = false
    # Set to the vnum of the most recent mob loaded. Since it starts as nil,
    # G, E, and O resets can tell if any mob has been loaded yet (and throw
    # errors if not)
    current_mob = nil
    equip_slots = []

    section[:data].each_line do |line|
      line.rstrip!

      if section_end && !line.empty?
        err(current_line, line, "Section continues after its terminating S line")
        return # Because it'll only keep throwing this error over and over again
      end

      # This detects comments beginning with *
      # Comments don't need a starting char if they occur after a reset or special
      if line =~ /^\s*\*/
        current_line += 1
        next
      end

      # N.B. a lot of the regexp have '\*?' in them. Sometimes comments starting with *
      # get smooshed up against the last number in the line, and it would otherwise
      # throw an error.
      case line[0..1]
      when "M "
        current_mob = true # This is to signify that a mob is at least trying to be loaded
        equip_slots = [] # Clear equip reset history for the new mob
        # Line syntax: M 0 mob_VNUM limit room_VNUM comments
        items = line.split(" ", 6)
        if items.length >= 5 # Comments are optional
          mob_reset = Reset.new(current_line, :mobile)
          # Items[0] is just the leading M, so ignore it
          #err(current_line, line, "First token of mob reset should be a 0") unless items[1] == "0"
          # Parse the Mob VNUM
          if m = items[2].match(/^(-?\d+)$/)
            mob_vnum = m[1].to_i
            err(current_line, line, "Mob VNUM can't be 0 or negative") if mob_vnum < 1
            current_mob = mob_vnum
            mob_reset[:vnum] = mob_vnum
          else
            err(current_line, line, "Invalid mob VNUM")
          end
          # Parse the Mob Limit
          if m = items[3].match(/^(-?\d+)$/)
            spawn_limit = m[1].to_i
            err(current_line, line, "Mob limit can't be negative") if spawn_limit < 0
            mob_reset[:limit] = spawn_limit
          else
            err(current_line, line, "Invalid mob limit")
          end
          # Parse the target Room. Some comments starting with * are smooshed up
          # against the vnum, btw
          if m = items[4].match(/^(-?\d+)\*?$/)
            target = m[1].to_i
            err(current_line, line, "Target spawn room can't be negative") if target < 0
          else
            err(current_line, line, "Invalid room VNUM")
          end
        else
          err(current_line, line, "Not enough tokens on in mob reset line")
        end
        @resets << mob_reset
        if @reset_count[mob_vnum] >= mob_reset[:limit]
          warn(current_line, line, "Mob reset limit is #{mob_reset[:limit]}, but #{@reset_count[mob_vnum]} mobs load before it.")
        end
        @reset_count[mob_vnum] += 1
        # Throw an error if this mobile spawns in a room not in the area, but only if
        # the hash isn't empty (in which case the section probably hasn't been parsed)
        warn(current_line, line, "Mobile's spawn location is not in the area") unless @rooms.key?(target) || @rooms.empty?
        warn(current_line, line, "Mobile to spawn is not in the area") unless @mobiles.key?(mob_vnum) || @mobiles.empty?
      when "G "
        # Line syntax: G <0 or -#> obj_VNUM 0
        err(current_line, line, "G reset occurs before any mob has been loaded") unless current_mob
        items = line.split(" ", 5)
        if items.length >= 4
          # Items[0] is just the leading G, so ignore it
          # Parse the limit. Can be 0 or a negative number
          if m = items[1].match(/^(-?\d+)$/)
            spawn_limit = m[1].to_i
            #err(current_line, line, "Inventory spawn limit out of bounds 0 or -2 and lower") if spawn_limit > 0
            #err(current_line, line, "Inventory spawn limit out of bounds 0 or -2 and lower") if spawn_limit == -1
          else
            err(current_line, line, "Invalid inventory spawn limit")
          end
          # Parse the object VNUM
          if m = items[2].match(/^(-?\d+)$/)
            obj_vnum = m[1].to_i
            err(current_line, line, "Object VNUM can't be negative") if obj_vnum < 0
            # Throw an error if this object to spawn is not in the area, but only if
            # the hash isn't empty (in which case the section probably hasn't been parsed)
            warn(current_line, line, "Object to spawn is not in the area") unless @objects.key?(obj_vnum) || @objects.empty? || known_vnum(obj_vnum)
          else
            err(current_line, line, "Invalid object VNUM")
          end
          # Parse the trailing 0
          #err(current_line, line, "Last token of inventory reset must be a 0") unless items[3] == "0"
        else
          err(current_line, line, "Not enough tokens in inventory reset line")
        end
      when "E "
        err(current_line, line, "E reset occurs before any mob has been loaded") unless current_mob
        items = line.split(" ", 6)
        if items.length >= 5
          # Items[0] is just the leading E, so ignore it
          # Parse the limit. Can be 0 or a negative number
          if m = items[1].match(/^(-?\d+)$/)
            spawn_limit = m[1].to_i
            #err(current_line, line, "First token of equipment reset must be 0 or negative") if spawn_limit > 0
          else
            err(current_line, line, "Invalid first token")
          end
          # Parse the object VNUM
          if m = items[2].match(/^(-?\d+)$/)
            obj_vnum = m[1].to_i
            err(current_line, line, "Object VNUM can't be negative") if obj_vnum < 0
            # Throw an error if this object to spawn is not in the area, but only if
            # the hash isn't empty (in which case the section probably hasn't been parsed)
            warn(current_line, line, "Object to spawn is not in the area") unless @objects.key?(obj_vnum) || @objects.empty?  || known_vnum(obj_vnum)
          else
            err(current_line, line, "Invalid object VNUM")
          end
          # Parse the trailing 0
          #err(current_line, line, "Third token of inventory reset must be 0") unless items[3] == "0"
          # Parse the wear location
          if m = items[4].match(/^(-?\d+)\*?$/)
            wear_loc = m[1].to_i
            if equip_slots.include? wear_loc
              err(current_line, line, "Wear location already filled on this mob reset.")
            else
              equip_slots << wear_loc
            end
            err(current_line, line, "Wear location out of bounds 0 to #{WEAR_MAX}") unless wear_loc.between?(0,WEAR_MAX)
          else
            err(current_line, line, "Invalid wear location")
          end
        else
          err(current_line, line, "Not enough tokens in equipment reset line")
        end
      when "O "
        # Commenting out this warning because so many areas start with O resets
        # The warning will remain for E and G resets, though.
        # warn(current_line, line, "O reset occurs before any mob has been loaded") unless current_mob
        items = line.split(" ", 6)
        if items.length >= 5
          # Items[0] is just the leading O, so ignore it
          # Parse the first token, which should be a 0
          #err(current_line, line, "First token of object reset must be a 0") unless items[1] == "0"
          # Parse the object vnum
          if m = items[2].match(/^(-?\d+)$/)
            obj_vnum = m[1].to_i
            err(current_line, line, "Object VNUM can't be negative") if obj_vnum < 0
            warn(current_line, line, "Object to spawn is not in the area") unless @objects.key?(obj_vnum) || @objects.empty? || known_vnum(obj_vnum)
          else
            err(current_line, line, "Invalid object VNUM")
          end
          # Parse the third token, which should be a 0
          #err(current_line, line, "First token of object reset must be a 0") unless items[3] == "0"
          # Parse the target room vnum
          if m = items[4].match(/^(-?\d+)\*?$/)
            target = m[1].to_i
            err(current_line, line, "Target room VNUM can't be negative") if target < 0
            # Throw an error if this object spawns in a room not in the area, but only if
            # the hash isn't empty (in which case the section probably hasn't been parsed)
            warn(current_line, line, "Object's spawn location is not in the area") unless @rooms.key?(target) || @rooms.empty?
          else
            err(current_line, line, "Invalid target room VNUM")
          end
        else
          err(current_line, line, "Not enough tokens in object reset line")
        end
      when "P "
        items = line.split(" ", 6)
        if items.length >= 5
          # Items[0] is just the leading O, so ignore it
          # Parse the first token, which should be a 0
          #err(current_line, line, "First token of container reset must be a 0") unless items[1] == "0"
          # Parse the object vnum
          if m = items[2].match(/^(-?\d+)$/)
            obj_vnum = m[1].to_i
            err(current_line, line, "Object VNUM can't be negative") if obj_vnum < 0
            warn(current_line, line, "Object to spawn is not in the area") unless @objects.key?(obj_vnum) || @objects.empty? || known_vnum(obj_vnum)
          else
            err(current_line, line, "Invalid object VNUM")
          end
          # Parse the third token, which should be a 0
          #err(current_line, line, "First token of object reset must be a 0") unless items[3] == "0"
          # Parse the target container vnum
          if m = items[4].match(/^(-?\d+)\*?$/)
            target = m[1].to_i
            err(current_line, line, "Target container VNUM can't be negative") if target < 0
            # Throw an error if this object spawns in a container not in the area, but only
            # if the hash isn't empty (in which case the section probably hasn't been parsed)
            warn(current_line, line, "Object's spawn container is not in the area") unless @objects.key?(target) || @objects.empty?
          else
            err(current_line, line, "Invalid target container VNUM")
          end
        else
          err(current_line, line, "Not enough tokens in container reset line")
        end
      when "D "
        items = line.split(" ", 6)
        if items.length >= 5
          # Items[0] is just the leading D, so ignore it
          # Parse the first token, which should be a 0
          #err(current_line, line, "First token of door reset must be a 0") unless items[1] == "0"
          # Parse the target room number
          if m = items[2].match(/^(-?\d+)$/)
            target = m[1].to_i
            err(current_line, line, "Room VNUM can't be negative") if target < 0
          else
            err(current_line, line, "Invalid room VNUM")
          end
          # Parse the door number
          if m = items[3].match(/^(-?\d+)$/)
            dir = m[1].to_i
            err(current_line, line, "Door number out of bounds 0 to 5") unless dir.between?(0,5)
          else
            err(current_line, line, "Invalid door direction")
          end
          # Parse the door state
          if m = items[4].match(/^(-?\d+)\*?$/)
            state = m[1].to_i
            err(current_line, line, "Door state out of bounds 0 to 8") unless state.between?(0,8)
          else
            err(current_line, line, "Invalid door state")
          end
        else
          err(current_line, line, "Not enough tokens in door reset line")
        end
        if !@rooms.empty?
          # Treating this like a real error, because seriously when would you ever
          # reset a door from another area...
          if !@rooms.key?(target)
            err(current_line, line, "Door reset's room is not in the area")
          elsif @rooms[target][:exits].nil?
            err(current_line, line, "Door reset's room does not have this exit")
          elsif @rooms[target][:exits][dir].nil?
            err(current_line, line, "Door reset's room does not have this exit")
          elsif @rooms[target][:exits][dir][:lock] == 0
            err(current_line, line, "Door reset targets an ordinary exit with no door")
          end
        else
          err(current_line, line, "Door reset's room is not in the area")
        end
      when "R "
        items = line.split(" ", 5)
        if items.length >= 4
          # Items[0] is just the leading D, so ignore it
          # Parse the first token, which should be a 0
          #err(current_line, line, "First token of random reset must be a 0") unless items[1] == "0"
          # Parse the room vnum
          if m = items[2].match(/^(-?\d+)$/)
            target = m[1].to_i
            err(current_line, line, "Room VNUM can't be negative") if target < 0
          else
            err(current_line, line, "Invalid target room VNUM")
          end
          # Parse the number of exits
          if m = items[3].match(/^(-?\d+)\*?$/)
            num_exits = m[1].to_i
            err(current_line, line, "Number of exits out of bounds 0 to 6") unless num_exits.between?(0,6)
          else
            err(current_line, line, "Invalid number of exits")
          end
        else
          err(current_line, line, "Not enough tokens in random reset line")
        end
        err(current_line, line, "Room to randomize is not in the area") unless @rooms.key?(target) || @rooms.empty?
      when "S"
        section_end = true
        err(current_line, line, "Invalid text after terminating S") unless line.length == 1
      else
        err(current_line, line, "Invalid reset") unless line.empty?
      end
      current_line += 1
    end
  end

def parse_section_shops(section)
    # This section will be the death of me.
    # seriously, die in a fire, #shops

    expectation = [ :shopkeeper, :types, :profit, :time ]
    expect = 0

    current_line = section[:line]
    section_end = false

    section[:data].each_line do |line|
      line.rstrip!
      # if section_end && line =~ /\S/
      if section_end and not line.empty?
        err(current_line, line, "Section continues after terminating 0")
        return
      end
      
      # This section doesn't mind text after fields on the line
      case expectation[expect]
      when :shopkeeper
        if line == "0"
          section_end = true
        elsif m = line.match(/^(\d+)/)
          expect += 1
          warn(current_line, line, "Shopkeeper mobile is not in the area") unless @mobiles.key?(m[1].to_i) || @mobiles.empty?
        elsif line.empty?
          # Do nothing! Empty lines are great. Totally great. 
        else
          err(current_line, line, "Invalid shopkeeper VNUM")
        end
      when :types
        if line.empty?
          err(current_line, nil, "Invalid blank line inside shop")
          current_line += 1
          next
        end
        expect += 1
        items = line.split(" ", 6)
        if items.length >= 5
          0.upto(4).each do |i|
            err(current_line, line, "Invalid object type") unless items[i] =~ /^\d+$/
          end
        else
          err(current_line, line, "Not enough tokens in shop type line")
        end
      when :profit
        if line.empty?
          err(current_line, nil, "Invalid blank line inside shop")
          current_line += 1
          next
        end
        expect += 1
        items = line.split(" ", 3)
        if items.length >= 2
          if items[0] =~ /^-?\d+$/
            err(current_line, line, "Profit margin can't be negative") if items[0].to_i < 0
          else
            err(current_line, line, "Invalid profit margin")
          end
          if items[1] =~ /^-?\d+$/
            err(current_line, line, "Profit margin can't be negative") if items[1].to_i < 0
          else
            err(current_line, line, "Invalid profit margin")
          end
        else
          err(current_line, line, "Not enough tokens in profit line")
        end
      when :time
        if line.empty?
          err(current_line, nil, "Invalid blank line inside shop")
          current_line += 1
          next
        end
        expect = 0
        items = line.split(" ", 3)
        if items.length >= 2
          if items[0] =~ /^\d+$/
            err(current_line, line, "Hours out of bounds 0 to 23") unless items[0].to_i.between?(0,23)
          else
            err(current_line, line, "Invalid hour")
          end
          if items[1] =~ /^\d+$/
            err(current_line, line, "hours out of bounds 0 to 23") unless items[1].to_i.between?(0,23)
          else
            err(current_line, line, "Invalid hour")
          end
        else
          err(current_line, line, "Not enough tokens in hours line")
        end
      end
      current_line += 1
    end
  end
