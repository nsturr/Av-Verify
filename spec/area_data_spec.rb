require "./spec/spec_helper"
require "./lib/sections/area_data"

data = File.read("./spec/test-areadata.are")

describe AreaData do

  let(:area_data) { AreaData.new(data.rstrip) }

  it "detects invalid text after its terminating S" do
    area_data.contents << "\nHi there"

    expect_one_error(area_data, AreaData.err_msg(:continues_after_delimeter))
  end

  it "detects a missing terminating S" do
    area_data.contents.chop!

    expect_one_error(area_data, AreaData.err_msg(:no_delimeter))
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

    expect_one_error(area_data, AreaData.err_msg(:duplicate) % line[0] )
  end

  it "calls the correct parse method for each line type" do
    expect(area_data).to receive(:parse_plane_line)
    expect(area_data).to receive(:parse_flags_line)
    expect(area_data).to receive(:parse_outlaw_line)
    expect(area_data).to receive(:parse_kspawn_line)
    expect(area_data).to receive(:parse_modifier_line)
    expect(area_data).to receive(:parse_group_exp_line)
    area_data.parse
  end

  context "when parsing a plane line" do

    it "detects invalid trailing text" do
      i, j = area_data.contents.match(/^P.*$/).offset(0)
      area_data.contents.insert(j, " writing rspec isn't my idea of a good saturday")

      expect_one_error(area_data, AreaData.err_msg(:invalid_extra_text) % "plane")
    end

    it "detects out-of-range planes" do
      i = area_data.contents.index(/(?<=P )\d/)
      area_data.contents.insert(i, "99")

      expect_one_error(area_data, AreaData.err_msg(:plane_out_of_range))
    end

    it "detects non-numeric planes" do
      i = area_data.contents.index(/(?<=P )\d/)
      area_data.contents[i] = "a"

      expect_one_error(area_data, AreaData.err_msg(:invalid_field) % "area plane")
    end

    it "detects out-of-range sectors" do
      i = area_data.contents.index(/(?<=P \d )\d/)
      area_data.contents.insert(i, "99")

      expect_one_error(area_data, AreaData.err_msg(:zone_out_of_range))
    end

    it "detects non-numeric sectors" do
      i = area_data.contents.index(/(?<=P \d )\d/)
      area_data.contents[i] = "a"

      expect_one_error(area_data, AreaData.err_msg(:invalid_field) % "area zone")
    end

    it "parses the plane and sector data"

  end

  context "when parsing an area flags line" do

    it "detects invalid trailing text" do
      i, j = area_data.contents.match(/^F.*$/).offset(0)
      area_data.contents.insert(j, " writing rspec isn't my idea of a good sturday")

      expect_one_error(area_data, AreaData.err_msg(:invalid_extra_text) % "area flags")
    end

    it "detects invalid bitfields" do
      i, j = area_data.contents.match(/^F.*$/).offset(0)
      area_data.contents.insert(j, "|abcdefg")

      expect_one_error(area_data, AreaData.err_msg(:bad_line) % "area flags")
    end

    it "detects bit flags that aren't a power of two" do
      i, j = area_data.contents.match(/^F.*$/).offset(0)
      area_data.contents.insert(j, "|19")

      expect_one_error(area_data, AreaData.err_msg(:bad_bit) % "Area flags")
    end

    it "parses the area flag data"

  end

  context "when parsing an outlaw line" do

    it "detects invalid trailing text" do
      i, j = area_data.contents.match(/^O.*$/).offset(0)
      area_data.contents.insert(j, " writing rspec isn't my idea of a goot saturday")

      expect_one_error(area_data, AreaData.err_msg(:invalid_extra_text) % "outlaw")
    end

    it "detects invalid non-numeric elements" do
      i, j = area_data.contents.match(/(?<=O )\d+/).offset(0)
      area_data.contents[i,2] = "hi"

      expect_one_error(area_data, AreaData.err_msg(:bad_line) % "outlaw")
    end

    it "parses the outlaw data"

  end

  context "when parsing a kspawn" do

    it "detects invalid non-numeric elements"

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
      # you don't see THEM whip-stopping the barnyard corral, now do ya.
      # Nope, you sure don't.
      expect(area_data.errors.one? do |error|
        error.description == AreaData.err_msg(:kspawn_no_tilde)
      end)
    end

    it "detects an extra tilde" do
      i = area_data.contents.index("~")
      area_data.contents.insert(i, " Hey, look at me!~")

      expect_one_error(area_data, AreaData.err_msg(:kspawn_extra_tilde))
    end

    it "parses the area kspawn"

  end

  context "when parsing an area modifier line" do

    it "detects invalid trailing text" do
      i, j = area_data.contents.match(/^M.*$/).offset(0)
      area_data.contents.insert(j, " writing rspec isn't my idea of a goot saturday")

      expect_one_error(area_data, AreaData.err_msg(:invalid_extra_text) % "area modifier")
    end

    it "detects invalid non-numeric elements" do
      i, j = area_data.contents.match(/(?<=M )\d+/).offset(0)
      area_data.contents[i,2] = "hi"

      expect_one_error(area_data, AreaData.err_msg(:bad_line) % "area modifier")
    end

    it "parses the area modification data"

  end

  context "when parsing a group exp modifier line" do

    it "detects invalid trailing text" do
      i, j = area_data.contents.match(/^G.*$/).offset(0)
      area_data.contents.insert(j, " writing rspec isn't my idea of a goot saturday")

      expect_one_error(area_data, AreaData.err_msg(:invalid_extra_text) % "group exp")
    end

    it "detects invalid non-numeric elements" do
      i, j = area_data.contents.match(/(?<=G )\d+/).offset(0)
      area_data.contents[i,2] = "hi"

      expect_one_error(area_data, AreaData.err_msg(:bad_line) % "group exp")
    end

    it "parses the group exp data"

  end

end
