module AreaAttributes

  #AREA
  def name
    unless @name
      s = @main_sections["area"]
      @name = s ? s.name : nil
    end
    @name
  end

  def author
    unless @author
      s = @main_sections["area"]
      @author = s ? s.author : nil
    end
    @author
  end

  def level
    unless @level
      s = @main_sections["area"]
      @level = s ? s.level : nil
    end
    @level
  end

  #AREADATA

  def plane
    unless @plane
      s = @main_sections["areadata"]
      @plane = s ? s.plane : nil
    end
    @plane
  end

  def zone
    unless @zone
      s = @main_sections["areadata"]
      @zone = s ? s.zone : nil
    end
    @zone
  end

  def sector
    zone
  end

  def flags
    unless @flags
      s = @main_sections["areadata"]
      @flags = s ? s.flags : nil
    end
    @flags
  end

  def outlaw
    unless @outlaw
      s = @main_sections["areadata"]
      @outlaw = s ? s.outlaw : nil
    end
    @outlaw
  end

  def seeker
    unless @seeker
      s = @main_sections["areadata"]
      @seeker = s ? s.kspawn : nil
    end
    @seeker
  end

  def modifiers
    unless @modifiers
      s = @main_sections["areadata"]
      @modifiers = s ? k.modifiers : nil
    end
    @modifiers
  end

  def group_exp
    unless @group_exp
      s = @main_sections["areadata"]
      @group_exp = s ? k.group_exp : nil
    end
    @group_exp
  end

  # the regular sections

  def helps
    @helps ||= @main_sections["helps"]
    @helps ? @helps.help_files : nil
  end

  def mobiles
    @mobiles ||= @main_sections["mobiles"]
  end

  def objects
    @objects ||= @main_sections["objects"]
  end

  def rooms
    @rooms ||= @main_sections["rooms"]
  end

  def resets
    @resets ||= @main_sections["resets"]
  end

  def shops
    @shops ||= @main_sections["shops"]
    @resets ? @resets.resets : nil
  end

  def specials
    @specials ||= @main_sections["specials"]
    @specials ? @specials.specials : nil
  end

end
