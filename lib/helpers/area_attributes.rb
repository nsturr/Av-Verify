module AreaAttributes

  #AREA
  def name
    s = get_section("area")
    s ? s.name : nil
  end

  def author
    s = get_section("area")
    s ? s.author : nil
  end

  def level
    s = get_section("area")
    s ? s.level : nil
  end

  #AREADATA

  def plane
    s = get_section("areadata")

  end

  def zone
    s = get_section("areadata")

  end

  def sector
    zone
  end

  def flags
    s = get_section("areadata")

  end

  #outlawy stuff here

  def kspawn
    s = get_section("areadata")

  end

  def modifications
    s = get_section("areadata")

  end

  def group_exp
    s = get_section("areadata")

  end

  # the regular sections

  def helps
    s = get_section("helps")
    s.help_files
  end

  def mobiles
    s = get_section("mobiles")
    s.mobiles
  end

  def objects
    s = get_section("objects")
    s.objects
  end

  def rooms
    s = get_section("rooms")
    s.rooms
  end

  def resets
    s = get_section("resets")
    s.resets
  end

  def shops
    s = get_section("shops")
    s.shops
  end

  def specials
    s = get_section("specials")
    s.specials
  end

end
