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
    # unless @helps
    #   s = @main_sections["helps"]
    #   @helps = s ? s.help_files : nil
    # end
    @helps ||= @main_sections["helps"]
    @helps ? @helps.help_files : nil
  end

  def mobiles
    # unless @mobiles
    #   s = @main_sections["mobiles"]
    #   @mobiles = s #? s.mobiles : nil
    # end
    @mobiles ||= @main_sections["mobiles"]
  end

  def objects
    # unless @objects
    #   s = @main_sections["objects"]
    #   @objects = s ? s.objects : nil
    # end
    @objects ||= @main_sections["objects"]
  end

  def rooms
    # unless @rooms
    #   s = @main_sections["rooms"]
    #   @rooms = s ? s.rooms : nil
    # end
    @rooms ||= @main_sections["rooms"]
  end

  def resets
    # unless @resets
    #   s = @main_sections["resets"]
    #   @resets = s ? s.resets : nil
    # end
    @resets ||= @main_sections["resets"]
    @resets ? @resets.resets : nil
  end

  def shops
    # unless @shops
    #   s = @main_sections["shops"]
    #   @shops = s ? s.shops : nil
    # end
    @shops ||= @main_sections["shops"]
    @resets ? @resets.resets : nil
  end

  def specials
    # unless @specials
    #   s = @main_sections["specials"]
    #   @specials = s ? s.specials : nil
    # end
    @specials ||= @main_sections["specials"]
    @specials ? @specials.specials : nil
  end

end
