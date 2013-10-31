require_relative 'section.rb'

class Helps < Section

  attr_reader :help_files

  def initialize(contents, line_number)
    super(contents, line_number)
    @name = "HELPS"

    @help_files = []

    # This just takes off the section name header
    slice_first_line
    @current_line += 1

    # grabs the delimeter and whatever (erroneous) content is after it
    @delimeter = slice_delimeter("0 ?\\$~")

    split_help_files
  end

  def split_help_files

    until @contents.empty?
      # Match and extract the block of text that starts from the beginning of
      # the contents and runs until it encounters either the second tilde or
      # the end of the section.
      help_body = @contents.slice!(/\A[^~]*(?:~|\z)[^~]*(?:~|\z).*?(?:\n|\z)/)

      @help_files << HelpFile.new(help_body, @current_line)
      @current_line += help_body.count("\n")
    end

  end

  def parse

    @help_files.each do |help_file|
      help_file.parse
      @errors += help_file.errors
    end

    if @delimeter.nil?

    else
      unless @delimeter.rstrip =~ /\A0 ?\$~\z/
        # TODO: ensure that this always locates the invalid text
        # (It doesn't if the invalid text is on another line after the delim)
        line = @delimeter[/\A.*$/]
        err(@current_line, line, "Invalid text after terminating 0$~")
      end
    end

  end

end

class HelpFile
  include Parsable

  attr_reader :level, :keywords, :body, :line_number

  def initialize(contents, line_number=1)
    @line_number = line_number
    @current_line = line_number
    @contents = contents.rstrip
    @errors = []
  end

  def parse

    first_line = @contents.slice!(/\A.*(?:\n|\Z)/)
    p first_line, @contents

    first_line.match(/\A(\d+)\s/) do |m|
      @level = m[1].to_i
    end

    err(@current_line, first_line, "Missing or invalid help file level") if self.level.nil?

    first_line.match(/(\d+) ('(?:\w+ ?)+'|[^'\W]+ ?)*/)

  end

end
