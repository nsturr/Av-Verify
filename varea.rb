# Avatar area file verifier by Scevine.
#
# This verifier depends on the input file having a minimum of proper
# formatting, i.e. #SECTIONs, #VNUMs, and delimeters starting on their
# own lines, text fields sticking to their own lines, etc. (You get
# this from the area builder anyway, so it shouldn't be an issue.)
#
# Usage: ruby varea.rb areafile.are [nowarning, cosmetic, nocolor]
#
# "Nowarning" suppresses non-critical errors, such as Loading a mob
# or object not in the area, which might be intentional. "Cosmetic"
# displays any cosmetic errors such as text fields lacking a newline
# at the end, lines containing tabs, etc. "Nocolor" strips ANSI color
# codes from the output, which is handy if you're piping the output
# away from the console. If "areafile" ends in the extension ".lst"
# then the file is interpreted as an arefile list, and every area
# listed inside will be verified at once.
#
# Usage: ruby varea.rb areafile.are [analyze [mobs|objs]]
#
# This is not yet implemented. Syntax is always checked. It just throws
# data in your face like a clown throwing a cream pie at you. Except
# the pie is made out of numbers, and the clown is a terminal window.
#
# Public methods include:
# verify_area
# verify_areadata
# verify_mobiles
# verify_objects
# verify_rooms
# verify_resets
# verify_shops
# verify_specials - All of these do just what they say.
#
# verify_all - Does all of the above in one
#
# error_report - Actually prints the errors and/or warnings, if any.
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
#  Re-add the checking to make sure that doors don't go after edescs etc.
#  When expecting door locks, properly interpret a single ~

# This file contains AVATAR constants like spec_funs, number of classes, etc.
# which can change when new features are added. If the verifier becomes out-of-
# date after a game update, look in this file first.
require_relative 'avconstants'
# Handy methods for breaking down pipe|separated|bitfields:
require_relative 'bits'
# Adds ANSI color codes to terminal output in AVATAR parlance. I.e.:
# puts "Oh my god my hair is on fire! Better send " + "Snikt".BR + " a tell!"
require_relative 'avcolors'

require './lib/area_header.rb'
require './lib/area_data.rb'
require './lib/helps.rb'
require './lib/mobiles.rb'

class Area
	attr_reader :name, :errors, :mobiles, :objects, :rooms, :resets, :specials

	# Simple structs to encapsulate a section of data with its starting location
	# (line num) in the larger area file.
	Section = Struct.new(:line, :name, :data)
	Error = Struct.new(:line, :type, :context, :description)

	# More granular structs to encapsulate rooms, objects, mobs
	# :line is the line number where the item occurs in the areafile (i.e. after the #VNUM line)
	# :apply is always a hash of applytype => value
	#   multiple applies on the same object/mob will just be summed
	# :kspawn is an array of integers [condition, type, spawn-vnum, room-vnum]
	Mobile = Struct.new(:line, :vnum, :name, :align, :level, :race, :class, :apply, :team, :kspawn)
	# Yeah it has to be spelled like that...
	Objekt = Struct.new(:line, :vnum, :name, :type, :values, :apply)
	Room = Struct.new(:line, :vnum, :name, :exits, :class_excl, :align_excl)
	Exit = Struct.new(:dir, :lock, :key, :dest)
	Reset = Struct.new(:line, :type, :vnum, :room, :limit)

	def initialize(filename, flags=[])
		# How 'bout a little FILE, Scarecrow! >:D
		@name = File.basename(filename)

		unless File.exist?(filename)
			puts "#{filename} not found, skipping."
			return nil
		end

		data = File.read(filename)
		total_lines = data.count("\n") + 1
		data.rstrip!

		@flags = []
		unless flags.empty?
			@flags = flags.map {|item| item.downcase.to_sym}
		end


		@errors = []
		# Mobiles, Objects, Rooms, and Specials are keyed by VNUM (string)
		@mobiles = {}
		@objects = {}
		@rooms = {}
		@resets = [] # Specifically, Mob resets only
		@reset_count = Hash.new(0) # Number of times a mob is loaded, keyed by vnum
		@specials = {}

		if data.end_with?("\#$")
			# If the correct ending char is found, strip it completely so none of the
			# section-parsing methods have to worry about it
			data.slice!(-2..-1)
		else
			err(total_lines, nil, "Area file does not end with \#$")
		end

		@main_sections = find_main_sections(data)
	end

	def verify_all
		@main_sections.each do |section|
			puts "Found ##{section.name} on line #{section.line_number}" if @flags.include?(:debug)
			section.parse
			@errors += section.errors
		end
		# verify_area
		# verify_areadata
		# verify_helps
		# verify_mobiles
		# verify_objects
		# verify_rooms
		# verify_resets
		# verify_shops
		# verify_specials
	end

	# def verify_area
	# 	sect = find_section("area")

	# 	if sect
	# 		puts "##{sect[:name]} found on line #{sect[:line]}" if @flags.include?(:debug)
	# 		parse_section_area sect
	# 	else
	# 		puts "#AREA section not found, skipping." if @flags.include?(:debug)
	# 	end
	# end

	# def verify_areadata
	# 	sect = find_section("areadata")

	# 	if sect
	# 		puts "##{sect[:name]} found on line #{sect[:line]}" if @flags.include?(:debug)
	# 		parse_section_areadata sect
	# 	else
	# 		puts "#AREADATA section not found, skipping." if @flags.include?(:debug)
	# 	end
	# end

	def verify_helps
		sect = find_section("helps")

		if sect
			puts "##{sect[:name]} found on line #{sect[:line]}" if @flags.include?(:debug)
			parse_section_helps sect
		else
			puts "#HELPS section not found, skipping." if @flags.include?(:debug)
		end
	end

	def verify_mobiles
		sect = find_section("mobiles")

		if sect
			puts "##{sect[:name]} found on line #{sect[:line]}" if @flags.include?(:debug)
			parse_section_of_vnums(sect, :mobiles)
		else
			puts "#MOBILES section not found, skipping." if @flags.include?(:debug)
		end
	end

	def verify_objects
		sect = find_section("objects")

		if sect
			puts "##{sect[:name]} found on line #{sect[:line]}" if @flags.include?(:debug)
			parse_section_of_vnums(sect, :objects)
		else
			puts "#OBJECTS section not found, skipping." if @flags.include?(:debug)
		end
	end

	def verify_rooms
		sect = find_section("rooms")

		if sect
			puts "##{sect[:name]} found on line #{sect[:line]}" if @flags.include?(:debug)
			parse_section_of_vnums(sect, :rooms)
		else
			puts "#ROOMS section not found, skipping." if @flags.include?(:debug)
		end
	end

	def verify_resets
		sect = find_section("resets")

		if sect
			puts "##{sect[:name]} found on line #{sect[:line]}" if @flags.include?(:debug)
			parse_section_resets(sect)
		else
			puts "#RESETS section not found, skipping." if @flags.include?(:debug)
		end
	end

	def verify_shops
		sect = find_section("shops")

		if sect
			puts "##{sect[:name]} found on line #{sect[:line]}" if @flags.include?(:debug)
			parse_section_shops(sect)
		else
			puts "#SHOPS section not found, skipping." if @flags.include?(:debug)
		end
	end

	def verify_specials
		sect = find_section("specials")

		if sect
			puts "##{sect[:name]} found on line #{sect[:line]}" if @flags.include?(:debug)
			parse_section_specials(sect)
		else
			puts "#SPECIALS section not found, skipping." if @flags.include?(:debug)
		end
	end

	def error_report
		unless @errors.empty?
			errors = 0
			warnings = 0
			notices = 0
			cosmetic = 0
			@errors.each do |item|
				errors += 1 if item[:type] == :error
				warnings += 1 if item[:type] == :warning
				notices += 1 if item[:type] == :nb
				cosmetic += 1 if item[:type] == :ugly
			end

			text_intro = errors > 0 ? "Someone's been a NAUGHTY builder!" : "Error report:"
			text_error = errors == 1 ? "1 error" : "#{errors} errors"
			text_warning = warnings == 1 ? "1 warning" : "#{warnings} warnings"
			text_cosmetic = cosmetic == 1 ? "1 cosmetic issue" : "#{cosmetic} cosmetic issues"

			unless @flags.include?(:nocolor)
				text_error.BR!
				text_warning.R!
				text_cosmetic.C!
			end

			summary = "#{text_intro} #{text_error}, #{text_warning}."
			if cosmetic > 0
				summary.chop!
				summary += ", #{text_cosmetic}."
			end
			puts summary

			suppressed = 0
			@errors.each do |error|
				if error[:type] == :error
					puts format_error(error, :BR)
				elsif error[:type] == :warning && !@flags.include?(:nowarning)
					puts format_error(error, :R)
				elsif error[:type] == :nb && @flags.include?(:notices)
					puts format_error(error, :Y)
				elsif error[:type] == :ugly && @flags.include?(:cosmetic)
					puts format_error(error, :C)
				else
					suppressed += 1
				end
			end
			puts "Suppressed #{suppressed} items." if suppressed > 0
		else
			puts "No errors found."
		end
	end

	private
	# Returns a new Error struct, while also adding it to the instance var @errors
	def err(line, context, description)
		error = Error.new(line, :error, context, description)
		@errors << error
		error
	end

	# Returns a new Error struct, but only for non-critical errors
	def warn(line, context, description)
		error = Error.new(line, :warning, context, description)
		@errors << error
		error
	end

	# Nothing creates these yet, so ignore
	def nb(line, context, description)
		error = Error.new(line, :nb, context, description)
		@errors << error
		error
	end

	# The least important errors, primarily cosmetic things
	def ugly(line, context, description)
		error = Error.new(line, :ugly, context, description)
		@errors << error
		error
	end

	# returns 1 or 2 lines of formatted text describing the passed error
	# Color is an avatar color code in symbol form (:BW, :K, etc.)
	def format_error(error, color)
		# Error reports will look like this by default:

		# Line NNNN: Description of error
		# --> The offending line [only displayed if error[:context] is not nil]

		text_line = "Line #{error[:line]}:"
		text_indent = "-->"
		unless @flags.include?(:nocolor)
			text_line.CC!(color)
			text_indent.CC!(color)
		end
		formatted = "#{text_line} #{error[:description]}\n"
		formatted += "#{text_indent} #{error[:context]}\n" unless error[:context].nil?
		formatted + "\n"
	end

	# Looks through the main sections for a header matching "name"
	# Returns either the struct containing the section, or false if it couldn't be found.
	def find_section(name)
		return false if @main_sections.nil?
		@main_sections.each do |sect|
			if sect[:name].downcase == name
				return sect
			end
		end
		return false
	end

	def find_main_sections(data)
		lines_so_far = 1 # Keeps track of \n occurances

		# Can't just split sections by #\S and check for valid chars later
		# because it'll catch mob/obj/room vnums.
		separated = data.split(/^(?=#[a-zA-Z\$]+)/)
		sections = []

		separated.each do |content|
			# Mark the line number at which this section starts, then count the line breaks
			# in the section to determine the line number at which the following section
			# will start.
			line_start_section = lines_so_far
			lines_in_section = content.count("\n")
			lines_so_far += lines_in_section

			# Strip trailing whispace AFTER we record how many lines it has.
			# Whitespace between sections doesn't matter, so by eliminating it,
			# it's a lot easier to detect the invalid whitespace inside sections
			# and mobs/etc.
			content.rstrip!
			# The only "section" that should ever be empty is any leading linebreaks
			# at the very beginning of an area file, if any
			next if content.empty?

			sections << (make_section(content, line_start_section) || next)
		end

		# p sections

		sections
	end

	def make_section(content, line_num)
		# Identify area name
		first_line = content.match(/^#.*?$/).to_s.rstrip
		# AREA section has its contents on the same line as the section name
		if first_line.downcase.start_with?("#area ", "#area\t")
			name = "AREA"
		else
			# Other sections technically can have contents on same line as section,
			# name, but I'm enforcing good syntax anyway.
			first_line = content.slice(/\A.*(?:\n|\Z)/).rstrip
			name = first_line.match(/[a-zA-Z\$]+/).to_s

			if first_line.include?(" ")
				err(line_start_section, first_line, "Invalid text on same line as section name")
			end
			# line_num += 1
		end

		unless SECTIONS.include? name.downcase
			err(line_num, nil, "Invalid section name ##{name}") and return
		end

		section = case name.downcase
							when "area"
								AreaHeader.new(content, line_num)
							when "areadata"
								AreaData.new(content, line_num)
							when "helps"
								Helps.new(content, line_num)
							end
		return section
	end

	# Accepts the Apply flag line ("A apply value")
	# Returns an array of [apply, value] if valid, nil otherwise
	# Also throws errors to console.
	def parse_apply_flag(apply_line, line_num)
		items = apply_line.split(" ", 4)
		apply = nil
		value = nil
		unless items.length < 3 # This should only be false if there's only "A" on the apply line
			# Items[0] is just the letter M
			if m = items[1].match(/^(\d+)$/)
				apply = m[1].to_i
			else
				err(line_num, apply_line, "Invalid (negative or non-numeric) apply type")
			end
			if m = items[2].match(/^((?:-|\+)?\d+)$/)
				value = m[1].to_i
			elsif m = items[2].match(/^(\d+(?:\|\d+)+)$/)
				warn(line_num, apply_line, "Bitfields are only used for Apply 50: Immunity") unless apply == 50
				value = Bits.new(m[1])
				err(line_num, apply_line, "Bitfield is not a power of 2") if value.error?
				value = value.sum
			else
				err(line_num, apply_line, "Invalid (non-numeric, incomplete bitfield) apply value")
			end

			return [apply, value] unless apply.nil? || value.nil?
		end
		nil
	end

	def parse_section_helps(section)
		current_line = section[:line]
		section_end = false # Set to true after the 0$~ token is reached
		expect_header = true # True if the next line should be the header of a help file

		section[:data].rstrip.each_line do |line|
			line.rstrip!

			if line.empty?
				current_line += 1
				next
			end

			if section_end
				err(current_line, line, "Section continues after 0$~ delimeter")
				break #Only need to throw this error once.
			end
			if expect_header
				if line =~ /^0 ?\$~/ # sometimes there is a space between 0 and $~
					# First check if the end delimeter is here, and if so mark the section as ended.
					section_end = true
					unless line =~ /^0 ?\$~$/ #Check that nothing comes after the delimeter.
						err(current_line, line, "Section continues after 0$~ delimeter")
						break
					end
					current_line += 1
					next
				# Check that there's non-whitespace on line, so blank lines are ignored
				elsif not line.empty?
					# Now check for the actual header: 000 keyword 'multiple keywords'
					err(current_line, line, "Help file header doesn't start with a level") unless line =~ /^-?\d+/
					if line.count("~") == 0
						err(current_line, line, "Help file header lacks terminating ~")
					elsif line =~ /~.*?\S/
						err(current_line, line, "Help file header continues after terminating ~")
					end
					expect_header = false
				end
			else
				if line.include?("~")
					# Detect the closing tilde of a help file contents, and throw errors if it's
					# in the wrong place.
					ugly(current_line, line, "Visible text contains a tab character") if line.include?("\t")
					ugly(current_line, line, "Closing tilde should be on its own line") unless line =~ /^ *~/
					err(current_line, line, "Line continues after terminating ~") if line =~ /~.*?\S/
					expect_header = true
				end
				# Otherwise, do nothing.
			end
			current_line += 1
		end
		err(current_line, nil, "Section lacks 0$~ ending delimeter") unless section_end
	end

	# The general structure of #mobiles, #objects, and #rooms is the same,
	# so this method works for all three sections, using the "type" parameter
	# to branch when necessary
	def parse_section_of_vnums(section, type)
		lines_so_far = section[:line]
		section_end = false # Set to true when delimeter #0 is found.

		sections = section[:data].split(/^(?=#\d\S*)/)

		sections.each do |sect|
			line_start_section = lines_so_far
			lines_in_section = sect.count("\n")
			lines_so_far += lines_in_section

			if section_end == true
				err(line_start_section, sect[/\A.*?$/], "#{type.to_s.capitalize} section continues after #0 terminator")
				# No need to continue checking, as every subsequent line will throw this error.
				break
			elsif sect =~ /\A#0\b/ #Some vnums start with 0, grrrr

				# this block detects #0 followed by invalid text, either on the same
				# line or on subsequent lines. After a #0 is found, only blank lines
				# are valid
				if not sect.rstrip =~ /\A#0\Z/
					# We want to display just the line that the invalid text is on, though
					# the section isn't split up into lines at this point. Hence the different
					# patterns depending on whether or not the invalid text pans multiple lines
					if sect.rstrip.include?("\n")
						offending_text = sect[/(?<=\A#0).*?\S$/m]
						# Get offset from line where #0 is
						offending_lines = offending_text.count("\n")
						err(line_start_section + offending_lines, offending_text.lstrip, "#{type.to_s.capitalize} section continues after #0 terminator")
					else
						err(line_start_section, sect[/\A#0.*?$/].lstrip, "#{type.to_s.capitalize} section continues after #0 terminator")
					end
				end

				section_end = true
				#lines_so_far += 1
				next
			end
			unless sect =~ /\A#\d+\b/ # If the first line doesn't match #\d+ then it's a bad VNUM
				# But only throw an error if there's actually non-whitespace inside the section
				err(line_start_section, sect[/\A.*$/], "Invalid #{type.to_s} VNUM") if sect =~ /\S/
				next # If the VNUM is invalid, skip over it
			end

			if type == :mobiles
				parse_mobile(sect.rstrip, line_start_section)
			elsif type == :objects
				parse_object(sect.rstrip, line_start_section)
			elsif type == :rooms
				parse_room(sect.rstrip, line_start_section)
			end

		end

		err(lines_so_far, nil, "#{type.to_s.capitalize} section lacks terminating #0") unless section_end
	end

	def parse_mobile(section, line_num)
		first_line = section.slice!(/\A.*?\n/).chomp #Slice off #VNUM

		current_line = line_num # Keep track of areafile line.

		if section.strip.empty? || first_line.nil?
			err(current_line, nil, "Mobile definition is empty!")
			return
		end

		vnum = first_line.match(/(\d+)/)[1].to_i

		if @mobiles.key?(vnum)
			err(line_num, nil, "Duplicate mobile ##{vnum}, first appears on line #{@mobiles[vnum][:line]}")
			return # If mob is a dupe, no need to continue parsing it
		end
		err(line_num, first_line, "Invalid text on same line as VNUM") unless first_line =~ /^#\d+\s*$/

		# This will eventually get added to the area's hash of mobs
		mob = Mobile.new(line_num, vnum)
		# When an apply flag is found, we will just mob[:apply][apply] += amount
		# to account for multiple applies of the same type
		mob[:apply] = Hash.new(0)

		current_line = line_num + 1 # Keep track of areafile line. +1 because we've skipped #VNUM

		# List of each type of line we can parse in a mob section.
		expectation = [ :keywords, :short, :long, :description, :act_aff_align,
										:level, :constant, :sex, :misc, :multiline ]
		# This is an index for the previous array. Gets incremented as we proceed through
		# the lines of the section. expectation[expect] detemines what we'll try to parse
		expect = 0

		long_line = 0 # Number of lines that the long desc takes (It should only be 1)
		last_multiline = nil # Line number where most recent multi-line field started

		section.each_line do |line|
			line.rstrip!

			case expectation[expect]
			when :keywords
				if line.empty?
					err(current_line, nil, "Invalid blank line in mob keywords")
					current_line += 1
					next
				end
				expect += 1
				if line.include?("~")
					err(current_line, line, "Invalid text after terminating ~") if line =~ /~./
				else
					err(current_line, line, "Keyword has no terminating ~ or spans multiple lines")
				end
			when :short
				if line.empty?
					err(current_line, nil, "Mobile short desc spans multiple lines")
					current_line += 1
					next
				end
				ugly(current_line, line, "Visible text contains a tab character") if line.include?("\t")
				expect += 1
				if m = line.match(/^([^~]*)~$/)
					mob[:name] = m[1]
				elsif line =~ /~./
					err(current_line, line, "Invalid text after terminating ~")
				else
					err(current_line, line, "Short desc has no terminating ~ or spans multiple lines")
				end
			when :long
				ugly(current_line, line, "Visible text contains a tab character") if line.include?("\t")
				long_line += 1
				if line.include? "~"
					expect += 1
					if line =~ /~./
						err(current_line, line, "Invalid text after terminating ~")
					elsif line.length > 1
						ugly(current_line, line, "Terminating ~ should be on its own line")
					end
				elsif long_line == 2
					ugly(current_line, line, "Long desc has more than one line of text")
				end
			when :description
				ugly(current_line, line, "Visible text contains a tab character") if line.include?("\t")
				# Firstly, try to match the <act> <aff> <align> S line
				# If it matches exactly, it's a safe bet that the description section lacks a
				# ~ and we just bled into it.
				if line =~ /^#{Bits.insert} +#{Bits.insert} +-?\d+ +S/
					err(current_line, line, "This doesn't look like part of a description. Forget a terminating ~ above?")
					# Set code block to expect the next line (which is the line we just found)
					# and redo the block on the current line
					expect += 1
					redo
				end
				if line.end_with?("~")
					expect += 1
					ugly(current_line, line, "Terminating ~ should be on its own line or it'll look bad") unless line.length == 1
				end
			when :act_aff_align
				if line.empty?
					err(current_line, nil, "Invalid blank line in mob definition")
					current_line += 1
					next
				end
				err(current_line, line, "Line lacks terminating S") unless line.end_with?("S")
				items = line.split
				warn(current_line, line, "ACT_NPC is not set") unless items[0].start_with?("1")
				if items.length == 4
					if items[0] =~ Bits.pattern
						err(current_line, line, "Act flag is not a power of 2") if Bits.new(items[0]).error?
					else
						err(current_line, line, "Bad act flags")
					end
					if items[1] =~ Bits.pattern
						err(current_line, line, "Affect flag is not a power of 2") if Bits.new(items[1]).error?
					else
						err(current_line, line, "Bad affect flags")
					end
					if m = items[2].match(/(-?\d+\b)/)
						align = m[1].to_i
						err(current_line, line, "Alignment out of bounds -1000 to 1000") unless align.between?(-1000, 1000)
						mob[:align] = align
					else
						err(current_line, line, "Bad alignment")
					end
				else
					err(current_line, line, "Line should read: <act> <aff> <align> S")
				end
				expect += 1
			when :level
				if line.empty?
					err(current_line, nil, "Invalid blank line in mob definition")
					current_line += 1
					next
				end
				if m = line.match(/^(\d+) +\d+ +\d+$/)
					level = m[1].to_i
					mob[:level] = level
				else
					unless line =~ /^\d+\b/
						err(current_line, line, "Bad \"level\" field")
					else
						err(current_line, line, "Line should follow syntax: <level:#> 0 0")
					end
				end
				expect += 1
			when :constant
				if line.empty?
					err(current_line, nil, "Invalid blank line in mob definition")
					current_line += 1
					next
				end
				# Technically the line doesn't have to read 0d0+0 0d0+0 0 0, any numbers
				# will do, though they have no effect.
				unless line =~ /^\d+d\d+\+\d+ +\d+d\d+\+\d+ +\d+ +\d+$/i
					err(current_line, line, "Line should read: 0d0+0 0d0+0 0 0")
				end
				expect += 1
			when :sex
				if line.empty?
					err(current_line, nil, "Invalid blank line in mob definition")
					current_line += 1
					next
				end
				if m = line.match(/^\d+ +\d+ +(\d+)$/)
					sex = m[1].to_i
					err(current_line, line, "Sex out of bounds 0 to 2") unless sex.between?(0,SEX_MAX)
				else
					err(current_line, line, "Line should follow syntax: 0 0 <sex:#>")
				end
				expect += 1
			when :misc
				if line.empty?
					err(current_line, nil, "Invalid blank line in mob definition")
					current_line += 1
					next
				end
				# next if line.empty?
				if line.start_with?("R")
					if m = line.match(/^R +(-?\d+)/)
						mob[:race] = m[1].to_i
						err(current, line, "Mob race out of bounds 0 to #{RACE_MAX}") unless mob[:race].between?(0, RACE_MAX)
					else
						err(current_line, line, "Invalid (non-numeric) \"race\" field")
					end
					err(current_line, line, "Invalid text after \"race\" field") unless line =~ /^R +-?\d+$/
				elsif line.start_with?("C")
					if m = line.match(/^C +(-?\d+)/)
						mob[:class] = m[1].to_i
						err(current_line, line, "Mob class out of bounds 0 to #{CLASS_MAX}") unless mob[:class].between?(0, CLASS_MAX)
					else
						err(current_line, line, "Invalid (non-numeric) \"class\" field")
					end
					err(current_line, line, "Invalid text after \"class\" field") unless line =~ /^C +-?\d+$/
				elsif line.start_with?("L")
					if m = line.match(/^L +(-?\d+)/)
						mob[:team] = m[1].to_i
						err(current_line, line, "Mob team out of bounds 0 to #{TEAM_MAX}") unless mob[:team].between?(0, TEAM_MAX)
					else
						err(current_line, line, "Invalid (non-numeric) \"team\" field")
					end
					err(current_line, line, "Invalid text after \"team\" field") unless line =~ /^L +-?\d+$/
				elsif line.start_with?("A")
					# Apply checking is done in another method
					apply = parse_apply_flag(line, current_line)
					unless apply.nil?
						mob[:apply][apply[0]] += apply[1]
					end
				elsif line.start_with?("K")
					last_multiline = current_line
					# Split line into: K condition type spawn mob text...
					items = line.split(" ", 6)
					kspawn = items[1..4]
					if kspawn.length == 4
						err(current_line, line, "Invalid (negative or non-numeric) kspawn condition") unless kspawn[0] =~ /^\d+$/
						err(current_line, line, "Invalid (incomplete or not power of 2) kspawn type bitfield") if Bits.new(kspawn[1]).error?
						err(current_line, line, "Invalid (non-numeric) kspawn vnum") unless kspawn[2] =~ /^-1$|^\d+$/
						err(current_line, line, "Invalid (non-numeric or less than -1) kspawn location") unless kspawn[3] =~ /^-1$|^\d+$/
						mob[:kspawn] = kspawn
					else
						err(current_line, line, "Not enough tokens in kspawn line")
					end

					# The line's last field is text with can span multiple lines. If there's no tilde,
					# expect the next line to just be more text that can be ignored until a tilde
					# is found.
					expect += 1 unless line.end_with?("~")
				else
					err(current_line, line, "Invalid extra field (expecting R, C, L, A, or K)") unless line.empty?
				end
			when :multiline
				ugly(current_line, line, "Visible text contains a tab character") if line.include?("\t")
				# This type is only ever expected if a killspawn text field spans multiple lines
				expect -= 1 if line.end_with?("~")
			end # End case
			current_line += 1

		end # End section.each

		# If we've gone through every line and are still expecting text from a multiline killspawn
		# message, we've obviously forgotten a tilde somewhere.
		err(current_line, nil, "Killspawn lacks terminating ~ between lines #{last_multiline} and #{current_line}") if expectation[expect] == :multiline

		@mobiles[vnum] = mob
	end

	def parse_object(section, line_num)
		first_line = section.slice!(/\A.*?\n/).chomp #Slice off #VNUM

		current_line = line_num # Keep track of areafile line.

		if section.strip.empty? || first_line.nil?
			err(current_line, nil, "Mobile definition is empty!")
			return
		end

		vnum = first_line.match(/(\d+)/)[1].to_i

		if @objects.key?(vnum)
			err(line_num, nil, "Duplicate object ##{vnum}, first appears on line #{@objects[vnum][:line]}")
			return # If object is a dupe, no need to continue parsing it
		end
		err(line_num, first_line, "Invalid text on same line as VNUM") unless first_line =~ /^#\d+\s*$/

		# This will eventually get added to the area's hash of objects
		obj = Objekt.new(line_num, vnum)
		# When an apply flag is found, we will just obj[:apply][apply] += amount
		# to account for multiple applies of the same type
		obj[:apply] = Hash.new(0)

		current_line = line_num + 1 # Keep track of areafile line. +1 because we've skipped #VNUM

		# List of each type of line we can parse in an object section.
		expectation = [ :keywords, :short, :long, :action, :type_extra_wear,
										:values, :weight_worth, :misc, :ekeyword, :edesc ]
		# This is an index for the previous array. Gets incremented as we proceed through
		# the lines of the section. expectation[expect] detemines what we'll try to parse
		expect = 0
		long_line = 0 # This is for long descs that go for more than 1 line. I don't like them.

		# Line number where the most recent multi-line field started
		last_multiline = nil

		section.each_line do |line|
			line.rstrip!

			# next if line.empty?

			case expectation[expect]
			when :keywords
				if line.empty?
					err(current_line, nil, "Invalid blank line in object keywords")
					current_line += 1
					next
				end
				expect += 1
				if line.include?("~")
					err(current_line, line, "Invalid text after terminating ~") if line =~ /~./
				else
					err(current_line, line, "Keywords lacks terminating ~ or spans multiple lines")
				end
			when :short
				if line.empty?
					err(current_line, nil, "Short description spans multiple lines")
					current_line += 1
					next
				end
				ugly(current_line, line, "Visible text contains a tab character") if line.include?("\t")
				expect += 1
				unless line.end_with?("~")
					err(current_line, line, "Short description lacks terminating ~ or spans multiple lines")
				end
				if name = line.match(/^([^~]*)~$/)
					obj[:name] = name[1]
				end
			when :long
				ugly(current_line, line, "Visible text contains a tab character") if line.include?("\t")
				long_line += 1
				if line.include? "~"
					expect += 1
					if line =~ /~./
						err(current_line, line, "Invalid text after terminating ~")
					end
				elsif long_line == 2
					ugly(current_line, line, "Long desc has more than one line of text")
				end
			when :action
				ugly(current_line, line, "Visible text contains a tab character") if line.include?("\t")
				if m = line.match(/^(\d+) +#{Bits.insert} +#{Bits.insert}$/)
					type = m[1].to_i
					obj[:type] = type
					err(current_line, line, "Doesn't look like part of an adesc. Forget a ~ somewhere?")
					# Since we assume we already reached the type_extra_wear line, this sets
					# the code block to expect the values line next
					expect += 2
				end
				expect += 1 if line.end_with?("~")
			when :type_extra_wear
				if line.empty?
					err(current_line, nil, "Invalid blank line in object definition")
					current_line += 1
					next
				end
				expect += 1
				if m = line.match(/^(\d+) +(#{Bits.insert}) +(#{Bits.insert})$/)
					type = m[1].to_i
					obj[:type] = type
					err(current_line, line, "Extra flag is not a power of 2") if Bits.new(m[2]).error?
					err(current_line, line, "Wear flag is not a power of 2") if Bits.new(m[3]).error?
				else
					err(current_line, line, "Line should follow syntax: <type:#> <extraflag:#> <wearflag:#>")
				end
			when :values
				if line.empty?
					err(current_line, nil, "Invalid blank line in object definition")
					current_line += 1
					next
				end
				expect += 1
				items = line.split
				if items.length == 4
					values = []
					0.upto(3) do |i|
						if items[i].match(/^(?:-?\d+|#{Bits.insert})$/)
							values[i] = items[i]
						else
							err(current_line, line, "Invalid format for object value#{i}")
						end
					end
					obj[:values] = values
				else
					err(current_line, line, "Wrong number of items in value0-3 line")
				end
			when :weight_worth
				if line.empty?
					err(current_line, nil, "Invalid blank line in object definition")
					current_line += 1
					next
				end
				expect += 1
				items = line.split
				err(current_line, line, "Too many items in weight/worth line") if items.length > 3
				if items.length >= 3
					err(current_line, line, "Invalid object weight") unless items[0] =~ /^\d+$/
					err(current_line, line, "Invalid object worth") unless items[1] =~ /^\d+$/
				else
					err(current_line, line, "Line should follow syntax: <weight:#> <worth:#> 0")
				end
			when :misc
				if line.empty?
					err(current_line, nil, "Invalid blank line in object definition")
					current_line += 1
					next
				end
				if line.start_with?("A")
					# Apply checking is done in another method
					apply = parse_apply_flag(line, current_line)
					unless apply.nil?
						obj[:apply][apply[0]] += apply[1]
					end
				elsif line.start_with?("Q")
					if line =~ /^Q +\d+/
						err(current_line, line, "Invalid text after quality field") unless line =~ /^Q +\d+$/
					elsif line =~ /^Q +-\d+/
						err(current_line, line, "Quality cannot be negative")
					else
						err(current_line, line, "Invalid quality field")
					end
				elsif line.start_with?("E")
					err(current_line, line, "Invalid text after E flag") if line.length > 1
					expect += 1
				else
					err(current_line, line, "Invalid extra field (expecting A, Q, or E)") unless line.empty?
				end
			when :ekeyword
				if line.empty?
					err(current_line, nil, "Object edesc keywords span multiple lines")
					current_line += 1
					next
				end
				expect += 1
				last_multiline = current_line + 1 # The next line begins a multiline field
				if line.count("~") > 1
					err(current_line, line, "Misplaced ~ in edesc keyword line")
				elsif !line.end_with?("~")
					err(current_line, line, "Edesc keyword line lacks terminating ~ or spans multiple lines")
				end
			when :edesc
				if line.empty?
					current_line += 1
					next
				end
				ugly(current_line, line, "Visible text contains a tab character") if line.include?("\t")
				if line.end_with?("~")
					expect -= 2
					ugly(current_line, line, "Edesc terminating ~ should be on its own line") if line.length > 1
				end
			end
			current_line += 1
		end
		err(current_line, nil, "Edesc lacks terminating ~ between lines #{last_multiline} and #{current_line}") if expectation[expect] == :edesc

		@objects[vnum] = obj
	end

	def parse_room(section, line_num)
		first_line = section.slice!(/\A.*?\n/).chomp #Slice off #VNUM

		current_line = line_num # Keep track of areafile line.

		if section.strip.empty? || first_line.nil?
			err(current_line, nil, "Mobile definition is empty!")
			return
		end

		vnum = first_line.match(/(\d+)/)[1].to_i

		if @rooms.key?(vnum)
			err(line_num, nil, "Duplicate room ##{vnum}, first appears on line #{@rooms[vnum][:line]}")
			return # If room is a dupe, no need to continue parsing it
		end
		err(line_num, first_line, "Invalid text on same line as VNUM") unless first_line =~ /^#\d+\s*$/

		room = Room.new(line_num, vnum) # This will eventually get added to the area's hash of rooms
		exits = {}
		exit = nil # Temporary var for an Exit object

		current_line = line_num + 1 # Keep track of areafile line. +1 because we've skipped #VNUM

		# List of each type of line we can parse in an object section.
		expectation = [ :name, :desc, :flags_sector, :misc, :door_desc,
										:door_kword, :door_locks, :ekeyword, :edesc ]
		# This is an index for the previous array. Gets incremented as we proceed through
		# the lines of the section. expectation[expect] detemines what we'll try to parse
		expect = 0

		# Line number where the most recent multi-line field started
		last_multiline = nil

		# True when extra fields are parsed, after which door fields will be invalid
		#past_doors = false

		# True when the S line is found, indicating that the room section is ending
		section_end = false

		section.each_line do |line|
			line.rstrip!

			# First check to make sure that we haven't found the designated end of the room
			if section_end && line =~ /\S/
				err(current_line, line, "Room continues after its terminating S line")
				return # Return, because every subsequent line will just throw the same error
			end

			case expectation[expect]
			when :name
				if line.empty?
					err(current_line, nil, "Invalid blank line in room name")
					current_line += 1
					next
				end
				expect += 1
				if m = line.match(/^([^~]*)~$/)
					room[:name] = m[1]
				elsif line =~ /~./
					err(current_line, line, "Invalid text after terminating ~")
				else
					err(current_line, line, "Room name lacks terminating ~ or spans multiple lines")
				end
			when :desc
				ugly(current_line, line, "Visible text contains a tab character") if line.include?("\t")
				# If this line matches, it's practically guaranteed that we've left the description
				# and entered the next field due to lack of ~
				if line =~ /^\d+ +#{Bits.insert} +\d+ *$/
					err(current_line, line, "This doesn't look like part of a description. Forget a terminating ~ above?")
					expect += 1
					redo
				end
				# Basically ignore every line of the description that doesn't have a ~ in it
				if line.end_with?("~")
					expect += 1
					ugly(current_line, line, "Room desc terminating ~ should be on its own line.") if line.length > 1
				elsif line =~ /~./
					err(current_line, line, "Room desc continues after terminating ~")
					expect += 1
				end
			when :flags_sector
				if line.empty?
					err(current_line, nil, "Invalid blank line in room definition")
					current_line += 1
					next
				end
				expect += 1
				items = line.split
				err(current_line, line, "Too many fields on roomflag/sector line") if items.length > 3
				if items[1] =~ Bits.pattern
					err(current_line, line, "Room flag is not a power of 2") if Bits.new(items[1]).error?
				else
					err(current_line, line, "Invalid roomflag field")
				end
				if items[2] =~ /\d+\b/
					err(current_line, line, "Room sector out of bounds 0 to #{SECTOR_MAX}") unless items[2].to_i.between?(0, SECTOR_MAX)
				else
					err(current_line, line, "Invalid sector field")
				end
			when :misc
				if line.empty? && section_end == false
					err(current_line, nil, "Invalid blank line in room definition")
					current_line += 1
					next
				end
				if line.start_with?("D")
					#err(current_line, line, "Door field occurs after extra fields") if past_doors
					if m = line.match(/^D(\d+)/)
						expect += 1
						last_multiline = current_line + 1 #Next line begins a multiline field
						direction = m[1].to_i

						exit = Exit.new(direction)

						err(current_line, line, "Duplicate exit direction in room") unless exits[direction].nil?
						err(current_line, line, "Invalid text after exit header") unless line =~ /^D\d+$/
						err(current_line, line, "Invalid exit direction") unless direction.between?(0,5)
					else
						err(current_line, line, "Invalid field (expecting D#, A, C, E, or S)")
					end
				elsif line.start_with?("A")
					if m = line.match(/^A +(#{Bits.insert})/)
						#past_doors = true
						align_excl = Bits.new(m[1])
						room[:align_excl] = align_excl.to_a
						err(current_line, line, "Alignment restriction flag is not a power of 2") if align_excl.error?
						err(current_line, line, "Invalid text after room alignment restriction") unless line =~ /^A +#{Bits.insert}$/
					else
						err(current_line, line, "Invalid alignment restriction line")
					end
				elsif line.start_with?("C")
					if m = line.match(/^C +(#{Bits.insert})/)
						#past_doors = true
						class_excl = Bits.new(m[1])
						room[:class_excl] = class_excl.to_a
						err(current_line, line, "Class restriction flag is not a power of 2") if class_excl.error?
						err(current_line, line, "Invalid text after room class restriction") unless line =~ /^C +#{Bits.insert}$/
					else
						err(current_line, line, "Invalid class restriction line")
					end
				elsif line.start_with?("E")
					if line.length == 1
						#past_doors = true
						expect += 4 #Expect a keyword line next
					else
						err(current_line, line, "Invalid field (expecting D#, A, C, E, or S)")
					end
				elsif line.start_with?("S")
					if expectation[expect] == :edesc || expectation[expect] == :door_desc
						err(current_line, nil, "Extra/door desc lacks terminating ~ between lines #{last_multiline} and #{current_line}")
					end
					section_end = true
					err(current_line, line, "Invalid text after terminating S") unless line =~ /^S$/
				elsif section_end == false
					err(current_line, line, "Invalid field (expecting D#, A, C, E, or S)")
				end
			when :door_desc
				if line.empty?
					current_line += 1
					next
				end
				ugly(current_line, line, "Visible text contains a tab character") if line.include?("\t")
				# Basically ignore every line of the description that doesn't have a ~ in it
				if line.end_with?("~")
					expect += 1
					ugly(current_line, line, "Door desc terminating ~ should be on its own line.") if line.length > 1
				elsif line =~ /~./
					err(current_line, line, "Door desc continues after terminating ~")
					expect += 1
				end
			when :door_kword
				if line.empty?
					err(current_line, nil, "Invalid blank line in room exit keywords")
					current_line += 1
					next
				end
				expect += 1
				if line =~ /^[^~]*~$/
					#
				elsif line =~ /~./
					err(current_line, line, "Invalid text after terminating ~")
				else
					err(current_line, line, "Door keywords lack terminating ~ or spans multiple lines")
				end
			when :door_locks
				expect -= 3 # Go back to expecting a misc line
				items = line.split
				# Make sure the right number of items are on the line
				if items.length == 3
					if items[0] =~ /^\d+$/
						exit[:lock] = items[0].to_i unless exit.nil?
						err(current_line, line, "Door lock type out of bounds 0 to #{LOCK_MAX}") unless items[0].to_i.between?(0,LOCK_MAX)
					else
						err(current_line, line, "Invalid door lock field")
					end
					if items[1] =~ /^-1$|^\d+$/
						# Valid values for keys are -1, 0, or any positive number.
						exit[:key] = items[1].to_i unless exit.nil?
					else
						err(current_line, line, "Invalid door key field")
					end
					if items[2] =~ /^-1$|^\d+$/
						# Valid values for destinations are -1, or any positive number.
						exit[:dest] = items[2].to_i unless exit.nil?
					else
						err(current_line, line, "Invalid door destination field")
					end
					exits[exit[:dir]] = exit if exits[exit[:dir]].nil?
					exit = nil
				else
					err(current_line, line, "Invalid door locks line")
				end
			when :ekeyword
				if line.empty?
					err(current_line, nil, "Room edesc keywords span multiple lines")
					current_line += 1
					next
				end
				expect += 1
				# Mark the following line as the start of a multiline field
				last_multiline = current_line + 1
				if line =~ /^[^~]*~$/
					#
				elsif line =~ /~./
					err(current_line, line, "Invalid text after terminating ~")
				else
					err(current_line, line, "Edesc keywords lack terminating ~ or spans multiple lines")
				end
			when :edesc
				ugly(current_line, line, "Visible text contains a tab character") if line.include?("\t")
				# Basically ignore every line of the description that doesn't have a ~ in it
				if line.end_with?("~")
					expect -= 5
					ugly(current_line, line, "Room edesc terminating ~ should be on its own line.") if line.length > 1
				elsif line =~ /~./
					err(current_line, line, "Room edesc continues after terminating ~")
					expect -= 5
				end
			end
			current_line += 1
		end

		err(current_line, nil, "Edesc lacks terminating ~ between lines #{last_multiline} and #{current_line}") if expectation[expect] == :edesc
		err(current_line, nil, "Room section lacks terminating S") unless section_end

		room[:exits] = exits unless exits.empty?

		@rooms[vnum] = room
	end

	def parse_section_resets(section)

		current_line = section[:line]
		# Set to true when the "S" line is detected
		section_end = false
		# Set to the vnum of the most recent mob loaded. Since it starts as nil,
		# G, E, and O resets can tell if any mob has been loaded yet (and throw
		# errors if not)
		current_mob = nil
		equip_slots = []

		section[:data].each_line do |line|
			line.rstrip!

			if section_end && !line.empty?
				err(current_line, line, "Section continues after its terminating S line")
				return # Because it'll only keep throwing this error over and over again
			end

			# This detects comments beginning with *
			# Comments don't need a starting char if they occur after a reset or special
			if line =~ /^\s*\*/
				current_line += 1
				next
			end

			# N.B. a lot of the regexp have '\*?' in them. Sometimes comments starting with *
			# get smooshed up against the last number in the line, and it would otherwise
			# throw an error.
			case line[0..1]
			when "M "
				current_mob = true # This is to signify that a mob is at least trying to be loaded
				equip_slots = [] # Clear equip reset history for the new mob
				# Line syntax: M 0 mob_VNUM limit room_VNUM comments
				items = line.split(" ", 6)
				if items.length >= 5 # Comments are optional
					mob_reset = Reset.new(current_line, :mobile)
					# Items[0] is just the leading M, so ignore it
					#err(current_line, line, "First token of mob reset should be a 0") unless items[1] == "0"
					# Parse the Mob VNUM
					if m = items[2].match(/^(-?\d+)$/)
						mob_vnum = m[1].to_i
						err(current_line, line, "Mob VNUM can't be 0 or negative") if mob_vnum < 1
						current_mob = mob_vnum
						mob_reset[:vnum] = mob_vnum
					else
						err(current_line, line, "Invalid mob VNUM")
					end
					# Parse the Mob Limit
					if m = items[3].match(/^(-?\d+)$/)
						spawn_limit = m[1].to_i
						err(current_line, line, "Mob limit can't be negative") if spawn_limit < 0
						mob_reset[:limit] = spawn_limit
					else
						err(current_line, line, "Invalid mob limit")
					end
					# Parse the target Room. Some comments starting with * are smooshed up
					# against the vnum, btw
					if m = items[4].match(/^(-?\d+)\*?$/)
						target = m[1].to_i
						err(current_line, line, "Target spawn room can't be negative") if target < 0
					else
						err(current_line, line, "Invalid room VNUM")
					end
				else
					err(current_line, line, "Not enough tokens on in mob reset line")
				end
				@resets << mob_reset
				if @reset_count[mob_vnum] >= mob_reset[:limit]
					warn(current_line, line, "Mob reset limit is #{mob_reset[:limit]}, but #{@reset_count[mob_vnum]} mobs load before it.")
				end
				@reset_count[mob_vnum] += 1
				# Throw an error if this mobile spawns in a room not in the area, but only if
				# the hash isn't empty (in which case the section probably hasn't been parsed)
				warn(current_line, line, "Mobile's spawn location is not in the area") unless @rooms.key?(target) || @rooms.empty?
				warn(current_line, line, "Mobile to spawn is not in the area") unless @mobiles.key?(mob_vnum) || @mobiles.empty?
			when "G "
				# Line syntax: G <0 or -#> obj_VNUM 0
				err(current_line, line, "G reset occurs before any mob has been loaded") unless current_mob
				items = line.split(" ", 5)
				if items.length >= 4
					# Items[0] is just the leading G, so ignore it
					# Parse the limit. Can be 0 or a negative number
					if m = items[1].match(/^(-?\d+)$/)
						spawn_limit = m[1].to_i
						#err(current_line, line, "Inventory spawn limit out of bounds 0 or -2 and lower") if spawn_limit > 0
						#err(current_line, line, "Inventory spawn limit out of bounds 0 or -2 and lower") if spawn_limit == -1
					else
						err(current_line, line, "Invalid inventory spawn limit")
					end
					# Parse the object VNUM
					if m = items[2].match(/^(-?\d+)$/)
						obj_vnum = m[1].to_i
						err(current_line, line, "Object VNUM can't be negative") if obj_vnum < 0
						# Throw an error if this object to spawn is not in the area, but only if
						# the hash isn't empty (in which case the section probably hasn't been parsed)
						warn(current_line, line, "Object to spawn is not in the area") unless @objects.key?(obj_vnum) || @objects.empty? || known_vnum(obj_vnum)
					else
						err(current_line, line, "Invalid object VNUM")
					end
					# Parse the trailing 0
					#err(current_line, line, "Last token of inventory reset must be a 0") unless items[3] == "0"
				else
					err(current_line, line, "Not enough tokens in inventory reset line")
				end
			when "E "
				err(current_line, line, "E reset occurs before any mob has been loaded") unless current_mob
				items = line.split(" ", 6)
				if items.length >= 5
					# Items[0] is just the leading E, so ignore it
					# Parse the limit. Can be 0 or a negative number
					if m = items[1].match(/^(-?\d+)$/)
						spawn_limit = m[1].to_i
						#err(current_line, line, "First token of equipment reset must be 0 or negative") if spawn_limit > 0
					else
						err(current_line, line, "Invalid first token")
					end
					# Parse the object VNUM
					if m = items[2].match(/^(-?\d+)$/)
						obj_vnum = m[1].to_i
						err(current_line, line, "Object VNUM can't be negative") if obj_vnum < 0
						# Throw an error if this object to spawn is not in the area, but only if
						# the hash isn't empty (in which case the section probably hasn't been parsed)
						warn(current_line, line, "Object to spawn is not in the area") unless @objects.key?(obj_vnum) || @objects.empty?  || known_vnum(obj_vnum)
					else
						err(current_line, line, "Invalid object VNUM")
					end
					# Parse the trailing 0
					#err(current_line, line, "Third token of inventory reset must be 0") unless items[3] == "0"
					# Parse the wear location
					if m = items[4].match(/^(-?\d+)\*?$/)
						wear_loc = m[1].to_i
						if equip_slots.include? wear_loc
							err(current_line, line, "Wear location already filled on this mob reset.")
						else
							equip_slots << wear_loc
						end
						err(current_line, line, "Wear location out of bounds 0 to #{WEAR_MAX}") unless wear_loc.between?(0,WEAR_MAX)
					else
						err(current_line, line, "Invalid wear location")
					end
				else
					err(current_line, line, "Not enough tokens in equipment reset line")
				end
			when "O "
				# Commenting out this warning because so many areas start with O resets
				# The warning will remain for E and G resets, though.
				# warn(current_line, line, "O reset occurs before any mob has been loaded") unless current_mob
				items = line.split(" ", 6)
				if items.length >= 5
					# Items[0] is just the leading O, so ignore it
					# Parse the first token, which should be a 0
					#err(current_line, line, "First token of object reset must be a 0") unless items[1] == "0"
					# Parse the object vnum
					if m = items[2].match(/^(-?\d+)$/)
						obj_vnum = m[1].to_i
						err(current_line, line, "Object VNUM can't be negative") if obj_vnum < 0
						warn(current_line, line, "Object to spawn is not in the area") unless @objects.key?(obj_vnum) || @objects.empty? || known_vnum(obj_vnum)
					else
						err(current_line, line, "Invalid object VNUM")
					end
					# Parse the third token, which should be a 0
					#err(current_line, line, "First token of object reset must be a 0") unless items[3] == "0"
					# Parse the target room vnum
					if m = items[4].match(/^(-?\d+)\*?$/)
						target = m[1].to_i
						err(current_line, line, "Target room VNUM can't be negative") if target < 0
						# Throw an error if this object spawns in a room not in the area, but only if
						# the hash isn't empty (in which case the section probably hasn't been parsed)
						warn(current_line, line, "Object's spawn location is not in the area") unless @rooms.key?(target) || @rooms.empty?
					else
						err(current_line, line, "Invalid target room VNUM")
					end
				else
					err(current_line, line, "Not enough tokens in object reset line")
				end
			when "P "
				items = line.split(" ", 6)
				if items.length >= 5
					# Items[0] is just the leading O, so ignore it
					# Parse the first token, which should be a 0
					#err(current_line, line, "First token of container reset must be a 0") unless items[1] == "0"
					# Parse the object vnum
					if m = items[2].match(/^(-?\d+)$/)
						obj_vnum = m[1].to_i
						err(current_line, line, "Object VNUM can't be negative") if obj_vnum < 0
						warn(current_line, line, "Object to spawn is not in the area") unless @objects.key?(obj_vnum) || @objects.empty? || known_vnum(obj_vnum)
					else
						err(current_line, line, "Invalid object VNUM")
					end
					# Parse the third token, which should be a 0
					#err(current_line, line, "First token of object reset must be a 0") unless items[3] == "0"
					# Parse the target container vnum
					if m = items[4].match(/^(-?\d+)\*?$/)
						target = m[1].to_i
						err(current_line, line, "Target container VNUM can't be negative") if target < 0
						# Throw an error if this object spawns in a container not in the area, but only
						# if the hash isn't empty (in which case the section probably hasn't been parsed)
						warn(current_line, line, "Object's spawn container is not in the area") unless @objects.key?(target) || @objects.empty?
					else
						err(current_line, line, "Invalid target container VNUM")
					end
				else
					err(current_line, line, "Not enough tokens in container reset line")
				end
			when "D "
				items = line.split(" ", 6)
				if items.length >= 5
					# Items[0] is just the leading D, so ignore it
					# Parse the first token, which should be a 0
					#err(current_line, line, "First token of door reset must be a 0") unless items[1] == "0"
					# Parse the target room number
					if m = items[2].match(/^(-?\d+)$/)
						target = m[1].to_i
						err(current_line, line, "Room VNUM can't be negative") if target < 0
					else
						err(current_line, line, "Invalid room VNUM")
					end
					# Parse the door number
					if m = items[3].match(/^(-?\d+)$/)
						dir = m[1].to_i
						err(current_line, line, "Door number out of bounds 0 to 5") unless dir.between?(0,5)
					else
						err(current_line, line, "Invalid door direction")
					end
					# Parse the door state
					if m = items[4].match(/^(-?\d+)\*?$/)
						state = m[1].to_i
						err(current_line, line, "Door state out of bounds 0 to 8") unless state.between?(0,8)
					else
						err(current_line, line, "Invalid door state")
					end
				else
					err(current_line, line, "Not enough tokens in door reset line")
				end
				if !@rooms.empty?
					# Treating this like a real error, because seriously when would you ever
					# reset a door from another area...
					if !@rooms.key?(target)
						err(current_line, line, "Door reset's room is not in the area")
					elsif @rooms[target][:exits].nil?
						err(current_line, line, "Door reset's room does not have this exit")
					elsif @rooms[target][:exits][dir].nil?
						err(current_line, line, "Door reset's room does not have this exit")
					elsif	@rooms[target][:exits][dir][:lock] == 0
						err(current_line, line, "Door reset targets an ordinary exit with no door")
					end
				else
					err(current_line, line, "Door reset's room is not in the area")
				end
			when "R "
				items = line.split(" ", 5)
				if items.length >= 4
					# Items[0] is just the leading D, so ignore it
					# Parse the first token, which should be a 0
					#err(current_line, line, "First token of random reset must be a 0") unless items[1] == "0"
					# Parse the room vnum
					if m = items[2].match(/^(-?\d+)$/)
						target = m[1].to_i
						err(current_line, line, "Room VNUM can't be negative") if target < 0
					else
						err(current_line, line, "Invalid target room VNUM")
					end
					# Parse the number of exits
					if m = items[3].match(/^(-?\d+)\*?$/)
						num_exits = m[1].to_i
						err(current_line, line, "Number of exits out of bounds 0 to 6") unless num_exits.between?(0,6)
					else
						err(current_line, line, "Invalid number of exits")
					end
				else
					err(current_line, line, "Not enough tokens in random reset line")
				end
				err(current_line, line, "Room to randomize is not in the area") unless @rooms.key?(target) || @rooms.empty?
			when "S"
				section_end = true
				err(current_line, line, "Invalid text after terminating S") unless line.length == 1
			else
				err(current_line, line, "Invalid reset") unless line.empty?
			end
			current_line += 1
		end
	end

	def parse_section_shops(section)
		# This section will be the death of me.
		# seriously, die in a fire, #shops

		expectation = [ :shopkeeper, :types, :profit, :time ]
		expect = 0

		current_line = section[:line]
		section_end = false

		section[:data].each_line do |line|
			line.rstrip!
			# if section_end && line =~ /\S/
			if section_end and not line.empty?
				err(current_line, line, "Section continues after terminating 0")
				return
			end
			
			# This section doesn't mind text after fields on the line
			case expectation[expect]
			when :shopkeeper
				if line == "0"
					section_end = true
				elsif m = line.match(/^(\d+)/)
					expect += 1
					warn(current_line, line, "Shopkeeper mobile is not in the area") unless @mobiles.key?(m[1].to_i) || @mobiles.empty?
				elsif line.empty?
					# Do nothing! Empty lines are great. Totally great. 
				else
					err(current_line, line, "Invalid shopkeeper VNUM")
				end
			when :types
				if line.empty?
					err(current_line, nil, "Invalid blank line inside shop")
					current_line += 1
					next
				end
				expect += 1
				items = line.split(" ", 6)
				if items.length >= 5
					0.upto(4).each do |i|
						err(current_line, line, "Invalid object type") unless items[i] =~ /^\d+$/
					end
				else
					err(current_line, line, "Not enough tokens in shop type line")
				end
			when :profit
				if line.empty?
					err(current_line, nil, "Invalid blank line inside shop")
					current_line += 1
					next
				end
				expect += 1
				items = line.split(" ", 3)
				if items.length >= 2
					if items[0] =~ /^-?\d+$/
						err(current_line, line, "Profit margin can't be negative") if items[0].to_i < 0
					else
						err(current_line, line, "Invalid profit margin")
					end
					if items[1] =~ /^-?\d+$/
						err(current_line, line, "Profit margin can't be negative") if items[1].to_i < 0
					else
						err(current_line, line, "Invalid profit margin")
					end
				else
					err(current_line, line, "Not enough tokens in profit line")
				end
			when :time
				if line.empty?
					err(current_line, nil, "Invalid blank line inside shop")
					current_line += 1
					next
				end
				expect = 0
				items = line.split(" ", 3)
				if items.length >= 2
					if items[0] =~ /^\d+$/
						err(current_line, line, "Hours out of bounds 0 to 23") unless items[0].to_i.between?(0,23)
					else
						err(current_line, line, "Invalid hour")
					end
					if items[1] =~ /^\d+$/
						err(current_line, line, "hours out of bounds 0 to 23") unless items[1].to_i.between?(0,23)
					else
						err(current_line, line, "Invalid hour")
					end
				else
					err(current_line, line, "Not enough tokens in hours line")
				end
			end
			current_line += 1
		end
	end

	def parse_section_specials(section)

		current_line = section[:line]
		section_end = false

		specials = {}

		section[:data].each_line do |line|
			line.rstrip!

			if section_end && !line.empty?
				err(current_line, line, "Section continues after terminating S")
				return
			end

			# This detects comments beginning with *
			# Comments don't need a starting char if they occur after a reset or special
			if line =~ /^\s*\*/
				current_line += 1
				next
			end

			if line.start_with? "M "
				mob_vnum = nil
				spec = nil

				items = line.split(" ", 4)
				if items.length >= 3
					if items[1] =~ /^\d+$/
						mob_vnum = items[1].to_i
					else
						err(current_line, line, "Invalid mob vnum")
					end
					if items[2] =~ /^\w+$/
						spec = items[2].downcase
						err(current_line, line, "Unknown SPEC_FUN") unless SPECIALS.include? items[2].downcase
					else
						err(current_line, line, "Invalid SPEC_FUN")
					end
					warn(current_line, line, "This will override mob's existing special: #{@specials[mob_vnum]}") if @specials.key? mob_vnum
					@specials[mob_vnum] = spec
				else
					err(current_line, line, "Not enough tokens in special line")
				end
			elsif line.start_with? "S"
				err(current_line, line, "Section continues after terminating S") if line.length > 1
				section_end = true
			#elsif line.lstrip.start_with?("*")
				# This is a comment. Ignore!
			elsif not line.empty? # If any non-whitespace, flip out
				err(current_line, line, "Invalid special line")
			end
			current_line += 1
		end

		@specials = specials unless specials.empty?
	end

end

# To remove the batch verification using lst files and reinstate the
# old usage, comment out the long block starting with if ARGV[0] on
# line 1819 through 1858, and uncomment the 5-line block below.

if ARGV[0]
	if File.exist?(ARGV[0])
		puts "Parsing #{ARGV[0]}..."
		new_area = Area.new(ARGV[0], ARGV[1..-1])
		new_area.verify_all
		new_area.error_report
	else
		puts "#{ARGV[0]} not found, skipping."
	end
end

=begin Commenting out the needlessly complex batch verifying function.
				If you're going to uncomment this bit, be sure to comment out the
				"if" block above
if ARGV[0]
	files_enumerated = []
	path = "."
	
	# If file to parse ends with .lst, then treat it as area.lst containing
	# one areafile name per line, ending with End or $
	if ARGV[0].match(/^[\w\.\\\/_]+\.lst$/i)
		list_file = File.open(ARGV[0])
		# Getting the full path of the list file, then putting just the directory
		# structure into path (i.e. full path minus file name)
		path = File.dirname(list_file.path)
		list_file.each_line do |line|
			# End filename parsing if the current line contains "end" or starts with "$"
			break if line.rstrip.match(/^(?:\$|end$)/i)
			# Add each line to the list of files IF the line is just one word.
			files_enumerated << path + File::SEPARATOR + line.rstrip.chomp if line.rstrip.match(/^[\w\.]+$/)
		end
		list_file.close
	else
		# Otherwise, this is just a single area file.
		files_enumerated << ARGV[0]
	end

	areas = {}
	files_enumerated.each do |file|
		unless File.exist?(file)
			puts "#{file} not found, skipping."
			next
		end
		#puts file
		areas[file] = Area.new(file, ARGV[1..-1])
	end

	areas.each do |file, area|
		next if area.nil?
		puts "Results for #{file}:"
		area.verify_all
		area.error_report
	end
else
	puts "Bzzzz".Y+"ZZZZZ".BY+"zz".Y+"ZZ".BY+"zzzzzzzz".Y+"ZZZZZ".BY+"zzzzz".Y
end
=end
