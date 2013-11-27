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
    @id = "objects"
  end

  def to_s
    "#OBJECTS: #{self.objects.size} entries, line #{self.line_number}"
  end

  def objects
    @entries
  end

end

class Objekt < LineByLineObject
  include HasApplyFlag
  include HasQuotedKeywords

  @ERROR_MESSAGES = {
    visible_tab: "Visible text contains a tab character",
    invalid_text_after: "Invalid text after %s",
    # tilde_absent: "%s has no terminating ~",
    # tilde_absent_or_spans: "%s has no terminating ~ or spans multiple lines",
    # tilde_invalid_text: "Invalid text after terminating ~",
    # tilde_not_alone: "%s's terminating ~ should be on its own line",
    short_desc_spans: "Object short desc spans multiple lines",
    long_desc_spans: "Long desc has more than one line of text",
    adesc_no_tilde: "Doesn't look like part of an adesc. Forget a ~ somewhere?",
    edesc_no_tilde: "Edesc lacks terminating ~ between lines %s and %s",
    bad_bit: "%s not a power of 2",
    bad_field: "Invalid %s field",
    type_extra_wear_matches: "Line should follow syntax: <type:#> <extraflag:#> <wearflag:#>",
    weight_worth_matches: "Line should follow syntax: <weight:#> <worth:#> 0",
    bad_value: "Invalid format for object value%i",
    wrong_number_of_values: "Wrong number of values in value0-3 line",
    negative: "%s cannot be negative",
    invalid_extra_field: "Invalid extra field (expecting A, Q, or E)",
    edesc_keyword_spans: "Object edesc keywords span multiple lines",

  }

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

  def to_s
    "<Object: vnum #{self.vnum}, #{self.short_desc}, line #{self.line_number}>"
  end

  def parse
    super
    if @expectation == :multiline_edesc
      err(@current_line, nil, Objekt.err_msg(:edesc_no_tilde) % [last_multiline, @current_line])
    end
    self
  end

  def parse_vnum line
    m = line.match(/#(?<vnum>\d+)/)
    # To even be created, an Object has to have a valid vnum
    @vnum = m[:vnum].to_i
    expect :name
  end

  def parse_name line
    return if invalid_blank_line? line
    validate_tilde(
      line: line,
      line_number: @current_line,
      might_span_lines: true
    )
    # if has_tilde? line
    #   err(@current_line, line, Objekt.err_msg(:tilde_invalid_text)) unless trailing_tilde? line
    # else
    #   err(@current_line, line, Objekt.err_msg(:tilde_absent_or_spans) % "Object name")
    # end
    @name = parse_quoted_keywords(line[/\A[^~]*/], line, true, "object")
    expect :short_desc
  end

  def parse_short_desc line
    if line.empty?
      err(@current_line, nil, Objekt.err_msg(:short_desc_spans))
    else
      ugly(@current_line, line, Objekt.err_msg(:visible_tab)) if line.include?("\t")
      validate_tilde(
        line: line,
        line_number: @current_line,
        might_span_lines: true
      )
      # if has_tilde? line
      #   err(@current_line, line, Objekt.err_msg(:tilde_invalid_text)) unless trailing_tilde? line
      # else
      #   err(@current_line, line, Objekt.err_msg(:tilde_absent_or_spans) % "Short desc")
      # end
      @short_desc = line[/\A[^~]*/]
      expect :long_desc
    end
  end

  def parse_long_desc line
    ugly(@current_line, line, Objekt.err_msg(:visible_tab)) if line.include?("\t")
    @long_line += 1

    @long_desc << line << "\n"

    # TODO: Use validate_tilde to some degree
    if has_tilde? line
      expect :adesc
      if line =~ /~./
        err(@current_line, line, TheTroubleWithTildes.err_msg(:extra_text))
      end
    end
    if @long_line == 2
      ugly(@current_line, line, Objekt.err_msg(:long_desc_spans))
    end
  end

  def parse_adesc line
    ugly(current_line, line, Objekt.err_msg(:visible_tab)) if line.include?("\t")

    if line =~ /^(\d+) +#{Bits.insert} +#{Bits.insert}$/
      err(@current_line, line, Objekt.err_msg(:adesc_no_tilde))
      expect :type_extra_wear
      return :redo
    else
      @adesc << line << "\n"
    end

    if has_tilde? line
      # Adescs can span multiple lines, doncha know
      validate_tilde(
      line: line,
      line_number: @current_line,
      present: false
      )
      expect :type_extra_wear
    #   expect :type_extra_wear
    #   unless trailing_tilde? line
    #     err(@current_line, line, Objekt.err_msg(:tilde_invalid_text))
    #   end
    end
  end

  def parse_type_extra_wear line
    return if invalid_blank_line? line

    if m = line.match(/^(\d+) +(#{Bits.insert}) +(#{Bits.insert})$/)
      @type = m[1].to_i
      @extra = Bits.new(m[2])
      @wear = Bits.new(m[3])
      err(@current_line, line, Objekt.err_msg(:bad_bit) % "Extra flag") if @extra.error?
      err(@current_line, line, Objekt.err_msg(:bad_bit) % "Wear flag") if @wear.error?
    else
      err(@current_line, line, Objekt.err_msg(:type_extra_wear_matches))
    end
    expect :values
  end

  def parse_values line
    return if invalid_blank_line? line

    values = line.split
    if values.length == 4
      values.each_with_index do |value, i|
        if value =~ /\A-?\d+\z/
          @values[i] = value.to_i
        elsif value =~ Bits.pattern
          @values[i] = Bits.new(value)
        else
          err(@current_line, line, Objekt.err_msg(:bad_value) % i)
        end
      end
    else
      err(@current_line, line, Objekt.err_msg(:wrong_number_of_values))
    end

    expect :weight_worth
  end

  def parse_weight_worth line
    return if invalid_blank_line? line

    @weight, @worth, zero = line.split(" ", 3)
    # err(@current_line, line, "Too many items in weight/worth line") if items.length > 3
    unless [@weight, @worth, zero].any? { |el| el.nil? } || zero !~ /\A\d+\z/
      err(@current_line, line, Objekt.err_msg(:bad_field) % "weight") unless @weight =~ /^\d+$/
      err(@current_line, line, Objekt.err_msg(:bad_field) % "worth") unless @worth =~ /^\d+$/
    else
      err(@current_line, line, Objekt.err_msg(:weight_worth_matches))
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
        err(@current_line, line, Objekt.err_msg(:invalid_text_after) % "quality") unless line =~ /^Q +\d+$/
      elsif line =~ /^Q +-\d+/
        err(@current_line, line, Objekt.err_msg(:negative) % "Quality")
      else
        err(@current_line, line, Objekt.err_msg(:bad_field) % "quality")
      end
    when "E"
      err(@current_line, line, Objekt.err_msg(:invalid_text_after) % "E") if line.length > 1
      expect :edesc_keyword
    else
      err(@current_line, line, Objekt.err_msg(:invalid_extra_field))
    end

  end

  def parse_edesc_keyword line
    if line.empty?
      err(@current_line, nil, Objekt.err_msg(:edesc_keyword_spans))
      return
    end

    validate_tilde(
      line: line,
      line_number: @current_line,
      might_span_lines: true
    )
    # unless has_tilde? line
    #   err(@current_line, line, Objekt.err_msg(:tilde_absent_or_spans) % "Edesc keywords")
    # else
    #   if !trailing_tilde? line
    #     err(@current_line, line, Objekt.err_msg(:tilde_invalid_text))
    #   end
    # end

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
      validate_tilde(
        line: line,
        line_number: @current_line,
        should_be_alone: true,
        present: false
      )
      # unless trailing_tilde? line
      #   err(@current_line, line, Objekt.err_msg(:tilde_invalid_text))
      # end
      # unless isolated_tilde? line
      #   ugly(@current_line, line, Objekt.err_msg(:tilde_not_alone) % "Edesc body")
      # end
    end

    @edesc[@recent_keywords] << line[/[^~]*/] << "\n"

  end

end
