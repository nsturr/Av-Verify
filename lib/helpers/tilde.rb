module TheTroubleWithTildes

  # Let's add some error messages for Tildes
  class << self
    ERROR_MESSAGES = {
      missing: "Line lacks terminating ~",
      invalid_text: "Invalid text after terminating ~",
      extra: "Misplaced tilde on line",
      not_alone: "Tilde should be on its own line"
    }

    def err_msgs(sym)
      ERROR_MESSAGES[sym]
    end
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

  def tilde(sym, description="Line")
    case sym
    when :absent
      "#{description} has no terminating ~"
    when :absent_or_spans
      "#{description} has no terminating ~ or spans multiple lines"
    when :extra_text
      "#{description} has invalid text after terminating ~"
    when :not_alone
      "Terminating ~ should be on its own line"
    end
  end

  # TODO: incorporate this, as it'll be cleaner than using all the separate ones
  def validate_tilde(line, line_number, options={})
    options = {name: "Line"}.merge(options)
    if options[:absent]
      err(line_number, line, "#{options[:name]} has no terminating ~")
      options[:absent].call if options[:absent].is_a? Proc
    end

    if options[:absent_or_spans]
      err(line_number, line, "#{options[:name]} has no terminating ~ or spans multiple lines")
      options[:absent_or_spans].call if options[:absent_or_spans].is_a? Proc
    end

    if options[:extra_text]
      err(line_number, line, "#{opeions[:name]} has invalid text after terminating ~")
      options[:extra_text].call if options[:extra_text].is_a? Proc
    end

    if options[:not_alone]
      ugly(line_number, line, "#{options[:name]}'s terminating ~ should be on its own line")
      options[:not_alone].call if options[:not_alone].is_a? Proc
    end
  end

end
