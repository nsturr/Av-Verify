require_relative "bits"

module HasApplyFlag

  # Accepts the Apply flag line ("A apply value")
  # Returns an array of [apply, value] if valid, nil otherwise
  # Also throws errors to console.
  def parse_apply_flag(apply_line, line_num)
    apply_string, value_string, error = apply_line.split[1..-1]

    if apply_string # This should only be false if there's only "A" on the apply line
      if apply_string =~ /\A\d+\z/
        apply = apply_string.to_i
      else
        err(line_num, apply_line, "Invalid (negative or non-numeric) apply type")
      end
      if value_string =~ /\A(?:-|\+)?\d+\z/
        value = value_string.to_i
      elsif value_string =~ /^\d+(?:\|\d+)+$/
        warn(line_num, apply_line, "Bitfields are only used for Apply 50: Immunity") unless apply == 50
        value = Bits.new(value_string)
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
