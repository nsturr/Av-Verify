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

  it "detects a missing tilde" do
    missing_tilde.parse
    expect(missing_tilde.errors.length).to eq(1)
    expect(missing_tilde.errors.first.description).to eq(AreaHeader.err_msg(:missing_tilde))
  end

  it "detects an extra invalid tilde" do
    extra_tilde.parse
    expect(extra_tilde.errors.length).to eq(1)
    expect(extra_tilde.errors.first.description).to eq(AreaHeader.err_msg(:extra_tilde))
  end

  it "detects a header spanning multiple lines" do
    multi_line.parse
    expect(multi_line.errors.length).to eq(1)
    expect(multi_line.errors.first.description).to eq(AreaHeader.err_msg(:multi_line))
  end

  it "detects the wrong number of characters in the level range" do
    bad_range.parse
    expect(bad_range.errors.length).to eq(1)
    expect(bad_range.errors.first.description).to eq(AreaHeader.err_msg(:bad_range))
  end

  it "detects missing braces around the level range" do
    no_braces.parse
    expect(no_braces.errors.length).to eq(1)
    expect(no_braces.errors.first.description).to eq(AreaHeader.err_msg(:no_braces))
  end

end
