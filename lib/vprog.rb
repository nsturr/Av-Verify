#!/usr/bin/env ruby

# Mob/Room/Lobster/Fun/Balloon Prog verifier by Scevine
#
# Usage: ruby vprog.rb filename [nocolor, nowarning, showdeprecated, showunknown]
#
# 'showdeprecated' will raise a stink over the use of QSTART, QSTATE, etc.
# 'showunknown' will raise warnings over any unknown trigger types
# 'nowarning' will answer the speculative theramin quasit aspect to the
#   downstairs quadrant neighborhood (n.b. it doesn't do that)
# 'nocolor' drains color from your face, making you look like a vampire
#   It DOES NOT give you fangs. use candy corns instead.
#
# Direct comments, suggestions, and rosemary bushes to
#   aaaaaaaaahh@ohmygod.bees
# or contact Scevine ingame, whichever.

# TODO:
#   Handle $f0 variables in function CALLS when parsing the parameter
#     Lower priority: determine if I care that much to do the above

require_relative 'helpers/progconstants'
require_relative 'helpers/avcolors'

class MobProg
  attr_reader :name, :t_mob, :t_room, :t_fun, :errors
  # Simple structs to encapsulate a section of data with its starting location
  # (line num) in the larger area file.
  Section = Struct.new(:line, :name, :data)
  Error = Struct.new(:line, :type, :context, :description)

  # Section holds either :progs_mob, :progs_room, or :progs_fun.
  # Type holds the 2-character trigger type
  # End is true if it's the last trigger in a section... only used to detect
  # misplaced #ends
  # Connections is an array of hashes representing connections to other trigs.
  # For instance, trigger[:connection] << [target_vnum, "FA", "panic_and_hide"]
  Trigger = Struct.new(:line, :vnum, :type, :end, :connections)
  # And here's that condition struct
  # Type can be :FA, :FC, :trigger_change, :trigger_chg_name, :trigger_mob,
  #   :trigger_room
  # If target is nil, then that means that the connection is a target
  # Line num is the line number, line is the actual text of the line
  Connection = Struct.new(:line_num, :target, :type, :src_trig, :parameter, :line)

  def initialize(filename, flags = [])

    @name = filename

    unless File.exist?(filename)
      puts "#{filename} not found, skipping."
      return nil
    end

    data = File.read(filename)
    total_lines = data.count("\n") + 1
    data.rstrip!

    @flags = flags.map {|item| item.downcase.to_sym}

    @errors = []
    @t_mob = []
    @t_room = []
    @t_fun = []

    # A hash (by vnum) of all conditions that can get activated by a function call
    @fun_prog_to = {} # Both progs and conditions
    # A hash (by vnum) of all conditions that use FC progs
    @fun_cond_from = {}
    # A hash (by vnum) of all mobprog actions that call FA progs
    @fun_prog_from = {}
    # A hash (by vnum) of all actions that act on trigger names and don't touch funcs
    # also includes trigger_room, despite the name
    @trigger_mob = {}

    if data.end_with?("\#$")
      # If the correct ending char is found, strip it completely so none of the
      # section-parsing methods have to worry about it
      data.slice!(-2..-1)
    else
      err(total_lines, nil, "Prog file does not end with \#$") unless data.end_with?("\#$")
    end

    @main_sections = find_main_sections(data)
  end

  def verify_all
    @main_sections.each {|section| verify_section(section)}
  end

  # This method makes the hashes of all known trigger connections (errors may cause
  # the list to be underpopulated) and makes sure that every target has a match.
  def correlate
    # So everyone's on the same page:
    # for Trigger... :type is the 2-letter trigger name
    # for Connection... :target is the vnum of whatever this connection points to. Nil means
    #   it's on the receiving end.
    #   :type is a symbol representing the type of connection (:FA :trigger_mob etc.)
    #   :parameter is the second bit of info the connection takes. For function calls,
    #   it's the fun_name, for trigger_mob or trigger_change, it's the 2-letter trigger name.
    #   :src_trig is the name of the trigger that makes the connection, for informational use only

    # First do the relatively simple check that every trigger_mob, trigger_change, etc
    # has a matching target trigger somewhere in the file
    @trigger_mob.each do |vnum, array|
      array.each do |command|
        case command[:type]
        when :trigger_mob, :trigger_change, :trigger_chg_name
          # Grab set of all mobprogs whose vnum matches this command's target
          targets = @t_mob.select {|pr| pr[:vnum] == command[:target]}
          unless targets.empty?
            # Now grab the set of THOSE mobprogs who have the trigger in question to modify
            targets.select!{|pr| pr[:type] == command[:parameter]}
            # If none are left, it means that the mobprog exists but doesn't have the right triggername
            unknown(command[:line_num], command[:line], "#{command[:type].capitalize} acts on a trigger that #{command[:target]} doesn't have: #{command[:parameter]}") if targets.empty?
          else # No vnum found! Bigger warning than just an unknown triggername
            warn(command[:line_num], command[:line], "#{command[:type].capitalize} targets a mob vnum not in the file")
          end
        when :trigger_room
          targets = @t_room.select{|pr| pr[:vnum] == command[:target]}
          unless targets.empty?
            targets.select!{|pr| pr[:type] == command[:parameter]}
            unknown(command[:line_num], command[:line], "#{command[:type].capitalize} acts on a trigger that #{command[:target]} doesn't have: #{command[:parameter]}") if targets.empty?
          else
            warn(command[:line_num], command[:line], "#{command[:type].capitalize} targets a room vnum not in the file")
          end
        end
        # In hidsight, this is a bit of an underwhelming 'case' statement, huh
      end
    end
    # Now do the more convoluted checking of fun_progs and called functions *head explodes*
    @fun_cond_from.each do |vnum, array| # Vnum will be an array of conditions of that vnum
      # Get all RECEIVING fun_conditions of the vnum that matches the target
      array.each do |prog|
        if @fun_prog_to.empty?
          warn(prog[:line_num], prog[:line], "No matching function for condition in ##{vnum}'s #{prog[:src_trig]} trigger")
          next
        elsif 
          @fun_prog_to[prog[:target]].nil?
          warn(prog[:line_num], prog[:line], "No matching function for condition in from ##{vnum}'s #{prog[:src_trig]} trigger")
          next
        end
        targets = Array.new(@fun_prog_to[prog[:target]])
        # Then select from them
        # In this case, :parameter is the name of the fun, and :type is the 2-letter trigger name
        targets.select!{|pr| pr[:parameter] == prog[:parameter] && pr[:type] == prog[:type]}
        if targets.empty?
          warn(prog[:line_num], prog[:line], "No matching function for condition in ##{vnum}'s #{prog[:src_trig]} trigger")
        end
      end
    end
    @fun_prog_from.each do |vnum, array| # Vnum will be an array of conditions of that vnum
      # Get all RECEIVING fun_actions of the vnum that matches the target
      array.each do |prog|
        # A wee bit of checking that these hashes/arrays actually exist!
        if @fun_prog_to.empty?
          warn(prog[:line_num], prog[:line], "No matching function for function call from ##{vnum}'s #{prog[:src_trig]} trigger")
          next
        elsif @fun_prog_to[prog[:target]].nil?
          warn(prog[:line_num], prog[:line], "No matching function for function call from ##{vnum}'s #{prog[:src_trig]} trigger")
          next
        end
        targets = Array.new(@fun_prog_to[prog[:target]])

        # Then select from them
        # In this case, :parameter is the name of the fun, and :type is the 2-letter trigger name
        targets.select!{|pr| pr[:parameter] == prog[:parameter] && pr[:type] == prog[:type]}
        if targets.empty?
          # The 'unless' to this warning is if the parameter is the funprog variables
          # $f0 - $f9, which will never match any sort of fun_name
          warn(prog[:line_num], prog[:line], "No matching function for function call from ##{vnum}'s #{prog[:src_trig]} trigger") unless prog[:parameter] =~ /^\$f\d$/
        end
      end
    end
  end

  def error_report
    unless @errors.empty?
      errors = warnings = deprecated = unknown = 0
      @errors.each do |item|
        errors += 1 if item[:type] == :error
        warnings += 1 if item[:type] == :warning
        deprecated += 1 if item[:type] == :deprecated
        unknown += 1 if item[:type] == :unknown
      end

      text_intro = errors > 0 ? "Someone's been a NAUGHTY builder!" : "Error report:"
      text_error = errors == 1 ? "1 error" : "#{errors} errors"
      text_warning = warnings == 1 ? "1 warning" : "#{warnings} warnings"
      text_deprecated = deprecated == 1 ? "1 deprecated command" : "#{deprecated} deprecated commands"
      text_unknown = unknown == 1 ? "1 unknown trigger" : "#{unknown} unknown triggers"

      unless @flags.include?(:nocolor)
        # Apply some color codes
        text_error.BR!
        text_warning.R!
        text_deprecated.Y!
        text_unknown.C!
      end

      summary = "#{text_intro} #{text_error}, #{text_warning}."
      if deprecated > 0
        summary.chop!
        summary += ", #{text_deprecated}."
      end
      if unknown > 0
        summary.chop!
        summary += ", #{text_unknown}."
      end
      puts summary

      suppressed = 0
      @errors.each do |error|
        if error[:type] == :error
          puts format_error(error, :BR)
        elsif error[:type] == :warning && !@flags.include?(:nowarning)
          puts format_error(error, :R)
        elsif error[:type] == :deprecated && @flags.include?(:showdeprecated)
          puts format_error(error, :Y)
        elsif error[:type] == :unknown && @flags.include?(:showunknown)
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

  def find_main_sections(data)
    lines_so_far = 1

    separated = data.split(/^(?=#PROG)/i) # All sections conveniently start with this
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

      first_line = content.slice!(/\A.*(?:\n|\Z)/).rstrip
      name = first_line.match(/(?<=#)\S+/).to_s.upcase

      unless SECTIONS.include?(name) || name.empty?
        err(line_start_section, nil, "Invalid section ##{name}")
        next #Don't parse an unknown section
      end

      unless first_line =~ /^#\S+$/ || name.empty?
        err(line_start_section, first_line, "Invalid text on same line as section name")
      end

      line_start_section += 1 # Take into account that we just sliced off the first line
      sections << Section.new(line_start_section, name, content)
    end
    sections
  end

  def err(line, context, description)
    error = Error.new(line, :error, context, description)
    @errors << error
    error
  end

  def warn(line, context, description)
    error = Error.new(line, :warning, context, description)
    @errors << error
    error
  end

  def unknown(line, context, description)
    error = Error.new(line, :unknown, context, description)
    @errors << error
    error
  end

  def dep(line, context, description)
    error = Error.new(line, :deprecated, context, description)
    @errors << error
    error
  end

  # This splits an entire #PROGS_MOB or #PROGS_ROOM section into
  # blocks of single triggers, then checks them individually
  def verify_section(section)
    section_name = section[:name].to_sym
    lines_so_far = section[:line]
    # Temp variable for triggers before they get added
    trigger = nil
    # Temp variable for most current vnum
    vnum = 0
    section_end = false

    # All blocks of triggers should begin with the word... begin
    blocks = section[:data].split(/^(?=begin)/i)

    blocks.each do |block|


      current_line = lines_so_far
      lines_in_section = block.count("\n")
      lines_so_far += lines_in_section

      trigger = verify_trigger(block.rstrip, current_line, section_name, section_end)
      # This might come back nil if verify_trigger detected that the section ended
      # It's okay to return because we've already thrown an error about it, so no
      # need to parse anything that follows it
      return if trigger.nil?

      # If this trigger returns with its :end bit checked, that means it's
      # the end of the section, and all subsequent blocks will throw an error
      if trigger[:end] == true
        section_end = true
      end

      # If the vnum was valid, push the trigger onto the appropriate hash
      # But first check that no trigger exists for the same vnum with the same type
      if trigger[:vnum] != 0 && !trigger[:type].nil?
        if section_name == :PROGS_MOB
          exist = @t_mob.select{|t| t[:vnum] == trigger[:vnum] && t[:type] == trigger[:type]}
          unless exist.empty?
            err(trigger[:line], nil, "#{trigger[:type].upcase} trigger already exists for mob #{trigger[:vnum]} on line #{exist[0][:line]}")
          end
          @t_mob << trigger
        elsif section_name == :PROGS_ROOM
          exist = @t_room.select{|t| t[:vnum] == trigger[:vnum] && t[:type] == trigger[:type]}
          unless exist.empty?
            err(trigger[:line], nil, "#{trigger[:type].upcase} trigger already exists for room #{trigger[:vnum]} on line #{exist[0][:line]}")
          end
          @t_room << trigger
        elsif section_name == :PROGS_FUN
          exist = @t_fun.select{|t| t[:vnum] == trigger[:vnum] && t[:type] == trigger[:type]}
          unless exist.empty?
            err(trigger[:line], nil, "#{trigger[:type].upcase} trigger already exists for func #{trigger[:vnum]} on line #{exist[0][:line]}")
          end
          @t_fun << trigger
        end
      end
    end #iterating through blocks of a section
    err(lines_so_far, nil, "#{section_name} has no #End") unless section_end || section_name.empty?
  end

  def verify_trigger(block, line_num, section_type, ended=false)
    current_line = line_num
    section_end = ended
    # This might get thrown out if its :vnum or :type fields are empty
    trigger = Trigger.new(current_line)
    trigger[:connections] = []
    connection = nil # Will get added to trigger's connection field unless it stays nil

    # Holds a symbol for the last line parsed. Can be:
    # nothing, begin, t, c, amp, pipe, d, f, action, e, q
    last_line = :nothing
    # The following hash, keyed by last_line, will be interpolated into the error
    # string: "Invalid line, expected #{expected[last_line]}"
    expected = {
      nothing: "comments starting with * or 'begin <vnum>'",
      begin: "T <xx>",
      t: "value line, or C or D conditions",
      v: "value line, or C or D conditions",
      c: "another C or & condition, |, F, return, action, or pause lines",
      amp: "&, |, F, return, action, or pause lines",
      r: "F, action, or pause lines",
      pipe: "C condition",
      d: "F, return, action, or pause lines",
      f: "action or pause lines",
      action: "another A or P line, or E",
      pause: "another A or P line",
      e: "C or D condition, or Q",
      q: "end <vnum>"
    }

    # Descriptions of the line that preceded the current one
    before = {
      nothing: "the last prog ends",
      begin: "begin <vnum>",
      t: "trigger type",
      v: "trigger value",
      c: "C condition",
      r: "R return line",
      amp: "& condition",
      pipe: "pipe",
      d: "D condition",
      f: "F flag",
      action: "action",
      pause: "pause",
      e: "E line",
      q: "Q line"
    }

    block.each_line do |line|
      line.rstrip!

      # When reading regexps and .empty? calls, remember that we've rstripped
      # whitespace on every single line.

      # If line is blank ignore.
      if line.empty?
        current_line += 1
        next
      end

      # If line is a comment ignore
      if line.lstrip.start_with?("*")
        current_line += 1
        next
      end

      if section_end
        err(current_line, line, "Section continues after terminating #END line")
        return trigger
      end

      # Branch based on the first word of the line
      case line.split(" ", 2)[0].upcase
      when "BEGIN"
        # Start by throwing error if the line is not the first non-blank non-comment line
        unless last_line == :nothing
          err(current_line, line, "Unexpected 'begin'. Attempting to begin new trigger inside existing one?")
          current_line += 1
          next
        end
        # Now do actual parsing
        if parse_line(line, :begin, last_line, current_line, trigger, section_type) == false
          # Ignore the rest of the trigger, because all other errors will
          # be garbage without a vnum set
          last_line = :nothing
          break
        end
        last_line = :begin
      when "T"
        # T <xx> can only follow a begin line
        unless last_line == :begin
          err(current_line, line, "Invalid line. After #{before[last_line]}, expected #{expected[last_line]}")
          current_line += 1
          next
        end
        if parse_line(line, :t, last_line, current_line, trigger, section_type) == false
          # Ignore the rest of the trigger, because all other errors will
          # be garbage
          last_line = :nothing
          break
        end
        last_line = :t
      when "V"
        # V <d>-<type> [options] can only follow a T or other V lines
        unless [:t, :v].include?(last_line)
          err(current_line, line, "Invalid line. After #{before[last_line]}, expected #{expected[last_line]}")
          current_line += 1
          next
        end
        # TODO: add a way to parse a v line
        last_line = :v
      when "C"
        # C can only follow a T, C, |, or E line
        unless [:t, :c, :pipe, :e].include?(last_line)
          err(current_line, line, "Invalid line. After #{before[last_line]}, expected #{expected[last_line]}")
          current_line += 1
          next
        end
        # Any inter-trigger connection will be returned by parse_line
        connection = parse_line(line, :c, last_line, current_line, trigger, section_type)
        last_line = :c
      when "&"
        # & can only follow a C or other & line
        unless [:c, :amp].include?(last_line)
          err(current_line, line, "Invalid line. After #{before[last_line]}, expected #{expected[last_line]}")
          current_line += 1
          next
        end
        # Any inter-trigger connection will be returned by parse_line
        connection = parse_line(line, :amp, last_line, current_line, trigger, section_type)
        last_line = :amp
      when "|"
        unless [:c, :amp].include?(last_line)
          err(current_line, line, "Invalid line. After #{before[last_line]}, expected #{expected[last_line]}")
          current_line += 1
          next
        end
        err(current_line, line, "Invalid text after pipe") if line.split.length > 1
        last_line = :pipe
      when "D"
        unless [:t, :e].include?(last_line)
          err(current_line, line, "Invalid line. After #{before[last_line]}, expected #{expected[last_line]}")
          current_line += 1
          next
        end
        err(current_line, line, "Invalid text after D condition") if line.split.length > 1
        last_line = :d
      when "R"
        unless [:c, :amp, :d].include?(last_line)
          err(current_line, line, "Invalid line. After #{before[last_line]}, expected #{expected[last_line]}")
          current_line += 1
          next
        end
        last_line = :r
      when "F"
        if last_line == :t
          err(current_line, nil, "F flag immediately follows a trigger type line. Forget a D line?")
        elsif [:r, :action, :pause].include?(last_line)
          err(current_line, nil, "F flag can not be preceded by actions or pauses")
          current_line += 1
          next
        elsif ![:c, :amp, :d].include?(last_line)
          err(current_line, line, "Invalid line. After #{before[last_line]}, expected #{expected[last_line]}")
          current_line += 1
          next
        end
        err(current_line, line, "Invalid text after F flag") if line.split.length > 1
        last_line = :f
      when "A"
        # Actions can only come after C, &, or D conditions, F lines, or other actions
        if last_line == :t
          err(current_line, line, "Action line immediately follows a trigger type line. Forget a D line?")
        elsif ![:r, :c, :amp, :d, :f, :action, :pause].include?(last_line)
          err(current_line, line, "Invalid action. After #{before[last_line]}, expected #{expected[last_line]}")
          current_line += 1
          next
        end
        # Any inter-trigger connection will be returned by parse_line
        connection = parse_line(line, :a, last_line, current_line, trigger, section_type)
        last_line = :action
      when "P"
        unless [:r, :c, :amp, :d, :f, :action, :pause].include?(last_line)
          err(current_line, nil, "Invalid line. After #{before[last_line]}, expected #{expected[last_line]}")
          current_line += 1
          next
        end
        parse_line(line, :p, last_line, current_line, trigger, section_type)
        last_line = :pause
      when "E"
        unless [:action, :pause].include?(last_line)
          err(current_line, nil, "E line can only occur after mobprog actions")
          current_line += 1
          next
        end
        err(current_line, line, "Invalid text after E line") if line.split.length > 1
        warn(current_line, nil, "Don't end a mobprog with a pause") if last_line == :pause
        last_line = :e
      when "Q"
        unless last_line == :e
          err(current_line, nil, "Q can only occur after an E line")
          current_line += 1
          next
        end
        err(current_line, line, "Invalid text after Q line") if line.split.length > 1
        last_line = :q
      when "END"
        unless last_line == :q
          err(current_line, nil, "end <vnum> line can only occur after a Q line")
          current_line += 1
          next
        end
        parse_line(line, :end, last_line, current_line, trigger, section_type)
        last_line = :nothing # Finally break out of a block, and allow comments again
      when "#END"
        section_end = true
        trigger[:end] = true
        err(current_line, nil, "Section #ENDs inside an incomplete mobprog!") unless last_line == :nothing
        err(current_line, line, "Invalid text on same line as \#End delimiter") unless line.upcase =~ /^#END$/
      else
        err(current_line, line, "Invalid line, expected #{expected[last_line]}")
      end

      unless connection.nil?
        if [:trigger_mob, :trigger_room, :trigger_change, :trigger_chg_name].include?(connection[:type])
          @trigger_mob[trigger[:vnum]] ||= []
          @trigger_mob[trigger[:vnum]] << connection
        elsif connection[:type] == :FC
          # For CONDITIONS
          if connection[:target].nil?
            @fun_prog_to[trigger[:vnum]] ||= []
            @fun_prog_to[trigger[:vnum]] << connection
          else
            @fun_cond_from[trigger[:vnum]] ||= []
            @fun_cond_from[trigger[:vnum]] << connection
          end
        else
          # FOR ACTIONS/PROGS
          if connection[:target].nil?
            @fun_prog_to[trigger[:vnum]] ||= []
            @fun_prog_to[trigger[:vnum]] << connection
          else
            @fun_prog_from[trigger[:vnum]] ||= []
            @fun_prog_from[trigger[:vnum]] << connection
          end
        end
        trigger[:connections] << connection
        connection = nil
      end


      current_line += 1
    end #iterating through lines of a block
    trigger
  end

  # Parsing method for multi-char lines (i.e. not D, F, |, E etc)
  # Returns any connection found in a the line. Otherwise returns nil.
  # Only a few calls of this method actually assign its result to anything, though
  # N.B. returns false in the event that the calling method should break
  # (Currently only if a T <xx> line has no trigger at all, in which case the entire
  # block of mobprog text is skipped)
  def parse_line(line, type, last_line, current_line, trigger, section_type=:progs_mob)
    # This will get returned. If no connection found in line, it will stay nil.
    connection = nil

    case type
    when :begin
      items = line.split(" ", 3) # Max length 3 to account for possible invalid text
      if items.length > 1
        if items[1] =~ /^\d+$/
          vnum = items[1].to_i
        else
          err(current_line, line, "Invalid vnum in #{section_type}")
          vnum = items[1] # Can't to_i a non-number
        end
        # Even if it doesn't match the regexp above, still fill trigger[:vnum]
        trigger[:vnum] = vnum
        if items.length == 3
          err(current_line, line, "Invalid text after vnum") unless items[2].start_with?("*")
        end
      else # If line only consists of "begin"
        err(current_line, line, "No vnum specified for this 'begin' line")
        return false
      end
    when :end
      items = line.split(" ", 3) # Max length 3 to account for possible invalid text
      if items.length > 1
        if items[1] =~ /^\d+$/
          err(current_line, line, "Starting and ending vnums do not match: #{trigger[:vnum]} != #{items[1]}") unless items[1].to_i == trigger[:vnum]
        else
          err(current_line, line, "Invalid vnum")
        end
        err(current_line, line, "Invalid text after vnum") if items.length == 3
      else
        err(current_line, line, "No vnum specified for this 'end' line")
        # No need to return false. There are probably no more lines in the trigger
        # block that we need to skip over.
      end
    when :t
      items = line.split(" ", 3) # Max length 3 to account for possible invalid text
      if items.length > 1
        if items[1] =~ /^[a-z][a-z0-9]$/i
          trigger[:type] = items[1].upcase
          unknown(current_line, nil, "Unknown trigger type: #{trigger[:type]} for vnum #{trigger[:vnum]}") unless TRIGGERS.include?(items[1])
          err(current_line, line, "Invalid text after trigger type") if items.length == 3
        else
          err(current_line, nil, "Invalid trigger type: #{items[1]}")
        end
      else
        err(current_line, line, "Missing trigger type, expected 'T <xx>'")
        return false
      end
    when :a
      if line.count("~") == 1
          warn(current_line, line, "Action line continues after terminating ~") unless line.end_with?("~")
        elsif line.count("~") > 1
          warn(current_line, line, "Action line has too many ~")
        else
          err(current_line, line, "Action line lacks ~")
      end
      # In preparation for parsing a connection, get rid of any combination of !P !Q !L flags
      # see progconstants.rb to add additional flags to AFLAGS variable
      pared_line = line.sub(/(\s![#{AFLAGS}]+)+\b/i, "")
      pared_line.chop! if pared_line.end_with?("~")
      items = pared_line.split(" ", 4)
      if items.length > 1
        # Check if we're starting a function call in form of A #VNUM FA function~
        if m = items[1].match(/^#(\d+)$/)
          if items.length == 4
            err(current_line, line, "Trigger name (should be FA) is not 2 characters") if items[2].length != 2
            param = items[3].split[0]
            connection = Connection.new(current_line, m[1].to_i, items[2].upcase.to_sym, trigger[:type], param, line)
          else
            err(current_line, line, "Not enough tokens on function call: A #vnum FA functionname~")
          end
        # Now check for easier connections to match...
        elsif m = pared_line.match(/trigger_mob\s+(\w+)\s+(\w+)/i)
          if m[1] =~ /^\d+$/
            err(current_line, line, "Invalid trigger name in 'trigger_mob' statement") unless m[2] =~ /^[a-z][a-z0-9]$/i
            connection = Connection.new(current_line, m[1].to_i, :trigger_mob, trigger[:type], m[2], line)
          else
            err(current_line, line, "Invalid vnum after 'trigger_mob'")
          end
        elsif m = pared_line.match(/trigger_room\s+(\w+)\s+(\w+)/i)
          if m[1] =~ /^\d+$/
            err(current_line, line, "Invalid trigger name in 'trigger_room' statement") unless m[2] =~ /^[a-z][a-z0-9]$/i
            connection = Connection.new(current_line, m[1].to_i, :trigger_room, trigger[:type], m[2], line)
          else
            err(current_line, line, "Invalid vnum after 'trigger_mob'")
          end
        elsif m = pared_line.match(/trigger_change\s+(\w+)\s+(\w+)\s+(\w+)/i)
          if m[1] =~ /^\d+$/
            err(current_line, line, "Invalid old trigger name in 'trigger_change' statement") unless m[2] =~ /^[a-z][a-z0-9]$/i
            err(current_line, line, "Invalid new trigger name in 'trigger_change' statement") unless m[3] =~ /^[a-z][a-z0-9]$/i
            connection = Connection.new(current_line, m[1].to_i, :trigger_change, trigger[:type], m[2], line)
          else
            err(current_line, line, "Invalid vnum after 'trigger_change")
          end
        elsif m = pared_line.match(/trigger_chg_name\s+(\w+)\s+(\w+)/i)
          if m[1] =~ /^\d+$/
            err(current_line, line, "Invalid trigger name in 'trigger_chg_name' statement") unless m[2] =~ /^[a-z][a-z0-9]$/i
            connection = Connection.new(current_line, m[1].to_i, :trigger_chg_name, trigger[:type], m[2], line)
          else
            err(current_line, line, "Invalid vnum after 'trigger_chg_name")
          end
        end
      end
    when :p
      items = line.split(" ", 3) # 3rd item is invalid text, which hopefully doesn't exist
      if items.length > 1
        if not items[1] =~ /^-?\d+$/
          err(current_line, line, "Invalid pause amount")
        elsif items[1] =~ /^-1$/
          err(current_line, nil, "Only the first pause in a mobprog can be 'P -1'") if last_line == :action
        elsif items[1].start_with? "-"
          err(current_line, line, "The only negative pause allowed is -1")
        end
        err(current_line, line, "Invalid text after pause") if items.length == 3
      else
        err(current_line, nil, "Pause line lacks duration")
      end
    when :c
      items = line.split(" ", 4)
      if items.length > 3
        connection = parse_condition(line, current_line, trigger[:type], section_type)
      else
        err(current_line, line, "Incomplete condition, expected 'C <condition> <operator> <value>'")
      end
    when :amp
      items = line.split(" ", 4)
      if items.length > 3
        connection = parse_condition(line, current_line, trigger[:type], section_type)
      else
        err(current_line, line, "Incomplete condition, expected '& <condition> <operator> <value>'")
      end
    end

    return connection
  end

  def parse_condition(line, current_line, type=nil, section_type=:progs_mob)
    # Text arguments can be multi-word, so can't leave an extra token to dump
    # invalid text into...
    items = line.split(" ", 4)
    # We've already done checking that the line contains this many tokens
    # in the method we call this from
    condition = items[1].downcase
    operator = items[2]
    value = items[3]

    connection = nil # This gets returned. If it stays nil, there's no connection to be had.

    # Check that the condition type is valid.
    # Unlike unknown trigger names, bad conditions will cause errors

    # First, check for good conditions
    if condition.start_with?("#") || condition.start_with?("qvar") || condition.start_with?("wear_") || C_ALL.include?(condition)

    elsif C_DEPRECATED.include?(condition) || condition.start_with?("qstate")
      dep(current_line, line, "Deprecated quest tracking condition")
    elsif C_FUN.include?(condition)
      if condition == "fun_name"
        # Create a connection that we'll return
        # Target is nil because this is on the receiving end
        # Type should be FA, though other trigger names are valid (are they valid ingame though?)
        #puts value
        err(current_line, line, "The condition 'fun_name' must be on a C condition, not &") if line[0] == "&"

        # The reason there's a regex in the 'value' variable below is because there might
        # be more than one word here, and only the first one is the name of the function
        connection = Connection.new(current_line, nil, type.to_sym, type, value[/^[\S]+/], line)
      end
      err(current_line, line, "Function arguments are invalid outside of #PROGS_FUN") unless section_type == :PROGS_FUN
    else
      err(current_line, line, "Invalid condition type")
    end

    # Check that the operator is valid
    if condition.start_with?("#")
      # This is a function condition of syntax: C #VNUM = FC fun_name
      if value.end_with?("~")
        value.chop!
      else
        err(current_line, line, "Function condition call does not end with ~")
      end
      if m = condition.match(/^#(\d+)$/)
        # Create a new connection with the matched vnum as the target
        # Type of connection is fun_condition
        param = value.split[1]
        connection = Connection.new(current_line, m[1].to_i, :FC, type, param, line)
        if @flags.include? :debug
          puts "Found connection: #{line}"
          puts "To vnum #{connection[:target]} as a #{connection[:type]} with param #{connection[:parameter]}"
        end
        err(current_line, line, "Not enough tokens for fun_condition (FC conditionname [args...])") unless value.split(" ", 2).length == 2
      else
        err(current_line, line, "Invalid VNUM in function condition")
      end
    elsif !condition.start_with?("qstate")
      err(current_line, line, "Invalid operator in condition check") unless OPERATORS.include?(operator)
    elsif condition == "qvar"
      # Without a value tacked onto 'qvar' the only valid operators are = and !=
      err(current_line, line, "Wrong operator used for qvar comparison") unless ["=", "!="].include?(operator)
    else
      # Condition starts with qstate in this case. It can have an extra operator '!'
      err(current_line, line, "Invalid operator in condition check") unless (OPERATORS + ["!"]).include?(operator)
    end

    # Now check the value. And in the case of qvar-val, the token attached to qvar as well
    if condition.start_with?("qvar-")
      # Split the condition up by hyphens.
      conditions = condition.split("-", 2)
      # Do the same for ####-variablename. In this case, the value HAS to have something
      # after the -
      vars = value.split("-", 2)

      if conditions.length == 2
        # Check that the condition doesn't look like "qvar-"
        err(current_line, line, "No value appending qvar-_________") if conditions[1] == ""

        err(current_line, line, "Invalid (non-numeric) qnum") unless vars[0] =~ /^\d+$/
        if vars.length == 2
          # This is if the value looks like: qnum-
          err(current_line, line, "No variable name to compare value '#{conditions[1]}' against") if vars[1] == ""
          err(current_line, line, "Invalid characters in variable name") if vars[1] =~ /[^\w\-\$]/i
          err(current_line, line, "Invalid text after trigger condition") if vars[1].include? " "
        elsif vars[0] =~ /^\d+$/
          # This is if the value is just a qnum
          err(current_line, line, "No variable name to compare value '#{conditions[1]}' against")
        end
      end

    elsif condition == "qvar"
      # Split the value up by hyphens. A valid value will either be a single number and not be split up,
      # or a single number and an alphanumeric word separated by a single hyphen
      vars = value.split("-", 2)
      err(current_line, line, "Invalid (non-numeric) qnum") unless vars[0] =~ /^\d+$/
      if vars.length == 2
        err(current_line, line, "Invalid characters in variable name") if vars[1] =~ /[^\w\-\$]/i
        err(current_line, line, "Missing variable name after hyphen") if vars[1] == ""
        err(current_line, line, "Invalid text after trigger condition") if vars[1].include? " "
      end
    elsif condition.start_with?("wear_v")
      # Check for the item value condition
      if m = condition.match(/^wear_v(\d+)_(-?\d+)/)
        warn(current_line, line, "Object value index out of bounds 0 to 3") unless m[1].to_i.between?(0,3)
        warn(current_line, line, "Wear location in condition out of bounds 0 to #{EQSLOT_MAX}") unless m[2].to_i.between?(0, EQSLOT_MAX)
        err(current_line, line, "Invalid (non-numeric) object value") unless value =~ /^-?\d+$/
      else
        err(current_line, line, "Invalid wear-value condition. Syntax should be: wear_v#_#")
      end
    elsif condition.start_with?("wear_")
      # Check for the wear slot condition
      if m = condition.match(/^wear_(\d+)$/i)
        warn(current_line, line, "Wear location in condition out of bounds 0 to #{EQSLOT_MAX}") unless m[1].to_i.between?(0, EQSLOT_MAX)
        err(current_line, line, "Invalid (non-numeric or negative) object VNUM") unless value =~ /^\d+$/
      else
        err(current_line, line, "Invalid wear condition. Syntax should be: wear_# or wear_v#_#")
      end
    elsif C_NUM.include?(condition)
      # Check first that the value is numeric
      if value =~ /^-?\d+$/
        # Now do some condition specific checks
        case condition
        when "sunlight"
          warn(current_line, line, "Sunlight condition out of bounds 0 to #{SUNLIGHT_MAX}") unless value.to_i.between?(0,SUNLIGHT_MAX)
        when "sky"
          warn(current_line, line, "Sky condition out of bounds 0 to #{SKY_MAX}") unless value.to_i.between?(0, SKY_MAX)
        when "mhour"
          warn(current_line, line, "Hour out of bounds 0 to 23") unless value.to_i.between?(0,23)
        when "mday"
          warn(current_line, line, "Mud day out of bounds 0 to #{MDAY_MAX}") unless value.to_i.between?(0, MDAY_MAX)
        when "mmonth"
          warn(current_line, line, "Mud month out of bounds 0 to #{MMONTH_MAX}") unless value.to_i.between?(0, MMONTH_MAX)
        when "minute"
          warn(current_line, line, "Minute out of bounds 0 to 59") unless value.to_i.between?(0,59)
        when "hour"
          warn(current_line, line, "Hour out of bounds 0 to 23") unless value.to_i.between?(0,23)
        when "weekday"
          warn(current_line, line, "Weekday out of bounds 0 to 6") unless value.to_i.between?(0,6)
        when "day"
          warn(current_line, line, "Calendar day out of bounds 1 to 31") unless value.to_i.between?(1,31)
        when "month"
          warn(current_line, line, "Calendar month out of bounds 1 to 12") unless value.to_i.between?(1,12)
        end
      elsif value =~ /^\$f[0-9]$/i
        err(current_line, line, "Function arguments are invalid outside of #PROGS_FUN") unless section_type == :PROGS_FUN
      else # value is not numeric
        err(current_line, line, "Value for #{condition} condition must be numeric")
      end
    # Is there even a need to distinguish between text that requires quotes and
    # text that doesn't, anymore? I dare say there is not.
    elsif C_TEXT.include?(condition)
      if value =~ /^\$f[0-9]$/i
        err(current_line, line, "Function arguments are invalid outside of #PROGS_FUN") unless section_type == :PROGS_FUN
      end
      # Here we check for proper quotation. Only text conditions and command conditions IN A KS TRIGGER need quotes.
      # Firstly, if there are anything other than 2 or 0 quotes in the line, something's terribly amiss!
      if value.count("\"") != 2 && value.count("\"") != 0
        err(current_line, line, "Misplaced quotes in condition line")
      # Now check for a multi-word value
      elsif value.include?(" ")
        # And only text conditions need it, as well as a command condition in a KS trig
        if condition == "text" || (condition == "command" && type == "KS")
          err(current_line, line, "Multi-word text comparisons must be in double quotes") unless value.start_with?("\"") && value.end_with?("\"")
        # Regular command conditions don't need them. But I don't think they mess anything up,
        # (kreig.prg has lots of single-word KS commands in quotes and nothing has broken)
        # so commenting it out.
        elsif condition == "command"
          #warn(current_line, line, "Command conditions don't need quotes unless trigger is KS") if value.start_with?("\"") && value.end_with?("\"")
        end
      end
      # Apparently I forgot that the < > operators actuall do work for
      # text checks (for checking prefixes and suffixes)
      # err(current_line, line, "Wrong operator used with text comparison") if [">", "<"].include?(operator)
    end

    return connection
  end # End parse_condition

end

if ARGV[0]
  if File.exist?(ARGV[0])
    puts "Parsing #{ARGV[0]}..."
    new_prog = MobProg.new(ARGV[0], ARGV[1..-1])
    new_prog.verify_all
    new_prog.correlate
    new_prog.error_report
  else
    puts "#{ARGV[0]} not found, skipping."
  end
end
