require_relative "section"
require_relative "line_by_line_object"

# This section will be the death of me.
# seriously, die in a fire, #shops

class Shops < Section

  @section_delimiter = "^0\\b[^\\d\\n]*$"

  attr_reader :shops

  def initialize(contents, line_number=1)
    super(contents, line_number)
    @id = "shops"
    @shops = []

    slice_first_line!
    @current_line += 1
    split_shops
  end

  def length
    @shops.length
  end

  def size
    length
  end

  def each(&prc)
    @shops.each(&prc)
  end

  def [](index)
    @shops[index]
  end

  def to_s
    "#SHOPS: #{self.shops.size} entries, line #{self.line_number}"
  end

  def split_shops
    @delimiter = slice_delimiter!

    slice_leading_whitespace!

    # split on exactly one number in a line, maybe some invalid non-numbers after,
    # whatever. Shops sucks so much.
    @entries = @contents.split(/^(?=\d+\b[^\d]*$)/)
    @entries.each do |entry|
      @shops << Shop.new(entry, @current_line)
      @current_line += entry.count("\n")
    end
  end

  def parse
    super # set parsed to true

    @shops.each do |shop|
      shop.parse
      @errors += shop.errors
    end

    if @delimiter
      unless @delimiter.rstrip =~ /#{Shops.delimiter(:start)}\z/
        line_num, bad_line = invalid_text_after_delimiter(@current_line, @delimiter)
        err(line_num, bad_line, "#SHOPS section continues after terminating 0$~")
      end
    else
      err(@current_line, nil, "Shops section ends without terminating 0")
    end
    self.shops
  end

end

class Shop < LineByLineObject

  ATTRIBUTES = [:vnum, :types, :profit_buy, :profit_sell, :hour_open, :hour_close]

  attr_reader :line_number, *ATTRIBUTES

  def initialize(contents, line_number=1)
    super(contents, line_number)
    @section_end = false
  end

  def to_s
    "<Shop: vnum #{self.vnum}, line #{line_number}>"
  end

  def parse
    super
    unless @expectation == :vnum
      expectation = case @expectation
        when :types then "item types"
        when :profit then "protit"
        when :hours then "business hours"
        end
      err(@current_line, nil, "Shop terminates without #{expectation} line")
    end
    self
  end

  def parse_vnum line
    return if line.empty?
    if line =~ /^\d+(?:\s+.*)?$/
      @vnum = line.to_i
    else
      err(@current_line, line, "Invalid shopkeeper VNUM")
    end

    expect :types
  end

  def parse_types line
    return if invalid_blank_line? line

    types = line.split(" ", 6)[0..5] # drop off the possible (valid *grumble*) comment
    if types.length >= 5
      @types = []
      0.upto(4).each do |i|
        if types[i] =~ /^\d+$/
          @types << types[i]
        else
          err(@current_line, line, "Invalid object type")
        end
      end
    else
      err(@current_line, line, "Not enough tokens in shop type line")
    end

    expect :profit
  end

  def parse_profit line
    return if invalid_blank_line? line

    profit_buy, profit_sell = line.split(" ", 3)[0..1] # drop off the comment
    unless profit_sell.nil?
      if profit_buy =~ /^-?\d+$/
        @profit_buy = profit_buy.to_i
        err(@current_line, line, "Profit margin can't be negative") if @profit_buy < 0
      else
        err(@current_line, line, "Invalid profit margin")
      end
      if profit_sell =~ /^-?\d+$/
        @profit_sell = profit_sell.to_i
        err(@current_line, line, "Profit margin can't be negative") if @profit_sell < 0
      else
        err(@current_line, line, "Invalid profit margin")
      end
    else
      err(@current_line, line, "Not enough tokens in profit line")
    end

    expect :hours
  end

  def parse_hours line
    return if invalid_blank_line? line

    hour_open, hour_close = line.split(" ", 3)[0..1] # I hate you, shops
    unless hour_close.nil?
      if hour_open =~ /^\d+$/
        @hour_open = hour_open.to_i
        err(@current_line, line, "Hours out of bounds 0 to 23") unless @hour_open.between?(0,23)
      else
        err(@current_line, line, "Invalid hour")
      end
      if hour_close =~ /^\d+$/
        @hour_close = hour_close.to_i
        err(@current_line, line, "hours out of bounds 0 to 23") unless @hour_close.between?(0,23)
      else
        err(@current_line, line, "Invalid hour")
      end
    else
      err(@current_line, line, "Not enough tokens in hours line")
    end

    expect :vnum
  end

end
