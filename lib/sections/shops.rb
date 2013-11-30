require_relative "section"
require_relative "line_by_line_object"

# This section will be the death of me.
# seriously, die in a fire, #shops

class Shops < Section

  @section_delimiter = /^0\b[^\d\n]*$/

  @ERROR_MESSAGES = {
    continues_after_delimiter: "#SHOPS section continues after terminating 0$~",
    no_delimiter: "Shops section ends without terminating 0",
  }

  attr_reader :shops

  def child_class
    Shop
  end

  def initialize(contents, line_number=1)
    super(contents, line_number)
    @id = "shops"
    @children = []

    slice_first_line!
    @current_line += 1
  end

  def child_regex
    /^(?=\d+\b[^\d]*$)/
  end

  def length
    @children.length
  end

  def size
    length
  end

  def each(&prc)
    @children.each(&prc)
  end

  def [](index)
    @children[index]
  end

  def to_s
    "<#SHOPS: #{self.shops.size} entries, line #{self.line_number}>"
  end

  def parse
    @parsed = true

    split_children

    @children.each do |shop|
      shop.parse
      @errors += shop.errors
    end

    if @delimiter
      unless @delimiter.rstrip =~ /#{Shops.delimiter(:start)}\z/
        line_num, bad_line = invalid_text_after_delimiter(@current_line, @delimiter)
        err(line_num, bad_line, Shops.err_msg(:continues_after_delimiter))
      end
    else
      err(@current_line, nil, Shops.err_msg(:no_delimiter))
    end
    self.shops
  end

end

class Shop < LineByLineObject

  @ERROR_MESSAGES = {
    missing_line: "Shop terminates without %s line",
    bad_vnum: "Invalid shopkeeper VNUM",
    bad_object_type: "Invalid object type",
    not_enough_tokens: "Not enough tokens in %s line",
    negative_profit_margin: "Profit margin can't be negative",
    invalid_profit_margin: "Invalid profit margin",
    hours_out_of_bounds: "Hours out of bounds 0 to 23",
    bad_hour: "Invalid hour"
  }

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
      err(@current_line, nil, Shop.err_msg(:missing_line, expectation.to_s))
    end
    self
  end

  def parse_vnum line
    return if line.empty?
    if line =~ /^\d+(?:\s+.*)?$/
      @vnum = line.to_i
    else
      err(@current_line, line, Shop.err_msg(:bad_vnum))
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
          err(@current_line, line, Shop.err_msg(:bad_object_type))
        end
      end
    else
      err(@current_line, line, Shop.err_msg(:not_enough_tokens, "shop type"))
    end

    expect :profit
  end

  def parse_profit line
    return if invalid_blank_line? line

    profit_buy, profit_sell = line.split(" ", 3)[0..1] # drop off the comment
    unless profit_sell.nil?
      if profit_buy =~ /^-?\d+$/
        @profit_buy = profit_buy.to_i
        err(@current_line, line, Shop.err_msg(:negative_profit_margin)) if @profit_buy < 0
      else
        err(@current_line, line, Shop.err_msg(:invalid_profit_margin))
      end
      if profit_sell =~ /^-?\d+$/
        @profit_sell = profit_sell.to_i
        err(@current_line, line, Shop.err_msg(:negative_profit_margin)) if @profit_sell < 0
      else
        err(@current_line, line, Shop.err_msg(:invalid_profit_margin))
      end
    else
      err(@current_line, line, Shop.err_msg(:not_enough_tokens, "profit"))
    end

    expect :hours
  end

  def parse_hours line
    return if invalid_blank_line? line

    hour_open, hour_close = line.split(" ", 3)[0..1] # I hate you, shops
    unless hour_close.nil?
      if hour_open =~ /^\d+$/
        @hour_open = hour_open.to_i
        err(@current_line, line, Shop.err_msg(:hours_out_of_bounds)) unless @hour_open.between?(0,23)
      else
        err(@current_line, line, Shop.err_msg(:bad_hour))
      end
      if hour_close =~ /^\d+$/
        @hour_close = hour_close.to_i
        err(@current_line, line, Shop.err_msg(:hours_out_of_bounds)) unless @hour_close.between?(0,23)
      else
        err(@current_line, line, Shop.err_msg(:bad_hour))
      end
    else
      err(@current_line, line, Shop.err_msg(:not_enough_tokens, "hours"))
    end

    expect :vnum
  end

end
