#!/usr/bin/env ruby

# Avatar area file verifier by Scevine.
#
# This verifier depends on the input file having a minimum of proper
# formatting, i.e. #SECTIONs, #VNUMs, and delimiters starting on their
# own lines, text fields sticking to their own lines, etc. (You get
# this from the area builder anyway, so it shouldn't be an issue.)
#
# Usage: ruby varea.rb areafile.are [nowarning, cosmetic, nocolor]
#
# "Nowarning" suppresses non-critical errors, such as Loading a mob
# or object not in the area, which might be intentional.
#
# "Cosmetic"displays any cosmetic errors such as text fields lacking
# a newline at the end, lines containing tabs, etc.
#
# "Nocolor" strips ANSI color codes from the output, which is handy
# if you're piping the output away from the console.
#
# If "areafile" ends in the extension ".lst" then the file is interpreted
# as an arefile list, and every area listed inside will be verified at once.
#
# Send bugs and suggestions to the desert colossus, who dwells on the face of
# the Mesa of Eternity, awaking from its turbulent slumber only during solar
# eclipses to answer but a single question from a single pilgrim, and then
# either bestowing ultimate wisdom or smiting the unworthy.
# (Or nag Scevine ingame, whichever.)

# TODO:
#  Support a lack of spaces between number and text fields
#  Change some of the regexps to match tabs in addition to spaces
#    (Mostly in #AREADATA but also in class/race/etc lines)
#  When expecting door locks, properly interpret a single ~
#  Fix the tildes that get appended to the shifted-on text fields

require_relative 'helpers/avconstants'
require_relative 'helpers/bits'
require_relative 'helpers/avcolors'
require_relative 'helpers/parsable'
require_relative 'helpers/area_attributes'
require_relative 'helpers/correlate_sections'

%w{
  area_header area_data helps mobiles
  objects rooms resets shops specials
}.each { |section| require_relative "sections/#{section}" }

class Area
  include Parsable # bestows an errors getter
  include AreaAttributes # bestows getters for all its attributes
  include CorrelateSections

  attr_reader :main_sections, :flags

  def initialize(filename, flags=[])
    # How 'bout a little FILE, Scarecrow! >:D
    unless File.exist?(filename)
      puts "#{filename} not found, skipping."
      return nil
    end

    data = File.read(filename)
    total_lines = data.count("\n") + 1
    data.rstrip!

    @flags = flags.map {|item| item.downcase.to_sym}

    @errors = []

    if data.end_with?("\#$")
      # If the correct ending char is found, strip it completely so none of the
      # section-parsing methods have to worry about it
      data.slice!(-2..-1)
    else
      err(total_lines, nil, "Area file does not end with \#$")
    end

    @main_sections = extract_main_sections(data)
  end

  def get_section section
    if section.is_a? Symbol
      section = section.to_s
    end

    if section == "areaheader"
      self.main_sections["area"]
    elsif section.is_a? String
      section = section.downcase.gsub("_", "")
      self.main_sections[section]
    elsif section.is_a? Class
      self.main_sections.find { |_, s| s.class == section }
    end
  end

  def verify_all
    self.main_sections.each_value do |section|
      next if section.parsed?
      puts "Found ##{section.id} on line #{section.line_number}" if @flags.include?(:debug)
      section.parse
      @errors += section.errors
    end
  end

  def parse(id)

  end

  private

  def extract_main_sections(data)
    lines_so_far = 1

    separated = data.split(/^(?=#[a-zA-Z\$]+)/)
    sections = {}

    separated.each do |content|
      # Keep track of how many lines per section, so that the next section
      # has an accurate line number
      line_start_section = lines_so_far
      lines_in_section = content.count("\n")
      lines_so_far += lines_in_section

      content.rstrip!
      # The only "section" that should ever be empty is any leading linebreaks
      # at the very beginning of an area file, if any
      next if content.empty?

      new_section = make_section(content, line_start_section)

      if sections.any? { |s| s.class == new_section.class }
        warn(new_section.line_number, nil, "Another #{new_section.class} section? This bodes ill. Skipping")
        next
      end
      sections[new_section.id] = new_section
    end

    sections
  end

  def make_section(content, line_num)
    # Identify area name
    first_line = content.match(/^#.*?$/).to_s.rstrip
    # AREA section has its contents on the same line as the section name
    if first_line.downcase.start_with?("#area ", "#area\t")
      name = "area"
    else
      # Other sections technically can have contents on same line as section,
      # name, but I'm enforcing good syntax anyway.
      first_line = content.slice(/\A.*(?:\n|\Z)/).rstrip
      name = first_line.match(/[a-zA-Z\$]+/).to_s.downcase

      if first_line.include?(" ")
        err(line_start_section, first_line, "Invalid text on same line as section name")
      end
    end

    unless SECTIONS.include? name
      err(line_num, nil, "Invalid section name ##{name}") and return
    end

    case name
    when "area"
      AreaHeader.new(content, line_num)
    when "areadata"
      AreaData.new(content, line_num)
    when "helps"
      Helps.new(content, line_num)
    when "mobiles"
      Mobiles.new(content, line_num)
    when "objects"
      Objects.new(content, line_num)
    when "rooms"
      Rooms.new(content, line_num)
    when "resets"
      Resets.new(content, line_num)
    when "shops"
      Shops.new(content, line_num)
    when "specials"
      Specials.new(content, line_num)
    end
  end

end

if __FILE__ == $PROGRAM_NAME

  if ARGV[0]
    if File.exist?(ARGV[0])
      puts "Parsing #{ARGV[0]}..."
      new_area = Area.new(ARGV[0], ARGV[1..-1])
      new_area.verify_all
      new_area.correlate_all
      new_area.error_report
    else
      puts "#{ARGV[0]} not found, skipping."
    end
  else
    puts "Usage: varea filename.are [nocolor|cosmetic|nowarning]"
  end

end
