require "./spec/spec_helper"
require "./lib/sections/area_data"

data = File.read("./spec/test-areadata.are")

describe AreaData do

  let(:area_data) { AreaData.new(contents: data.rstrip) }

  it "detects invalid text after its terminating S" do
    area_data.contents << "\nHi there"

    expect_one_error(area_data, AreaData.err_msg(:continues_after_delimiter))
  end

  it "detects a missing terminating S" do
    area_data.contents.chop!

    expect_one_error(area_data, AreaData.err_msg(:no_delimiter))
  end

  it "detects invalid line types" do
    i = area_data.contents.index(/^S$/)
    area_data.contents.insert(i, "Z The flugelhorn watches you sleep\n")

    expect_one_error(area_data, AreaData.err_msg(:invalid_line))
  end

  it "detects line types that are repeated" do
    m = area_data.contents.match(/^O.*\n/)
    line, i = m[0], m.begin(0)
    area_data.contents.insert(i, line)

    expect_one_error(area_data, AreaData.err_msg(:duplicate, line[0]))
  end

  it "calls the correct parse method for each line type" do
    expect(area_data).to receive(:parse_plane_line)
    expect(area_data).to receive(:parse_flags_line)
    expect(area_data).to receive(:parse_outlaw_line)
    expect(area_data).to receive(:parse_kspawn_line)
    expect(area_data).to receive(:parse_modifiers_line)
    expect(area_data).to receive(:parse_group_exp_line)
    area_data.parse
  end

  context "when parsing a plane line" do

    it "detects invalid trailing text" do
      i, j = area_data.contents.match(/^P.*$/).offset(0)
      area_data.contents.insert(j, " writing rspec isn't my idea of a good saturday")

      expect_one_error(area_data, AreaData.err_msg(:invalid_extra_text, "plane"))
    end

    it "detects out-of-range planes" do
      i = area_data.contents.index(/(?<=P )\d/)
      area_data.contents.insert(i, "99")

      expect_one_error(area_data, AreaData.err_msg(:plane_out_of_range))
    end

    it "detects non-numeric planes" do
      i = area_data.contents.index(/(?<=P )\d/)
      area_data.contents[i] = "a"

      expect_one_error(area_data, AreaData.err_msg(:invalid_field, "area plane"))
    end

    it "detects out-of-range zone" do
      i = area_data.contents.index(/(?<=P \d )\d/)
      area_data.contents.insert(i, "99")

      expect_one_error(area_data, AreaData.err_msg(:zone_out_of_range))
    end

    it "detects non-numeric zone" do
      i = area_data.contents.index(/(?<=P \d )\d/)
      area_data.contents[i] = "a"

      expect_one_error(area_data, AreaData.err_msg(:invalid_field, "area zone"))
    end

    it "parses the plane and zone data" do
      area_data.parse

      expect(area_data.plane).to eq(2)
      expect(area_data.zone).to eq(1)
    end

  end

  context "when parsing an area flags line" do

    it "detects invalid trailing text" do
      i, j = area_data.contents.match(/^F.*$/).offset(0)
      area_data.contents.insert(j, " writing rspec isn't my idea of a good sturday")

      expect_one_error(area_data, AreaData.err_msg(:invalid_extra_text, "area flags"))
    end

    it "detects invalid bitfields" do
      i, j = area_data.contents.match(/^F.*$/).offset(0)
      area_data.contents.insert(j, "|abcdefg")

      expect_one_error(area_data, AreaData.err_msg(:bad_line, "area flags"))
    end

    it "detects bit flags that aren't a power of two" do
      i, j = area_data.contents.match(/^F.*$/).offset(0)
      area_data.contents.insert(j, "|19")

      expect_one_error(area_data, AreaData.err_msg(:bad_bit, "Area flags"))
    end

    it "parses the area flag data" do
      area_data.parse

      expect(area_data.flags).to be_an_instance_of(Bits)
      expect(area_data.flags.bit? 2).to be_true
      expect(area_data.flags.bit? 16).to be_true
    end

  end

  context "when parsing an outlaw line" do

    it "detects invalid trailing text" do
      i, j = area_data.contents.match(/^O.*$/).offset(0)
      area_data.contents.insert(j, " writing rspec isn't my idea of a goot saturday")

      expect_one_error(area_data, AreaData.err_msg(:invalid_extra_text, "outlaw"))
    end

    it "detects invalid non-numeric elements" do
      i, j = area_data.contents.match(/(?<=O )\d+/).offset(0)
      area_data.contents[i,2] = "hi"

      expect_one_error(area_data, AreaData.err_msg(:invalid_field, "outlaw"))
    end

    it "parses the outlaw data" do
      area_data.parse

      expect(area_data.outlaw[:dump_vnum]).to eq(11423)
      expect(area_data.outlaw[:jail_vnum]).to eq(11406)
      expect(area_data.outlaw[:death_row_vnum]).to eq(11498)
      expect(area_data.outlaw[:executioner_vnum]).to eq(11400)
      expect(area_data.outlaw[:justice_factor]).to eq(150)
    end

  end

  context "when parsing a kspawn" do

    it "detects invalid non-numeric elements" do
      i = area_data.contents.index("-1")
      area_data.contents.insert(i, "hi")

      expect_one_error(area_data, AreaData.err_msg(:invalid_field, "seeker"))
    end

    it "can parse a kspawn spanning multiple lines" do
      i = area_data.contents.index("~")
      area_data.contents.insert(i, "\nDon't mind me, just inserting another line")

      area_data.parse
      expect(area_data.errors).to be_empty
    end

    it "detects a kspawn with a missing tilde" do
      i = area_data.contents.index("~")
      area_data.contents[i] = "!"

      area_data.parse

      # This syntax rubs me the wrong way, but then so do porcupines, and
      # you don't see THEM varnishing the shingles at the barnyard corral,
      # now do ya. Nope, you sure don't.
      expect(area_data.errors.one? do |error|
        error.description == TheTroubleWithTildes.err_msg(:absent)
      end)
      # This emporary insanity brought to you by Lumoloth, the deceiver.
    end

    it "detects an extra tilde" do
      i = area_data.contents.index("~")
      area_data.contents.insert(i, " Hey, look at me!~")

      expect_one_error(area_data, TheTroubleWithTildes.err_msg(:extra))
    end

    it "parses the area kspawn" do
      area_data.parse

      expect(area_data.kspawn).to_not be_nil
      expect(area_data.kspawn[:condition]).to eq(1)
      expect(area_data.kspawn[:command]).to eq(3)
      expect(area_data.kspawn[:mob_vnum]).to eq(8623)
      expect(area_data.kspawn[:room_vnum]).to eq(-1)
      expect(area_data.kspawn[:text]).to eq("Oh dear, what have you done?")
    end

  end

  context "when parsing an area modifiers line" do

    it "detects invalid trailing text" do
      i, j = area_data.contents.match(/^M.*$/).offset(0)
      area_data.contents.insert(j, " writing rspec isn't my idea of a goot saturday")

      expect_one_error(area_data, AreaData.err_msg(:invalid_extra_text, "area modifiers"))
    end

    it "detects invalid non-numeric elements" do
      i, j = area_data.contents.match(/(?<=M )\d+/).offset(0)
      area_data.contents[i] = "h"

      expect_one_error(area_data, AreaData.err_msg(:invalid_field, "area modifiers"))
    end

    it "parses the area modifiers data" do
      area_data.parse

      expect(area_data.modifiers).to_not be_nil
      expect(area_data.modifiers[:xpgain_mod]).to eq(0)
      expect(area_data.modifiers[:hp_regen_mod]).to eq(13)
      expect(area_data.modifiers[:mana_regen_mod]).to eq(14)
      expect(area_data.modifiers[:move_regen_mod]).to eq(15)
      expect(area_data.modifiers[:statloss_mod]).to eq(50)
      expect(area_data.modifiers[:respawn_room]).to eq(11499)
    end

  end

  context "when parsing a group exp modifier line" do

    it "detects invalid trailing text" do
      i, j = area_data.contents.match(/^G.*$/).offset(0)
      area_data.contents.insert(j, " writing rspec isn't my idea of a goot saturday")

      expect_one_error(area_data, AreaData.err_msg(:invalid_extra_text, "group exp"))
    end

    it "detects invalid non-numeric elements" do
      i, j = area_data.contents.match(/(?<=G )\d+/).offset(0)
      area_data.contents[i,2] = "hi"

      expect_one_error(area_data, AreaData.err_msg(:invalid_field, "group exp"))
    end

    it "parses the group exp data" do
      area_data.parse

      expect(area_data.group_exp).to_not be_nil
      expect(area_data.group_exp[:pct0]).to eq(100)
      expect(area_data.group_exp[:num1]).to eq(7)
      expect(area_data.group_exp[:pct1]).to eq(45)
      expect(area_data.group_exp[:num2]).to eq(11)
      expect(area_data.group_exp[:pct2]).to eq(10)
      expect(area_data.group_exp[:pct3]).to eq(1)
      expect(area_data.group_exp[:diversity]).to eq(25)
    end

  end

end
