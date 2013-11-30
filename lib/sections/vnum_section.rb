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

  # A proc to pass to Section#split_children to determine whether or not to add
  # the the child to the instance var @children. Also raises errors
  def valid_vnum?
    Proc.new do |child|
      child_vnum = child[/\A#\d+\b/]
      invalid = false

      unless child_vnum
        # invalid vnums won't be added (sorry!)
        err(@current_line, child[/\A.*$/], VnumSection.err_msg(:invalid_vnum, self.id.upcase))
        invalid == true
      end
      unless child =~ /\A#\w+\s*$/
        err(@current_line, child[/\A.*$/], VnumSection.err_msg(:invalid_after_vnum))
      end

      !invalid
    end
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

  def parse
    @parsed = true

    split_children(self.valid_vnum?)

    if self.children.empty?
      err(self.line_number, nil, VnumSection.err_msg(:empty, self.class.name))
      @parsed = true
    end

    self.children.each do |entry|
      entry.parse

      existing_entry = self[entry.vnum]
      unless existing_entry.equal?(entry)
        err(
          entry.line_number, nil,
          VnumSection.err_msg(
            :duplicate, entry.class.name.downcase, entry.vnum, existing_entry.line_number
          )
        )
      end

      self.errors += entry.errors
    end

    if @delimiter.nil?
      err(@current_line, nil, VnumSection.err_msg(:no_delimiter, self.id.upcase))
    else
      unless @delimiter.rstrip =~ /#{self.class.delimiter(:start)}\z/
        line_num, bad_line = invalid_text_after_delimiter(@current_line, @delimiter)
        err(line_num, bad_line, VnumSection.err_msg(:continues_after_delimiter, self.id.upcase))
      end
    end
    self.children
  end

end
