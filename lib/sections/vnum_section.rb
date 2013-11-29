require_relative "section"

class VnumSection < Section

  @ERROR_MESSAGES = {
    invalid_vnum: "Invalid %s VNUM",
    invalid_after_vnum: "Invalid text on same line as VNUM",
    duplicate: "Duplicate %s #%i, first appears on line %i",
    no_delimiter: "#%s section lacks terminating #0",
    continues_after_delimiter: "#%s section continues after terminating #0",
    empty: "%s section is empty!"
  }

  def initialize(contents, line_number=1)
    super(contents, line_number)
    @children = []
    slice_first_line!
  end

  def has_children?
    true
  end

  def child_regex
    /^(?=#\d\S*)/
  end

  def [](vnum)
    self.children.find { |child| child.vnum == vnum }
  end

  def include?(vnum)
    self.children.any? { |child| child.vnum == vnum }
  end

  def length
    self.children.length
  end

  def size
    length
  end

  def each(&prc)
    self.children.each(&prc)
  end

  def split_children(prc=nil)
    super(prc)
  end

  # def split_entries
  # def split_children

  #   @delimiter = slice_delimiter!
  #   @current_line += 1
  #   slice_leading_whitespace!

  #   entries = @contents.rstrip.split(self.child_regex)

  #   entries.each do |entry|
  #     entry_line_number = @current_line
  #     @current_line += entry.count("\n")

  #     unless entry =~ /\A#\d+\b/ # bad VNUM
  #       err(entry_line_number, entry[/\A.*$/], VnumSection.err_msg(:invalid_vnum) % self.id.upcase)
  #       next
  #     end
  #     err(entry_line_number, entry[/\A.*$/], VnumSection.err_msg(:invalid_after_vnum)) unless entry =~ /\A#\d+\s*$/
  #     @raw_entries << self.class.child_class.new(entry, entry_line_number)
  #   end
  # end

  def parse
    super # set @parsed to true

    validate_vnum = Proc.new do |child|
      unless child =~ /\A#\d+\b/
        err(@current_line, child[/\A.*$/], VnumSection.err_msg(:invalid_vnum) % self.id.upcase)
      end
      unless child =~ /\A#\d+\s*$/
        err(@current_line, child[/\A.*$/], VnumSection.err_msg(:invalid_after_vnum))
      end
    end

    split_children(validate_vnum)

    # if @raw_entries.empty?
    if self.children.empty?
      err(self.line_number, nil, VnumSection.err_msg(:empty) % self.class.name)
      @parsed = true
    end

    self.children.each do |entry|
      entry.parse
      # unless @entries.key? entry.vnum
      #   @entries[entry.vnum] = entry
      # else
      #   err(
      #     entry.line_number, nil, VnumSection.err_msg(:duplicate) %
      #     [entry.class.name.downcase, entry.vnum, @entries[entry.vnum].line_number]
      #   )
      # end
      self.errors += entry.errors
    end

    if @delimiter.nil?
      err(@current_line, nil, VnumSection.err_msg(:no_delimiter) % self.id.upcase)
    else
      unless @delimiter.rstrip =~ /#{self.class.delimiter(:start)}\z/
        line_num, bad_line = invalid_text_after_delimiter(@current_line, @delimiter)
        err(line_num, bad_line, VnumSection.err_msg(:continues_after_delimiter) % self.id.updase)
      end
    end
    self.children
  end

end
