require_relative "section"

class VnumSection < Section

  @ERROR_MESSAGES = {
    invalid_vnum: "Invalid %s VNUM",
    duplicate: "Duplicate %s #%i, first appears on line %i",
    no_delimiter: "#%s section lacks terminating #0",
    continues_after_delimiter: "#%s section continues after terminating #0",
    empty: "%s section is empty!"
  }

  def initialize(contents, line_number)
    super(contents, line_number)
    @raw_entries = [] # Unparsed, has no VNUM yet, etc.
    @entries = {} # Parsed and validated, keyed by VNUM
    slice_first_line
    split_entries
  end

  def [](vnum)
    @entries[vnum]
  end

  def split_entries

    @delimiter = slice_delimiter
    @current_line += 1

    entries = @contents.rstrip.split(/^(?=#\d\S*)/)

    entries.each do |entry|
      entry_line_number = @current_line
      @current_line += entry.count("\n")

      # Only happens if whitespace between header and 1st vnum
      next if entry.rstrip.empty?
      unless entry =~ /\A#\d+\b/ # bad VNUM
        err(entry_line_number, entry[/\A.*$/], VnumSection.err_msg(:invalid_vnum) % self.id.upcase)
        next
      end
      @raw_entries << self.class.child_class.new(entry, entry_line_number)
    end
  end

  def parse
    super # set @parsed to true

    if @raw_entries.empty?
      err(self.line_number, nil, VnumSection.err_msg(:empty) % self.class.name.capitalize)
      @parsed = true
    end

    @raw_entries.each do |entry|
      entry.parse
      unless @entries.key? entry.vnum
        @entries[entry.vnum] = entry
      else
        err(
          entry.line_number, nil, VnumSection.err_msg(:duplicate) %
          [entry.class.name.downcase, entry.vnum, @entries[entry.vnum].line_number]
        )
      end
      @errors += entry.errors
    end

    if @delimiter.nil?
      err(@current_line, nil, VnumSection.err_msg(:no_delimiter) % self.id.upcase)
    else
      unless @delimiter.rstrip =~ /#{self.class.delimiter(:start)}\z/
        line_num, bad_line = invalid_text_after_delimiter(@current_line, @delimiter)
        err(line_num, bad_line, VnumSection.err_msg(:continues_after_delimiter) % self.id.updase)
      end
    end
    @entries
  end

end
