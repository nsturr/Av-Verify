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

  it_should_behave_like LineByLineObject do
    let(:item) { mobile }
  end

  context "parsing text fields" do
    let(:mobile) do
      mobiles_section = Mobiles.new(data.dup)
      mobiles_section.split_children
      mobiles_section.children.first
    end

    # A handy array of indices to locate the four tilde-
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

    it "detects an out-of-range race" do
      mobile.contents[/^R \d+/] = "R 1050"
      expect_one_error(mobile, Mobile.err_msg(:race_out_of_bounds))
    end

    it "detects an invalid race" do
      mobile.contents[/^R \d+/] = "R abcdefg"
      expect_one_error(mobile, Mobile.err_msg(:non_numeric, "race"))
    end

    it "detects invalid text after the race field" do
      line = mobile.contents[/^R \d+/]
      mobile.contents[line] = line + " hey babe, what's up?"

      expect_one_error(mobile, Mobile.err_msg(:invalid_text_after, "race"))
    end

    it "detects a duplicated race field" do
      line = mobile.contents[/^R \d+/]
      i = mobile.contents.index(line)
      mobile.contents.insert(i, line+"\n")

      expect_one_error(mobile, Mobile.err_msg(:race_duplicated))
    end

    it "detects an out-of-range class" do
      mobile.contents[/^C \d+/] = "C 1050"
      expect_one_error(mobile, Mobile.err_msg(:class_out_of_bounds))
    end

    it "detects an invalid class" do
      mobile.contents[/^C \d+/] = "C abcdefg"
      expect_one_error(mobile, Mobile.err_msg(:non_numeric, "class"))
    end

    it "detects invalid text after the class field" do
      line = mobile.contents[/^C \d+/]
      mobile.contents[line] = line + " hey babe, what's up?"

      expect_one_error(mobile, Mobile.err_msg(:invalid_text_after, "class"))
    end

    it "detects a duplicated class field" do
      line = mobile.contents[/^C \d+/]
      i = mobile.contents.index(line)
      mobile.contents.insert(i, line+"\n")

      expect_one_error(mobile, Mobile.err_msg(:class_duplicated))
    end

    it "detects an out-of-range team" do
      mobile.contents[/^L \d+/] = "L 1050"
      expect_one_error(mobile, Mobile.err_msg(:team_out_of_bounds))
    end

    it "detects an invalid team" do
      mobile.contents[/^L \d+/] = "L abcdefg"
      expect_one_error(mobile, Mobile.err_msg(:non_numeric, "team"))
    end

    it "detects invalid text after the team field" do
      line = mobile.contents[/^L \d+/]
      mobile.contents[line] = line + " hey babe, what's up?"

      expect_one_error(mobile, Mobile.err_msg(:invalid_text_after, "team"))
    end

    it "detects a duplicated team field" do
      line = mobile.contents[/^L \d+/]
      i = mobile.contents.index(line)
      mobile.contents.insert(i, line+"\n")

      expect_one_error(mobile, Mobile.err_msg(:team_duplicated))
    end

    it "detects an invalid misc field" do
      mobile.contents.rstrip!
      mobile.contents << "\nTOTALLY INVALID\n"
      expect_one_error(mobile, Mobile.err_msg(:invalid_extra_field))
    end

  end

  context "parsing a kspawn" do

    let(:mobile) do
      mobiles_section = Mobiles.new(data.dup)
      mobiles_section.split_children
      mobiles_section.children.first
    end

    it "detects a duplicated kspawn field" do
      line = mobile.contents[/^K \d+ \d+ -?\d+ -?\d+ .*?~/]
      i = mobile.contents.index(line)
      mobile.contents.insert(i, line+"\n")

      expect_one_error(mobile, Mobile.err_msg(:kspawn_duplicated))
    end

    # test for invalid after tilde, for real

    it "detects invalid kspawn syntax" do
      mobile.contents[/^K.*~/] = "K 1 2 ~"
      expect_one_error(mobile, Mobile.err_msg(:not_enough_tokens))
    end

    it "detects a bad kspawn condition" do
      mobile.contents[/(?<=^K )\d+/] = "a"
      expect_one_error(mobile, Mobile.err_msg(:non_numeric_or_neg, "kspawn condition"))
    end

    it "detects a bad kspawn type bit" do
      mobile.contents[/(?<=^K \d )\d+/] = "2|3"
      expect_one_error(mobile, Mobile.err_msg(:bad_bit, "Kspawn type"))
    end

    it "detects a bad kspawn vnum" do
      mobile.contents[/(?<=^K \d \d )\d+/] = "-12345"
      expect_one_error(mobile, Mobile.err_msg(:non_numeric_or_neg, "kspawn vnum"))
    end

    it "detects a bad kspawn location" do
      mobile.contents[/(?<=^K \d \d \d{5} )-?\d+/] = "-12345"
      expect_one_error(mobile, Mobile.err_msg(:non_numeric_or_neg, "kspawn location"))
    end

    it "detects a visible tab" do
      line = mobile.contents[/^K.*~/].gsub(" ", "\t")
      mobile.contents[/^K.*~/] = line

      expect_one_error(mobile, Mobile.err_msg(:visible_tab))
    end

    it "detects a kspawn with a missing tilde" do
      line = mobile.contents[/^K.*~/]
      mobile.contents[/^K.*~/] = line[0...-1]

      # TODO: The hardcoded line numbers (two params) are super brittle
      # determine them programmatically somehow
      expect_one_error(mobile, Mobile.err_msg(:kspawn_no_tilde, 21, 22))
    end

  end

end
