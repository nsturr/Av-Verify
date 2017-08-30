require_relative 'section'
require_relative '../helpers/tilde'
require_relative '../helpers/has_quoted_keywords'

# Helps section and HelpEntry classes contained within this file

# Helps section follows this pattern:
#
# #HELPS
# \d+ keyword 'multiple keywords'~
# Text for 0 or more lines
# ~
# 0$~
#
# The delimiter 0$~ sometimes has a space between the 0 and the $
# The tilde closing off a help file text can be on the same line as the
# text, but will throw a warning (it's ugly). There can be many blocks
# of help files between #HELPS and 0$~ as long as they have both a
# header with a level and a body.

class Helps < Section

  @ERROR_MESSAGES = {
    invalid_ascii: "Unprintable ascii character(s) found in %s section for help"
  }

  def self.delimiter(option=nil)
    case option
    when :regex
      /^0 ?\$~/
    when :before
      /^(?=0 ?\$~)/
    else
      "0$~"
    end
  end

  def child_class
    HelpFile
  end

  def child_parser
    HelpFileParser
  end

  def initialize(options)
    super(options)
    @children = []
  end

  def to_s
    "#HELPS: #{self.children.size} entries, line #{self.line_number}"
  end

  def split_children

    # TODO: I really gotta change this method to be less messy
    # The gist is that unlike other sections, help files are separated only by tildes,
    # but are also sparated internally by tildes too, so I have to go line by line

    # grabs the delimiter and whatever (erroneous) content is after it
    slice_leading_whitespace!
    slice_delimiter!

    expect_header = true
    help_body = ""
    line_number = @current_line

    # It's easier to increment line number at the start of the each
    # loop, so decrement it here first to compensate.
    @current_line -= 1

    @contents.each_line do |line|
      @current_line += 1

      next if line.strip.empty? && expect_header
      help_body << line

      if expect_header
        line_number = @current_line
        expect_header = false
      elsif line.include? "~"
        expect_header = true
        self.children << HelpFile.new(
          contents: help_body, line_number: line_number
        )
        help_body = ""
      end

    end
    # One more Help file just in case it lacked a tilde and wasn't pushed on before
    self.children << HelpFile.new(
      contents: help_body, line_number: line_number
    ) unless help_body.empty?

  end

  def parse
    @parsed = true

    split_children

    self.children.each do |help_file|
      help_file.parse
      self.errors += help_file.errors
    end

    verify_delimiter
    self.children
  end

end

class HelpFileParser
end

class HelpFile
  include Parsable
  include TheTroubleWithTildes
  include HasQuotedKeywords

  @ERROR_MESSAGES = {
    no_level: "Help file doesn't start with a level",
  }

  attr_reader :level, :keywords, :body, :line_number, :contents

  def initialize(options)
    @line_number = options[:line_number] || 1
    @current_line = @line_number
    @contents = options[:contents].dup.rstrip
    @errors = []
  end

  def to_s
    "<Help: level #{self.level}, #{self.keywords.join(" ")}, line #{self.line_number}>"
  end

  def parse
    @parsed = true

    @body = @contents.dup
    first_line = @body.slice!(/\A.*(?:\n|\Z)/).strip

    # N.B. Help file level can be negative
    first_line.match(/\A(-?\d+)\s+/) do |m|
      @level = m[1].to_i

      keywords = m.post_match
      validate_tilde(line: first_line, line_number: @current_line)
      nab_tilde(keywords)

      # see HasQuotedKeywords module for details
      @keywords = parse_quoted_keywords(keywords, first_line)

    end # if first line starts with a number
    if self.level.nil?
      err(@current_line, first_line, HelpFile.err_msg(:no_level))
    end

    # First line done with. Onto the body.
    @current_line += @body.count("\n") + 1
    # end_line = @body[/^.*~.*$/]
    end_line = @body[/^[^\n]*\z/] # TODO : Ensure this captures what I expect

    validate_tilde(
      line: end_line,
      line_number: @current_line,
      should_be_alone: true
    )

    validate_ascii(@body, "body")
    self
  end

  # Validates that everything in the string is printable ascii characters
  def validate_ascii(body, section)
    if !body.force_encoding("UTF-8").ascii_only?
      err(line_number, body, Helps.err_msg(:invalid_ascii, section))
    end
  end

end
