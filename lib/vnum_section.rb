class VnumSection < Section

  def initialize(contents, line_number)
    super(contents, line_number)
    @entries = []
    slice_first_line
    split_entries
  end

  def split_entries

    @delimeter = slice_delimeter

    @current_line += 1
    section_end = false

    entries = @contents.split(/^(?=#\d\S*)/)

    entries.each do |entry|
      @entries << self.class.child_class.new(entry, @current_line)
      @current_line += entry.count("\n")
    end
  end

  def parse


  end

end
