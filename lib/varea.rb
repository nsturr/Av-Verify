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
# or object not in the area, which might be intentional. "Cosmetic"
# displays any cosmetic errors such as text fields lacking a newline
# at the end, lines containing tabs, etc. "Nocolor" strips ANSI color
# codes from the output, which is handy if you're piping the output
# away from the console. If "areafile" ends in the extension ".lst"
# then the file is interpreted as an arefile list, and every area
# listed inside will be verified at once.
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

require './helpers/avconstants'
require './helpers/bits'
require './helpers/avcolors'
require './helpers/parsable'
require './helpers/area_attributes'

%w{ area_header area_data helps mobiles
	  objects rooms resets shops specials }.each do |section|
		require "./sections/#{section}"
end

class Area
	include Parsable
	include AreaAttributes

	def initialize(filename, flags=[])
		# How 'bout a little FILE, Scarecrow! >:D
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

		if data.end_with?("\#$")
			# If the correct ending char is found, strip it completely so none of the
			# section-parsing methods have to worry about it
			data.slice!(-2..-1)
		else
			err(total_lines, nil, "Area file does not end with \#$")
		end

		@main_sections = extract_main_sections(data)
	end

	def verify_all
		@main_sections.each do |section|
			next if section.parsed?
			puts "Found ##{section.name} on line #{section.line_number}" if @flags.include?(:debug)
			section.parse
			@errors += section.errors
		end
	end

	def error_report(nocolor=true)
		unless @errors.empty?
			nocolor = @flags.include?(:nocolor)

			errors, warnings, notices, cosmetic = 0, 0, 0, 0
			@errors.each do |item|
				errors += 1 if item.type == :error
				warnings += 1 if item.type == :warning
				notices += 1 if item.type == :nb
				cosmetic += 1 if item.type == :ugly
			end

			text_intro = errors > 0 ? "Someone's been a NAUGHTY builder!" : "Error report:"
			text_error = errors == 1 ? "1 error" : "#{errors} errors"
			text_warning = warnings == 1 ? "1 warning" : "#{warnings} warnings"
			text_cosmetic = cosmetic == 1 ? "1 cosmetic issue" : "#{cosmetic} cosmetic issues"

			unless nocolor
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
				if error.type == :error
					puts error.to_s(nocolor)
				elsif error.type == :warning && !@flags.include?(:nowarning)
					puts error.to_s(nocolor)
				elsif error.type == :nb && @flags.include?(:notices)
					puts error.to_s(nocolor)
				elsif error.type == :ugly && @flags.include?(:cosmetic)
					puts error.to_s(nocolor)
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

	def get_section(id)
		@main_sections.find { |section| section.id == id.upcase }
	end

	def extract_main_sections(data)
		lines_so_far = 1

		separated = data.split(/^(?=#[a-zA-Z\$]+)/)
		sections = []

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
			sections << new_section
		end

		sections.compact
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
		end

		unless SECTIONS.include? name.downcase
			err(line_num, nil, "Invalid section name ##{name}") and return
		end

		case name.downcase
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
