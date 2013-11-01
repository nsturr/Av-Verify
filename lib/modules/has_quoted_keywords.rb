module HasQuotedKeywords

  # The argument 'source' WILL be destroyed, 'line' will not be
  def parse_quoted_keywords source, line
    keyword_line = source.dup
    parsed_keywords = []
    until keyword_line.empty?
      # This regex matches either the first whole word, or the first single-quoted
      # block of words, including ones that are missing a closing quote
      parsed_keywords << keyword_line.slice!(/\A(?:[^\s']+|'.*?(?:'|\z))\s*/).rstrip
    end

    validate_keywords(parsed_keywords, line)

    parsed_keywords
  end

  def validate_keywords(keywords, line)
    # words that should never be keywords---they're probably part of a quoted block
    # that was missing its quotes
    watch_words = %w( and he her hers his if in it of on or she the with )

    if keywords.any? { |keyword| keyword.count("'") == 1 }
      err(@current_line, line, "Keywords missing closing quote")
    end

    if keywords.any? { |keyword| watch_words.include? keyword.downcase }
      warn(@current_line, line, "Common word detected as a keyword. Missing quotes?")
    end
  end

end
