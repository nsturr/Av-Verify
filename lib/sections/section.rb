require_relative '../helpers/parsable'
require_relative '../helpers/tilde'

class Section
  include Parsable
  include TheTroubleWithTildes

  @ERROR_MESSAGES = {
    no_delimiter: "\#%s section has no terminating %s",
    continues_after_delimiter: "\#%s section continues after terminating %s"
  }

  attr_reader :line_number, :contents, :children

  # Only AreaHeader should be overriding this to return true
  def self.is_just_one_line?
    false
  end

  def self.delimiter(option=nil)
    if @section_delimiter
      case option
      when :regex
        /^#{@section_delimiter}\b/
      when :before
        /^(?=#{@section_delimiter}\b)/
      else
        @section_delimiter
      end
    end
  end

  # def initialize(contents, line_number=1)
  def initialize(options)
    @line_number = options[:line_number] || 1
    @current_line = @line_number
    @contents = options[:contents].rstrip
    @errors = []

    # Do a quick verification of the section header on the first line, if any
    m = contents.match(/\A#([a-z]+)\b/i)
    if m
      # Throw an error if the section name in the first line doesn't
      # match self.id. It would probably be caused by a user instantiating
      # a section with the wrong content, because varea wouldn't.
      unless self.id == m[1].downcase
        raise ArgumentError.new("Section name #{m[1]} doesn't match class #{self.id.inspect} being instantiated")
      end
      unless self.class.is_just_one_line?
        slice_first_line!
        @current_line += 1
      end
    end
    # If there's no first line matching /\A#[a-z]+/i, don't do anything.
    # It can be passed headerless sections, no problem.
  end

  def id
    self.class.name.downcase
  end

  # Sections call this method directly so they don't have to all deal with
  # passing their the interpolated arguments to the error messages. This is the
  # single point of access for these error messages, even in the specs
  def delimiter_errors(type)
    case type
    when :no_delimiter
      Section.err_msg(:no_delimiter, self.id.upcase, self.class.delimiter)
    when :continues_after_delimiter
      Section.err_msg(:continues_after_delimiter, self.id.upcase, self.class.delimiter)
    end
  end

  def split_children(valid_child=nil)
    return if self.children.nil?

    slice_delimiter!
    slice_leading_whitespace!

    entries = self.contents.rstrip.split(self.child_regex)
    entries.each do |entry|
      # valid_entry both returns true/false to determine if the entry can be
      # added to children, and also raises errors/warnings if applicable
      if valid_child.nil? || valid_child.call(entry)
        self.children << self.child_class.new(entry, @current_line)
      end
      @current_line += entry.count("\n")
    end
  end

  private

  def slice_first_line!
    @contents.slice!(/\A.*(?:\n|\Z)/)
  end

  def slice_leading_whitespace!
    blank_lines = @contents.slice!(/\A\s*/m)
    @current_line += blank_lines.count("\n")
  end

  def slice_delimiter!
    @delimiter = @contents.slice!(/#{self.class.delimiter(:regex)}.*\z/m)
  end

  def verify_delimiter
    @current_line += 1
    if @delimiter.nil?
      err(@current_line, nil, delimiter_errors(:no_delimiter))
    else
      unless @delimiter.rstrip =~ /#{self.class.delimiter(:regex)}\z/
        line_num, bad_line = invalid_text_after_delimiter(@current_line, @delimiter)
        err(line_num, bad_line, delimiter_errors(:continues_after_delimiter))
      end
    end
  end

  # returns an array of offending line and line number
  def invalid_text_after_delimiter(line_number, text)
    unless text =~ /#{self.class.delimiter(:regex)}\s*?$/
      offending_text = text[/\A.*$/]
    else
      offending_text = text.rstrip
      # This slices off the delimiter line, leaving the \n at the end, which is good
      offending_text.slice!(/#{self.class.delimiter(:regex)}.*$/)
      # This finds up to the first line with non-whitespace on it
      offending_text = offending_text[/\A.*?\S[^\n]*$/m]
      line_number += offending_text.count("\n")
      offending_text.lstrip!
    end
    return [line_number, offending_text]
  end

end
