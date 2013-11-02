require "./spec/spec_helper"
require "./lib/sections/helps"

help = File.read("./spec/test-helps.are")

describe Helps do

  let(:helps) { Helps.new(help) }

  it "detects invalid text after the delimiter" do
    helps.contents << "\n\nHey, good times man."

    expect_one_error(helps, Helps.err_msg(:continues_after_delimiter))
  end

  it "detects a missing delimiter" do
    helps.contents.slice!(/0\$~.*\z/m)

    expect_one_error(helps, Helps.err_msg(:no_delimiter))
  end

end

describe HelpFile do

end
