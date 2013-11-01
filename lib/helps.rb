require_relative 'section.rb'
require_relative 'modules/tilde.rb'

class Helps < Section

  attr_reader :help_files

  def initialize(contents, line_number)
    super(contents, line_number)
    @name = "HELPS"

    @help_files = []

    slice_first_line # Takes off section name header

    split_help_files
  end

  def split_help_files

    # grabs the delimeter and whatever (erroneous) content is after it
    @delimeter = slice_delimeter("0 ?\\$~")

    expect_header = true
    help_body = ""
    line_number = @current_line

    @contents.each_line do |line|
      @current_line += 1
      help_body << line

      if expect_header
        line_number = @current_line
        expect_header = false
      elsif line.include? "~"
        expect_header = true
        self.help_files << HelpFile.new(help_body, line_number)
        help_body = ""
      end
    end
    # One more Help file just in case it lacked a tilde and wasn't pushed on before
    self.help_files << HelpFile.new(help_body, line_number) unless help_body.empty?

  end

  def parse

    @help_files.each do |help_file|
      help_file.parse
      @errors += help_file.errors
    end

    @current_line += 1
    if @delimeter.nil?
      err(@current_line, nil, "#HELPS section lacks terminating 0$~")
    else
      unless @delimeter.rstrip =~ /\A0 ?\$~\z/
        line_num, bad_line = invalid_text_after_delimeter(@current_line, @delimeter, "\\A0 ?\\$~")
        err(line_num, bad_line, "#HELPS section continues after terminating 0$~")
      end
    end

  end

end

class HelpFile
  include Parsable
  include TheTroubleWithTildes

  attr_reader :level, :keywords, :body, :line_number

  def initialize(contents, line_number=1)
    @line_number = line_number
    @current_line = line_number
    @contents = contents.rstrip
    @errors = []
  end

  def parse

    first_line = @contents.slice!(/\A.*(?:\n|\Z)/).strip

    first_line.match(/\A(\d+)\s+/) do |m|
      @level = m[1].to_i

      keywords = m.post_match
      unless has_tilde?(keywords)
        err(@current_line, first_line, tilde(:absent))
      else
        err(@current_line, first_line, tilde(:extra_text)) unless trailing_tilde?(keywords)
      end
      nab_tilde(keywords)

      # Start grabbing keywords
      parsed_keywords = []
      until keywords.empty?
        # This regex matches either the first whole word, or the first single-quoted
        # block of words, including ones that are missing a closing quote
        parsed_keywords << keywords.slice!(/\A(?:\w+|'.*?(?:'|\z))\s*/).rstrip
      end

      @keywords = parsed_keywords
      validate_keywords(first_line)

    end # if first line starts with a number
    if self.level.nil?
      err(@current_line, first_line, "Malformed help header; should start with a number")
    end

    # First line done with. Onto the body.
    @current_line += @contents.count("\n") + 1
    end_line = @contents[/^.*~.*$/]
    if !has_tilde?(@contents)
      err(@current_line, nil, tilde(:absent, "Help file body"))
    elsif !trailing_tilde?(end_line)
      err(@current_line, end_line, tilde(:extra_text, "Help file body"))
    elsif !isolated_tilde?(end_line)
      ugly(@current_line, end_line, tilde(:not_alone))
    end

  end

  def validate_keywords(line)
    # words that should never be keywords---they're probably part of a quoted block
    # that was missing its quotes
    watch_words = %w( and he her hers his if in it of on or she the with )

    if @keywords.any? { |keyword| keyword.count("'") == 1 }
      err(@current_line, line, "Keywords missing closing quote")
    end

    if @keywords.any? { |keyword| watch_words.include? keyword.downcase }
      warn(@current_line, line, "Common word detected as a keyword. Missing quotes?")
    end
  end

end
