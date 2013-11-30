require "./spec/spec_helper"
require "./lib/sections/helps"

help = File.read("./spec/test-helps.are")

describe Helps do

  let(:helps) { Helps.new(help.dup) }

  it_should_behave_like Section do
    let(:section) { helps }
  end

  it "detects invalid text after the delimiter" do
    helps.contents << "\n\nHey, good times man."

    expect_one_error(helps, helps.delimiter_errors(:continues_after_delimiter))
  end

  it "detects a missing delimiter" do
    helps.contents.slice!(/0\$~.*\z/m)

    expect_one_error(helps, helps.delimiter_errors(:no_delimiter))
  end

end

describe HelpFile do

  let (:help_file) do
    help_section = Helps.new(help.dup)
    help_section.split_children
    help_section.children.first
  end

  it "detects missing tildes on the keyword line" do
    i = help_file.contents.index("~")
    help_file.contents[i] = " "

    expect_one_error(help_file, TheTroubleWithTildes.err_msg(:absent))
  end

  it "detects invalid text after a tilde on the keyword line" do
    i = help_file.contents.index("~")
    help_file.contents.insert(i+1, " RSPEC BAAAAD")

    expect_one_error(help_file, TheTroubleWithTildes.err_msg(:extra_text))
  end

  it "detects missing tildes in the body" do
    i = help_file.contents.rindex("~")
    help_file.contents[i] = "!"

    expect_one_error(help_file, TheTroubleWithTildes.err_msg(:absent))
  end

  it "detects invalid text after a tilde in the body" do
    i = help_file.contents.rindex("~")
    help_file.contents.insert(i+1, " RSPEC BAAAAD")

    expect_one_error(help_file, TheTroubleWithTildes.err_msg(:extra_text))
  end

  it "detects a tilde on the same line as the body" do
    i = help_file.contents.rindex(/\n(?=~)/)
    help_file.contents.slice!(i)

    expect_one_error(help_file, TheTroubleWithTildes.err_msg(:not_alone))
  end

  it "detects invalid level" do
    i,j = help_file.contents.match(/\A\d+/).offset(0)
    help_file.contents[i...j] = "OHITHERE"

    expect_one_error(help_file, HelpFile.err_msg(:no_level))
  end

  it "parses level of file" do
    help_file.parse
    expect(help_file.level).to_not be_nil
  end

  it "parses keywords of file" do
    help_file.parse
    expect(help_file.keywords).to_not be_empty
  end

  it "parses body of file" do
    help_file.parse
    expect(help_file.body).to_not be_empty
  end

end
