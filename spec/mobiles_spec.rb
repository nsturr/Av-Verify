require './spec/spec_helper'
require './lib/sections/mobiles'

data = File.read("./spec/test-mobiles.are")

describe Mobiles do

  let(:mobiles) { Mobiles.new(data.dup) }

  it_should_behave_like Section do
    let(:section) { mobiles }
  end

  it_should_behave_like VnumSection do
    let(:section) { mobiles }
  end

end

describe Mobile do

  # Test LineByLineObject separately

  # it_should_behave_like LineByLineObject do
  #   let(:item) { mobile }
  # end

  context "parsing text fields" do
    let(:mobile) do
      mobiles_section = Mobiles.new(data.dup)
      mobiles_section.split_children
      mobiles_section.children.first
    end

    # A handy array of indices to located the four tilde-
    # delimited text fields
    let(:tildes) do
      t = []
      mobile.contents.scan(/~/) do
        t << Regexp.last_match.begin(0)
      end
      t
    end

    it "detects a tab character" do
      short_desc = mobile.contents[tildes[0]..tildes[1]]
      mobile.contents[tildes[0]..tildes[1]] = short_desc.gsub!(" ", "\t")

      expect_one_error(mobile, Mobile.err_msg(:visible_tab))
    end

    it "detects a long desc that spans more than one line" do
      mobile.contents.insert(tildes[2], "\nThis is neat!\n")
      expect_one_error(mobile, Mobile.err_msg(:long_desc_spans))
    end

    it "detects a missing tilde in the description field" do
      mobile.contents[tildes[3]] = "x"
      expect_one_error(mobile, Mobile.err_msg(:description_no_tilde))
    end

  end

  context "parsing act/aff/align line" do

    # These specs are a bit brittle because they depend on the
    # specific MOBILES sample from Pariah's Paradise rather than
    # working for any valid mob.

    let(:mobile) do
      mobiles_section = Mobiles.new(data.dup)
      mobiles_section.split_children
      mobiles_section.children.first
    end

    # let(:line_begin) { mobile.contents.index(/^\d+(?:|\d+)* \d+(?:|\d+)* -?\d+ ?S\s*?$/) }
    # let(:act) { mobile.contents.index(/\d+/)] }

    it "detects a missing 'S'" do
      mobile.contents[/S$/] = ""
      expect_one_error(mobile, Mobile.err_msg(:no_terminating, "S"))
    end

    it "detects a missing ACT_NPC flag" do
      # Delete the 1 (act_npc) bitflag. Should be the first
      # 1 or 2 characters on the line
      mobile.contents[/^\d+\|/] = ""
      expect_one_error(mobile, Mobile.err_msg(:act_not_npc))
    end

    it "detects a bad act bit" do
      mobile.contents["1|2|32"] = "1|3|32"
      expect_one_error(mobile, Mobile.err_msg(:bad_bit, "Act"))
    end

    it "detects a non-numeric act field" do
      mobile.contents["1|2|32"] = "1|a|32"
      expect_one_error(mobile, Mobile.err_msg(:bad_field, "act flags"))
    end

    it "detects a bad affect bit" do
      mobile.contents["8|32|128"] = "8|66|128"
      expect_one_error(mobile, Mobile.err_msg(:bad_bit, "Affect"))
    end

    it "detects a non-numeric affect field" do
      mobile.contents["8|32|128"] = "a|32|128"
      expect_one_error(mobile, Mobile.err_msg(:bad_field, "affect flags"))
    end

    it "detects an invalid align field" do
      mobile.contents["-1000"] = "bad"
      expect_one_error(mobile, Mobile.err_msg(:bad_field, "align"))
    end

    it "detects an out-of-range alignment" do
      mobile.contents["-1000"] = "-1050"
      expect_one_error(mobile, Mobile.err_msg(:bad_align_range))
    end

    it "detects invalid line syntax" do
      mobile.contents[/^\d+(?:\|\d+)* \d+(?:\|\d+)* -?\d+ S$/] = "1 1 1 hey, bro, how's it going? S"
      expect_one_error(mobile, Mobile.err_msg(:act_aff_align_matches))
    end

  end

  context "parsing those boring middle lines" do

    let(:mobile) do
      mobiles_section = Mobiles.new(data.dup)
      mobiles_section.split_children
      mobiles_section.children.first
    end

    it "detects an invalid mob level" do
      mobile.contents[/^\d+ 0 0/] = "-5 0 0"
      expect_one_error(mobile, Mobile.err_msg(:bad_field, "level"))
    end

    it "detects wrong level line syntax" do
      mobile.contents[/^\d+ 0 0/] = "75 a a"
      expect_one_error(mobile, Mobile.err_msg(:level_matches))
    end

    it "detects wrong '0d0+0' line syntax" do
      mobile.contents[/0d0\+0/] = "ad0+0"
      expect_one_error(mobile, Mobile.err_msg(:constant_matches))
    end

    it "detects invalid sex field" do
      mobile.contents[/^0 0 \d/] = "0 0 4"
      expect_one_error(mobile, Mobile.err_msg(:bad_sex_range))
    end

    it "detects invalid sex line syntax" do
      mobile.contents[/^0 0 \d/] = "a b c"
      expect_one_error(mobile, Mobile.err_msg(:sex_matches))
    end

  end

  context "parsing misc fields" do

    let(:mobile) do
      mobiles_section = Mobiles.new(data.dup)
      mobiles_section.split_children
      mobiles_section.children.first
    end

    it "detects an out-of-range race"

    it "detects an invalid race"

    it "detects invalid text after the race field"

    it "detects a duplicated race field"

    it "detects an out-of-range class"

    it "detects an invalid class"

    it "detects invalid text after the class field"

    it "detects a duplicated class field"

    it "detects an out-of-range team"

    it "detects an invalid team"

    it "detects invalid text after the team field"

    it "detects a duplicated team field"

    it "detects an invalid misc field"

  end

  context "parsing a kspawn" do

    let(:mobile) do
      mobiles_section = Mobiles.new(data.dup)
      mobiles_section.split_children
      mobiles_section.children.first
    end

    it "detects a duplicated kspawn field"

    it "detects invalid kspawn syntax"

    it "detects a bad kspawn condition"

    it "detects a bad kspawn type bit"

    it "detects a bad kspawn vnum"

    it "detects a bad kspawn location"

    it "detects a visible tab"

    it "detects a kspawn with a missing tilde"

  end

end
