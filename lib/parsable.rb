module Parsable

  Error = Struct.new(:line, :type, :context, :description)

  def err(line, context, description)
    error = Error.new(line, :error, context, description)
    @errors << error
  end

  # Returns a new Error struct, but only for non-critical errors
  def warn(line, context, description)
    error = Error.new(line, :warning, context, description)
    @errors << error
  end

  # Nothing creates these yet, so ignore
  def nb(line, context, description)
    error = Error.new(line, :nb, context, description)
    @errors << error
  end

  # The least important errors, primarily cosmetic things
  def ugly(line, context, description)
    error = Error.new(line, :ugly, context, description)
    @errors << error
  end

  def errors
    @errors || []
  end

end
