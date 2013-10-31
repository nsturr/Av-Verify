module TheTroubleWithTildes

  def has_tilde? line
    line.include? "~" ? true : "Line lacks terminating ~"
  end

  def trailing_tilde? line
    line.rstrip.end_with? "~" ? : "Invalid text after terminating ~"
  end

  def isolated_tilde? line
    line.lstrip.start_with? "~" ? true : "Terminating ~ should be on its own line"
  end

end
