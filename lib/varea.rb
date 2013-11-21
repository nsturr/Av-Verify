#!/usr/bin/env ruby

# Avatar area file verifier by Scevine.
#
# This verifier depends on the input file having a minimum of proper
# formatting, i.e. #SECTIONs, #VNUMs, and delimiters starting on their
# own lines, text fields sticking to their own lines, etc. (You get
# this from the area builder anyway, so it shouldn't be an issue.)
#
# Usage: ruby varea.rb areafile.are [nowarning|cosmetic|notices|nocolor]
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

# Require all the helper modules and classes
%w{
  avconstants avcolors bits parsable
  area_attributes correlate_sections
}.each { |helper| require_relative "helpers/#{helper}" }

# Require all the sections
%w{
  area_header area_data helps mobiles
  objects rooms resets shops specials
}.each { |section| require_relative "sections/#{section}" }

# Area class

class Area
  include Parsable # bestows an errors getter
  include AreaAttributes # bestows getters for all its attributes
  include CorrelateSections

  attr_reader :flags

  def initialize(filename, flags=[])
    # How 'bout a little FILE, Scarecrow! >:D
    unless File.exist?(filename)
      puts "#{filename} not found, skipping."
      return nil
    end

    # TODO: Don't release to the team until you've investigated what's happening
    # under the hood re: the encoding
    data = File.read(filename).force_encoding("ISO-8859-1").encode("utf-8", replace: nil)
    total_lines = data.count("\n") + 1
    data.rstrip!

    @flags = flags.map {|item| item.downcase.to_sym}

    @errors = [] # Required by parsable

    if data.end_with?("\#$")
      # If the correct ending char is found, strip it completely so none of the
      # section-parsing methods have to worry about it
      data.slice!(-2..-1)
    else
      err(total_lines, nil, "Area file does not end with \#$")
    end

    @main_sections = extract_main_sections(data)
  end

  def main_sections
    @main_sections.values
  end

  def sections_by_name
    @main_sections
  end

  # get_section accepts a string, symbol, or class
  # Returns the Section object that matches the paramameter, either by id or class
  def get_section section
    if section.is_a? Symbol
      section = section.to_s
    end

    if section == "areaheader"
      @main_sections["area"]
    elsif section.is_a? String
      section = section.downcase.gsub("_", "")
      @main_sections[section]
    elsif section.is_a? Class
      @main_sections.find { |_, s| s.class == section }
    end
  end

  # Runs parse on each of the classes
  def verify_all
    self.main_sections.each do |section|
      next if section.parsed?
      puts "Found ##{section.id} on line #{section.line_number}" if @flags.include?(:debug)
      section.parse
    end
  end

  # Overrides the getter supplied by Parsable
  # Repeatedly calling verify_all won't pollute the area's errors array with
  # duplicates (but correlating all repeatedly will. TODO)
  def errors
    @section_errors = self.main_sections.inject([]) { |arr, s| arr += s.errors }
    # @errors is populated by CorrelateSections's methods
    @errors + @section_errors
  end

  private

  # This splits the area file at the start of any line beginning with # followed by
  # letters (not numbers, those are VNUMs inside a section). Matches with a lookahead
  # so that the first line is kept as part of the section.
  def extract_main_sections(data)
    lines_so_far = 1
    sections = {}

    separated = data.split(/^(?=#[a-zA-Z\$]+)/)
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

      # TODO: some areas (mostly old ones) have more than one section of the same
      # type. Which is valid because I believe that when the game is run, all
      # area files all get mashed together internally anyway. If it makes sense
      # to put the effort in, remove this check for duplicate sections and add
      # in the ability to merge sections of the same type.
      if sections.any? { |s| s.class == new_section.class }
        warn(
          new_section.line_number,
          nil,
          "Another #{new_section.class} section? This bodes ill. Skipping")
        next
      end
      sections[new_section.id] = new_section
    end

    sections
  end

  def make_section(content, line_num)
    first_line = content.match(/^#.*?$/).to_s.rstrip

    # Grab the first line of the section, where the header is, to detect
    # what type it is. #AREA is a one-liner, so it gets special treatment.
    # (Technically all sections can have their data on the same line as
    # the header, but I'm enforcing good syntax.)
    if first_line.downcase.start_with?("#area ", "#area\t")
      name = "area"
    else
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
      new_area.correlate_all # This can't be run before verify_all
      new_area.error_report
    else
      puts "#{ARGV[0]} not found, skipping."
    end
  else
    puts "Usage: varea filename.are [nocolor|cosmetic|notices|nowarning]"
  end

end
