require_relative '../helpers/parsable'
require_relative '../helpers/tilde'

class Section
  include Parsable
  include TheTroubleWithTildes

  attr_reader :line_number, :id, :contents, :children

  def self.delimiter(*options)
    if @section_delimiter
      # delim = @section_delimiter.dup
      # delim.prepend("\\A") if options.include? :start
      # options.include?(:string) ? delim : /#{delim}/
      options.include?(:start) ? /\A#{@section_delimiter}/ : @section_delimiter
    end
  end

  def initialize(contents, line_number=1)
    @line_number = line_number
    @current_line = line_number
    @contents = contents.rstrip
    @errors = []
  end

  def has_children?
    true
  end

  def parse
    super # Parsable
  end

  def split_children(valid_child=nil)
    return if self.children.nil?

    @delimiter = slice_delimiter!
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

  def slice_first_line!
    @contents.slice!(/\A.*(?:\n|\Z)/)
  end

  def slice_leading_whitespace!
    blank_lines = @contents.slice!(/\A\s*/m)
    @current_line += blank_lines.count("\n")
  end

  def slice_delimiter!
    @contents.slice!(/^#{self.class.delimiter}.*\z/m)
  end

  # returns an array of offending line and line number
  def invalid_text_after_delimiter(line_number, text)
    unless text =~ /#{self.class.delimiter(:string)}\s*?$/
      offending_text = text[/\A.*$/]
    else
      offending_text = text.rstrip
      # This slices off the delimiter line, leaving the \n at the end, which is good
      offending_text.slice!(/#{self.class.delimiter(:string)}.*$/)
      # This finds up to the first line with non-whitespace on it
      offending_text = offending_text[/\A.*?\S[^\n]*$/m]
      line_number += offending_text.count("\n")
      offending_text.lstrip!
    end
    return [line_number, offending_text]
  end

end
