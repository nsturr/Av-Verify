require "./spec/spec_helper"
require "./lib/sections/area_header"

describe AreaHeader do

  let(:valid_header) { AreaHeader.new("#AREA {*HERO*} Scevine The Forge~") }
  let(:missing_tilde) { AreaHeader.new("#AREA {51  51} Quietus Shadow Keep") }
  let(:extra_tilde) { AreaHeader.new("#AREA {51  51} Quietus~ Shadow Keep~") }
  let(:multi_line) { AreaHeader.new("#AREA {51  51}\nScevine Pariah's Paradise~") }
  let(:bad_range) { AreaHeader.new("#AREA {51 51} Quietus Shadow Keep~") }
  let(:no_braces) { AreaHeader.new("#AREA {*HERO* Scevine The Forge~") }

  it "lets valid headers pass" do
    valid_header.parse
    expect(valid_header.errors).to be_empty
  end

  it "parses the level range" do
    valid_header.parse
    expect(valid_header.level).to eq("*HERO*")
  end

  it "parses the area builder" do
    valid_header.parse
    expect(valid_header.author).to eq("Scevine")
  end

  it "parses the area name" do
    valid_header.parse
    expect(valid_header.name).to eq("The Forge")
  end

  it "detects a missing tilde" do
    expect_one_error(missing_tilde, AreaHeader.err_msg(:missing_tilde))
  end

  it "detects an extra invalid tilde" do
    expect_one_error(extra_tilde, AreaHeader.err_msg(:extra_tilde))
  end

  it "detects a header spanning multiple lines" do
    expect_one_error(multi_line, AreaHeader.err_msg(:multi_line))
  end

  it "detects the wrong number of characters in the level range" do
    expect_one_error(bad_range, AreaHeader.err_msg(:bad_range))
  end

  it "detects missing braces around the level range" do
    expect_one_error(no_braces, AreaHeader.err_msg(:no_braces))
  end

end
