require "./helpers/bits"

module HasApplyFlag

  # Accepts the Apply flag line ("A apply value")
  # Returns an array of [apply, value] if valid, nil otherwise
  # Also throws errors to console.
  def parse_apply_flag(apply_line, line_num)
    items = apply_line.split(" ", 4)
    apply = nil
    value = nil
    unless items.length < 3 # This should only be false if there's only "A" on the apply line
      # Items[0] is just the letter M
      if m = items[1].match(/^(\d+)$/)
        apply = m[1].to_i
      else
        err(line_num, apply_line, "Invalid (negative or non-numeric) apply type")
      end
      if m = items[2].match(/^((?:-|\+)?\d+)$/)
        value = m[1].to_i
      elsif m = items[2].match(/^(\d+(?:\|\d+)+)$/)
        warn(line_num, apply_line, "Bitfields are only used for Apply 50: Immunity") unless apply == 50
        value = Bits.new(m[1])
        err(line_num, apply_line, "Bitfield is not a power of 2") if value.error?
        value = value.sum
      else
        err(line_num, apply_line, "Invalid (non-numeric, incomplete bitfield) apply value")
      end

      return [apply, value] unless apply.nil? || value.nil?
    end
    nil
  end

end
