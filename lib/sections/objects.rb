  require_relative "vnum_section"
  require_relative "line_by_line_object"
  require_relative "../helpers/tilde"
  require_relative "../helpers/has_apply_flag"
  require_relative "../helpers/has_quoted_keywords"
  require_relative "../helpers/bits"

class Objects < VnumSection

  @section_delimiter = "^#0\\b" # N.B. some valid vnums regrettably begin with a 0

  def self.child_class
    Objekt
  end

  def initialize(contents, line_number)
    super(contents, line_number)
    @id = "OBJECTS"
  end

  def objects
    @entries
  end

end

class Objekt < LineByLineObject
  include HasApplyFlag
  include HasQuotedKeywords

  ATTRIBUTES = [:vnum, :name, :short_desc, :long_desc, :adesc, :type, :extra, :wear,
    :values, :weight, :worth, :apply, :edesc, :quality]

  attr_reader :line_number, *ATTRIBUTES

  def initialize(contents, line_number)
    super(contents, line_number)

    # Need the following instantiated as we'll be adding to them later
    @long_desc = ""
    @adesc = ""
    @values = []
    @apply = Hash.new(0)
    @edesc = {}

    # Temporary variables
    # @recent_keywords
    @long_line = 0 # For determining how many lines the long_desc spans
    # @last_multiline
  end

  def parse
    super
    if @expectation == :multiline_edesc
      err(@current_line, nil, "Edesc lacks terminating ~ between lines #{@last_multiline} and #{@current_line}")
    end
  end

  def parse_vnum line
    m = line.match(/#(?<vnum>\d+)/)
    if m
      @vnum = m[:vnum].to_i
      err(@current_line, line, "Invalid text before VNUM") if m.pre_match =~ /\S/
      err(@current_line, line, "Invalid text after VNUM") if m.post_match =~ /\S/
    else
      err(@current_line, line, "Invalid VNUM line")
    end
    expect :name
  end

  def parse_name line
    return if invalid_blank_line? line
    if has_tilde? line
      err(@current_line, line, tilde(:extra_text, "Object name")) unless trailing_tilde? line
    else
      err(@current_line, line, tilde(:absent_or_spans, "Object name"))
    end
    @name = parse_quoted_keywords(line[/\A[^~]*/], line, true, "object")
    expect :short_desc
  end

  def parse_short_desc line
    if line.empty?
      err(@current_line, nil, "Object short desc spans multiple lines")
    else
      ugly(@current_line, line, "Visible text contains a tab character") if line.include?("\t")
      if has_tilde? line
        err(@current_line, line, tilde(:extra_text, "Short desc")) unless trailing_tilde? line
      else
        err(@current_line, line, tilde(:absent_or_spans, "Short desc"))
      end
      @short_desc = line[/\A[^~]*/]
      expect :long_desc
    end
  end

  def parse_long_desc line
    ugly(@current_line, line, "Visible text contains a tab character") if line.include?("\t")
    @long_line += 1

    @long_desc << line

    if has_tilde? line
      expect :description
      if line =~ /~./
        err(@current_line, line, "Invalid text after terminating ~")
      end
    elsif @long_line == 2
      ugly(@current_line, line, "Long desc has more than one line of text")
    end
    expect :adesc
  end

  def parse_adesc line
    ugly(current_line, line, "Visible text contains a tab character") if line.include?("\t")

    if line =~ /^(\d+) +#{Bits.insert} +#{Bits.insert}$/
      err(@current_line, line, "Doesn't look like part of an adesc. Forget a ~ somewhere?")
      expect :type_extra_wear
      return :redo
    else
      @adesc << line
    end

    if has_tilde? line
      expect :type_extra_wear
      unless trailing_tilde? line
        err(@current_line, line, tilde(:extra_text, "Adesc"))
      end
    end
  end

  def parse_type_extra_wear line
    return if invalid_blank_line? line

    if m = line.match(/^(\d+) +(#{Bits.insert}) +(#{Bits.insert})$/)
      @type = m[1].to_i
      @extra = Bits.new(m[2])
      @wear = Bits.new(m[3])
      err(current_line, line, "Extra flag is not a power of 2") if @extra.error?
      err(current_line, line, "Wear flag is not a power of 2") if @wear.error?
    else
      err(current_line, line, "Line should follow syntax: <type:#> <extraflag:#> <wearflag:#>")
    end
    expect :values
  end

  def parse_values line
    return if invalid_blank_line? line

    values = line.split
    if values.length == 4
      values.each_with_index do |value, i|
        if value.match(/^(?:-?\d+|#{Bits.insert})$/)
          @values[i] = values
        else
          err(@current_line, line, "Invalid format for object value#{i}")
        end
      end
    else
      err(@current_line, line, "Wrong number of values in value0-3 line")
    end

    expect :weight_worth
  end

  def parse_weight_worth line
    return if invalid_blank_line? line

    @weight, @worth, zero = line.split(" ", 3)
    # err(@current_line, line, "Too many items in weight/worth line") if items.length > 3
    unless [@weight, @worth, zero].any? { |el| el.nil? } || zero != "0"
      err(@current_line, line, "Invalid object weight") unless @weight =~ /^\d+$/
      err(@current_line, line, "Invalid object worth") unless @worth =~ /^\d+$/
    else
      err(@current_line, line, "Line should follow syntax: <weight:#> <worth:#> 0")
    end

    # If we do this earlier, it'll turn invalid values to 0 and the validations
    # above won't catch them.
    @weight, @worth = @weight.to_i, @worth.to_i

    expect :misc
  end

  def parse_misc line
    return if invalid_blank_line? line

    case line.lstrip[0]
    when "A"
      # see HasApplyFlag module for details
      apply_index, apply_value = parse_apply_flag(line, @current_line)
      unless apply_index.nil?
        @apply[apply_index] += apply_value
      end
    when "Q"
      if line =~ /^Q +\d+/
        err(@current_line, line, "Invalid text after quality field") unless line =~ /^Q +\d+$/
      elsif line =~ /^Q +-\d+/
        err(@current_line, line, "Quality cannot be negative")
      else
        err(@current_line, line, "Invalid quality field")
      end
    when "E"
      err(@current_line, line, "Invalid text after E flag") if line.length > 1
      expect :edesc_keyword
    else
      err(@current_line, line, "Invalid extra field (expecting A, Q, or E)")
    end

  end

  def parse_edesc_keyword line
    if line.empty?
      err(@current_line, nil, "Object edesc keywords span multiple lines")
      return
    end

    unless has_tilde? line
      err(@current_line, line, tilde(:absent_or_spans, "Edesc keywords"))
    else
      if !trailing_tilde? line
        err(@current_line, line, tilde(:extra_text, "Edesc keywords"))
      end
    end

    keywords = parse_quoted_keywords(line[/[^~]*/], line)

    # The array of keywords will be they key to the edesc body
    @edesc[keywords] = ""
    # This will remember the key so that subsequent calls to parse_multiline_edesc
    # can shift their contents to the appropriate place.
    # Kind of kludgey but it's what I got going on...
    @recent_keywords = keywords

    @last_multiline = @current_line + 1 # The next line begins a multiline field
    expect :multiline_edesc
  end

  def parse_multiline_edesc line
    if has_tilde? line
      expect :misc
      unless trailing_tilde? line
        err(@current_line, line, tilde(:extra_text, "Edesc body"))
        unless isolated_tilde? line
          ugly(@current_line, line, tilde(:not_alone, "Edesc body"))
          @edesc[@recent_keywords] << line[/[^~]*/]
        end
      end
    end

    @edesc[@recent_keywords] << line[/[^~]*/]

  end

end
