module TheTroubleWithTildes

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

end
