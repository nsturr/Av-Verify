module CorrelateSections

  def correlate_all

  end

  def correlate(section)

    s = get_section(section)
    return if s.nil?

    case s.id
    when "mobiles"
    when "objects"
    when "rooms"
    when "resets"
    when "shops"
    when "specials"

  end

  def correlate_resets(resets, mobiles, objects, rooms)

    skipped_mobs, skipped_objects, skipped_rooms = 0, 0, 0

    # Here is yon scoop:
    # If there's no mobs/objects/rooms section in the area, their parameters
    # in this method will be nil. The correlate_whatever method checks for it
    # being nil, and if so returns a 1, otherwise it does its thing and returns
    # a 0.
    #
    # That result is added to skipped_whatever, and after all the checking is
    # complete we can post a N.B. saying "Since the section wasn't in the area,
    # we didn't check N resets to see if they pointed to something in the area."

    resets.each do |reset|
      case reset.type
      when :mobile
        skipped_mobs += correlate_mob_reset_vnum(reset, mobiles)
        skipped_rooms += correlate_mob_reset_room(reset, rooms)
      when :inventory
        skipped_objects += correlate_obj_reset_vnum(reset, objects)
      when :equipment
        skipped_objects += correlate_obj_reset_vnum(reset, objects)
      when :object
        skipped_objects += correlate_obj_reset_vnum(reset, objects)
        skipped_rooms += correlate_obj_reset_room(reset, rooms)
      when :container
        skipped_objects += correlate_obj_reset_vnum(reset, objects)
        skipped_objects += correlate_container(reset, objects)
      when :door
        skipped_rooms += correlate_door_reset(reset, rooms)
      when :random
        skipped_rooms += correlate_random_reset(reset, rooms)
      end
    end

    nb(resets.line_number, nil, "No MOBILES section in area, #{skipped_mobs} mob references in RESETS skipped")
    nb(resets.line_number, nil, "No OBJECTS section in area, #{skipped_objs} object references in RESETS skipped")
    nb(resets.line_number, nil, "No ROOMS section in area, #{skipped_rooms} room references in RESETS skipped")
  end

  def correlate_shops(shops, mobiles)
    if mobiles.nil?
      warn(shops.line_number, nil, "No MOBILES section in area, can't check shopkeeper VNUMs")
      return
    end

  end

  def correlate_specials(specials, mobiles)
    if mobiles.nil?
      warn(specials.line_number, nil, "No MOBILES section in area, can't check spec_fun VNUMs")
      return
    end
  end

  private

  def correlate_mob_reset_vnum(reset, mobiles)
    return 1 if mobiles.nil?
    unless mobiles.key? reset.vnum
      warn(reset.line_number, reset.line, "Mobile to spawn is not in the area")
    end
    0
  end

  def correlate_mob_reset_room(reset, rooms)
    return 1 if rooms.nil?
    unless rooms.key? reset.target
      warn(reset.line_number, reset.line, "Mobile spawn location is not in the area")
    end
    0
  end

  def correlate_obj_reset_vnum(reset, objects)
    return 1 if objects.nil?
    unless objects.key? reset.vnum
      warn(reset.line_number, reset.line, "Object to spawn is not in the area")
    end
    0
  end

  def correlate_obj_reset_room(reset, rooms)
    return 1 if rooms.nil?
    unless rooms.key? reset.target
      warn(reset.line_number, reset.line, "Object spawn location is not in the area")
    end
    0
  end

  def correlate_container_reset(reset, objects)
    return 1 if objects.nil?
    unless objects.key? reset.target
      warn(reset.line_number, reset.line, "Object spawn container is not in the area")
    end
    0
  end

  def correlate_door_reset(reset, rooms)
    return 1 if rooms.nil?
    if rooms.key?(reset.vnum) == false
      err(reset.line_number, reset.line, "Door reset's room is not in the area")
    elsif rooms[reset.vnum][:doors].nil?
      err(reset.line_number, reset.line, "Door reset's room does not have this exit")
    elsif rooms[reset.vnum][:doors][reset.target].nil?
      err(reset.line_number, reset.line, "Door reset's room does not have this exit")
    elsif rooms[reset.vnum][:doors][reset.target][:lock] == 0
      err(reset.line_number, reset.line, "Door reset targets an exit with no door")
    end
    0
  end

  def correlate_random_reset(reset, rooms)
    return 1 if rooms.nil?
    unless rooms.key? reset.vnum
      err(reset.line_number, reset.line, "Room to randomize isn't in the area")
    end
    0
  end

end
