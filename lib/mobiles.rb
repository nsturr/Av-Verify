require_relative "vnum_section.rb"
require_relative "modules/tilde.rb"
require_relative "line_by_line_object.rb"

class Mobiles < VnumSection

  @section_delimeter = "^#0\\b" # N.B. some valid vnums regrettably begin with a 0

  def self.child_class
    Mobile
  end

  def initialize(contents, line_number)
    super(contents, line_number)
    @name = "MOBILES"
  end

end

class Mobile < LineByLineObject

  LINES = [:vnum, :name, :short_desc, :long_desc, :description, :act, :aff,
    :align, :level, :sex, :race, :klass, :apply, :team, :kspawn]

  def self.LINES
    LINES
  end

  attr_reader(:line_number, *LINES)

  def parse_vnum
  end

  def parse_keywords
  end

  def parse_name
  end

  def parse_short_desc
  end

  def parse_long_desc
  end

  def parse_description
  end

  def parse_act
  end

  def parse_aff
  end

  def parse_align
  end

  def parse_level
  end

  def parse_sex
  end

  def parse_race
  end

  def parse_klass
  end

  def parse_apply
  end

  def parse_team
  end

  def parse_kspawn
  end

end
