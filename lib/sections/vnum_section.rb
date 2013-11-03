require_relative "section"

class VnumSection < Section

  def initialize(contents, line_number)
    super(contents, line_number)
    @raw_entries = [] # Unparsed, has no VNUM yet, etc.
    @entries = {} # Parsed and validated, keyed by VNUM
    slice_first_line
    split_entries
  end

  def split_entries

    @delimiter = slice_delimiter

    @current_line += 1
    section_end = false

    entries = @contents.split(/^(?=#\d\S*)/)

    entries.each do |entry|
      unless entry =~ /\A#\d+\b/ # bad VNUM
        err(@current_line, entry[/\A.*$/], "Invalid #{self.class.name} VNUM")
        next
      end
      @raw_entries << self.class.child_class.new(entry, @current_line)
      @current_line += entry.count("\n")
    end
  end

  def parse

    @raw_entries.each do |entry|
      entry.parse
      @entries[entry.vnum] = entry
      @errors += entry.errors
    end

    if @delimiter.nil?
      err(@current_line, nil, "##{self.class.name} section lacks terminating #0")
    else
      unless @delimiter.rstrip =~ /#{self.class.delimiter(:start)}\z/
        line_num, bad_line = invalid_text_after_delimiter(@current_line, @delimiter)
        err(line_num, bad_line, "##{self.class.name} section continues after terminating #0")
      end
    end
    @entries
  end

end
