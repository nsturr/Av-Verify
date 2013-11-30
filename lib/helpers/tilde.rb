module TheTroubleWithTildes

  # Let's add some error messages for Tildes
  ERROR_MESSAGES = {
    absent: "%s has no terminating ~",
    absent_between: "%s has no terminating ~ between lines %d and %d",
    absent_or_spans: "%s has no terminating ~ or spans multiple lines",
    extra_text: "Invalid text after terminating ~",
    extra: "Misplaced tilde on line",
    not_alone: "Terminating ~ should be on its own line"
  }

  def self.err_msg(sym, desc="Line", line_start=1, line_end=2)
    ERROR_MESSAGES[sym] % [desc, line_start, line_end]
  end

  def has_tilde? line
    line.include? "~"
  end

  def trailing_tilde? line
    line.rstrip.end_with? "~"
  end

  def isolated_tilde? line
    line.lstrip.start_with? "~"
  end

  def nab_tilde line
    line.slice!(/\s*~.*\z/)
    line
  end

  # Performs all the validations in one function call
  # Options specify which validations to perform
  # Don't use this method for fields that can span multiple lines
  # like kspawns or descriptions.
  def validate_tilde(options={})
    options = {
      name: "Line",
      present: true,
      line_number: 0
    }.merge(options)

    raise ArgumentError.new("No line passed as argument") if options[:line].nil?
    line = options[:line]
    line_number = options[:line_number]
    name = options[:name]

    if options[:present] && !has_tilde?(line)
      message = options[:might_span_lines] ? :absent_or_spans : :absent
      err(line_number, line, TheTroubleWithTildes.err_msg(message) % name)
    elsif line.count("~") > 1
      err(line_number, line, TheTroubleWithTildes.err_msg(:extra) % name)
    elsif !trailing_tilde?(line)
      err(line_number, line, TheTroubleWithTildes.err_msg(:extra_text) % name)
    elsif options[:should_be_alone] && !isolated_tilde?(line)
      ugly(line_number, line, TheTroubleWithTildes.err_msg(:not_alone) % name)
    end
  end

end
