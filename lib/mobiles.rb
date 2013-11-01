require_relative "vnum_section.rb"
require_relative "modules/tilde.rb"

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

class Mobile
  include Parsable
  include TheTroubleWithTildes

  attr_reader :line_number, :vnum, :name, :short_desc, :long_desc,
    :description, :act, :aff, :align, :level, :sex, :race, :class,
    :apply, :team, :kspawn

  def initialize(contents, line_number=1)
    @contents = contents
    @line_number = line_number

    puts "#{contents[/\A.*$/]} : #{line_number}"
  end

  def parse

  end

end
