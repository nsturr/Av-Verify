# This gives Area its getters.
#
# @main_sections is a hash keyed by id string
#
# Some of the getters return the section object itself by just
# returning the value of the hash at a certain index.
# Other getters (specifically the ones at the top) try to grab
# a specific value out of a section object, returning nil if
# the section doesn't exist.
#
# All the getters cache their section if it is found.

module AreaAttributes

  #AREA
  def name
    unless @name
      s = self.sections_by_name["area"]
      @name = s ? s.name : nil
    end
    @name
  end

  def author
    unless @author
      s = self.sections_by_name["area"]
      @author = s ? s.author : nil
    end
    @author
  end

  def level
    unless @level
      s = self.sections_by_name["area"]
      @level = s ? s.level : nil
    end
    @level
  end

  #AREADATA

  def plane
    unless @plane
      s = self.sections_by_name["areadata"]
      @plane = s ? s.plane : nil
    end
    @plane
  end

  def zone
    unless @zone
      s = self.sections_by_name["areadata"]
      @zone = s ? s.zone : nil
    end
    @zone
  end

  def sector
    zone
  end

  def flags
    unless @flags
      s = self.sections_by_name["areadata"]
      @flags = s ? s.flags : nil
    end
    @flags
  end

  def outlaw
    unless @outlaw
      s = self.sections_by_name["areadata"]
      @outlaw = s ? s.outlaw : nil
    end
    @outlaw
  end

  def seeker
    unless @seeker
      s = self.sections_by_name["areadata"]
      @seeker = s ? s.kspawn : nil
    end
    @seeker
  end

  def modifiers
    unless @modifiers
      s = self.sections_by_name["areadata"]
      @modifiers = s ? k.modifiers : nil
    end
    @modifiers
  end

  def group_exp
    unless @group_exp
      s = self.sections_by_name["areadata"]
      @group_exp = s ? k.group_exp : nil
    end
    @group_exp
  end

  # the regular sections

  def helps
    @helps ||= self.sections_by_name["helps"]
    @helps ? @helps.help_files : nil
  end

  def mobiles
    @mobiles ||= self.sections_by_name["mobiles"]
  end

  def objects
    @objects ||= self.sections_by_name["objects"]
  end

  def rooms
    @rooms ||= self.sections_by_name["rooms"]
  end

  def resets
    @resets ||= self.sections_by_name["resets"]
  end

  def shops
    @shops ||= self.sections_by_name["shops"]
    # @resets ? @resets.resets : nil
  end

  def specials
    @specials ||= self.sections_by_name["specials"]
    # @specials ? @specials.specials : nil
  end

end
