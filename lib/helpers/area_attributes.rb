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
      s = self.main_sections["area"]
      @name = s ? s.name : nil
    end
    @name
  end

  def author
    unless @author
      s = self.main_sections["area"]
      @author = s ? s.author : nil
    end
    @author
  end

  def level
    unless @level
      s = self.main_sections["area"]
      @level = s ? s.level : nil
    end
    @level
  end

  #AREADATA

  def plane
    unless @plane
      s = self.main_sections["areadata"]
      @plane = s ? s.plane : nil
    end
    @plane
  end

  def zone
    unless @zone
      s = self.main_sections["areadata"]
      @zone = s ? s.zone : nil
    end
    @zone
  end

  def sector
    zone
  end

  def flags
    unless @flags
      s = self.main_sections["areadata"]
      @flags = s ? s.flags : nil
    end
    @flags
  end

  def outlaw
    unless @outlaw
      s = self.main_sections["areadata"]
      @outlaw = s ? s.outlaw : nil
    end
    @outlaw
  end

  def seeker
    unless @seeker
      s = self.main_sections["areadata"]
      @seeker = s ? s.kspawn : nil
    end
    @seeker
  end

  def modifiers
    unless @modifiers
      s = self.main_sections["areadata"]
      @modifiers = s ? k.modifiers : nil
    end
    @modifiers
  end

  def group_exp
    unless @group_exp
      s = self.main_sections["areadata"]
      @group_exp = s ? k.group_exp : nil
    end
    @group_exp
  end

  # the regular sections

  def helps
    @helps ||= self.main_sections["helps"]
    @helps ? @helps.help_files : nil
  end

  def mobiles
    @mobiles ||= self.main_sections["mobiles"]
  end

  def objects
    @objects ||= self.main_sections["objects"]
  end

  def rooms
    @rooms ||= self.main_sections["rooms"]
  end

  def resets
    @resets ||= self.main_sections["resets"]
  end

  def shops
    @shops ||= self.main_sections["shops"]
    # @resets ? @resets.resets : nil
  end

  def specials
    @specials ||= self.main_sections["specials"]
    # @specials ? @specials.specials : nil
  end

end
