# Has Quoted Keywords
#
# Usage:
# Requires two arguments: source and line.
# Source is the source string from which it will parse keywords
# Line is the source line in its original format, which is only used to supply
# a line to the err or warn methods.
#
# Returns an array of strings, which are either individual words or a quoted group
# of words.
#
# If it doesn't make sense for something to have any quotes in their name
# (a mob or object keywords, etc) pass true as the third argument, and a description
# of the object ("object", "mobile", "edesc") and a warning will be raised if there
# are any quotes detected. Name is optional, and is only used for the error readout.

require_relative "avconstants"

module HasQuotedKeywords

  # The argument 'source' WILL be destroyed, 'line' will not be
  def parse_quoted_keywords source, line, noquotes=false, name=""
    punct = KEYWORD_PUNCTUATION
    keyword_line = source.dup
    parsed_keywords = []
    until keyword_line.empty?
      # This regex matches either the first whole word, or the first single-quoted
      # block of words, including ones that are missing a closing quote
      parsed_keywords << keyword_line.slice!(/\A(?:'[\w#{punct} ]*(?:'|\z)|[\w#{punct}]+)\s*/i).rstrip
    end

    validate_keywords(parsed_keywords, line, noquotes, name)

    parsed_keywords
  end

  def validate_keywords(keywords, line, noquotes=false, name="these")

    # Finds keywords containing a single quote that isn't inside the word
    if keywords.any? { |keyword| keyword.count("'") == 1 && !(keyword =~ /\w'\w/) }
      err(@current_line, line, "Keywords missing closing quote")
    end

    if keywords.any? { |keyword| KEYWORD_COMMON.include? keyword.downcase }
      warn(@current_line, line, "Common word detected as a keyword. Missing quotes?")
    end

    if noquotes && keywords.any? { |k| k.start_with?("'") || k.end_with?("'")}
      warn(@current_line, line, "Are you sure you want quotes in #{name} keywords?")
    end
  end

end
