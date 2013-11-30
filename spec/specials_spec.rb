require './spec/spec_helper'
require './lib/sections/specials'

data = File.read("./spec/test-specials.are")

describe Specials do

  let(:specials) { Specials.new(data) }

  it_should_behave_like Section do
    let(:section) { specials }
  end

  it "ignores whitespace and comments" do
    specials.parse

    expect(specials.errors).to be_empty
  end

  it "detects a missing delimiter" do
    specials.contents.chop!

    expect_one_error(specials, Specials.err_msg(:no_delimiter))
  end

  it "detects invalid text after its delimiter" do
    specials.contents << "\nOh hi there!"

    expect_one_error(specials, Specials.err_msg(:continues_after_delimiter))
  end

  it "detects multiple specs for a single mob" do
    # We're grabbing a complete spec_fun line, then inserting a copy
    # as the first line
    i, j = specials.contents.match(/^M.*\n/).offset(0)
    specials.contents.insert(i, specials.contents[i...j])

    expect_one_error(specials, Specials.err_msg(:duplicate_spec, "spec_cast_wizard"))
  end

end

describe Special do

  let(:spec_fun) { Special.new("M 11467 SPEC_PRIEST_LITE") }
  let(:i_vnum) { spec_fun.line.index(/\b11467\b/) }
  let(:i_spec) { spec_fun.line.index(/\bSPEC\w+\b/) }

  it "detects an invalid special line" do
    spec_fun.line[0] = "Z"

    expect_one_error(spec_fun, Special.err_msg(:invalid_line))
  end

  it "detects an incomplete line" do
    spec_fun.line.replace("M 1")

    expect_one_error(spec_fun, Special.err_msg(:not_enough_tokens))
  end

  it "detects an invalid mob vnum" do
    spec_fun.line[i_vnum] = "howdy"

    expect_one_error(spec_fun, Special.err_msg(:invalid_vnum))
  end

  it "detects a negative mob vnum" do
    spec_fun.line.insert(i_vnum, "-")

    expect_one_error(spec_fun, Special.err_msg(:negative_vnum))
  end

  it "detects an invalid spec_fun" do
    spec_fun.line[i_spec] = "12.345"

    expect_one_error(spec_fun, Special.err_msg(:invalid_spec))
  end

  it "detects an unknown spec_fun" do
    spec_fun.line[i_spec] = "SPEC_BARRISTA"

    expect_one_error(spec_fun, Special.err_msg(:unknown_spec))
  end

end
