require "./lib/sections/area_header"

describe AreaHeader do

  let(:valid_header) { "#AREA {*HERO*} Scevine The Forge~" }
  let(:missing_tilde) { "#AREA {51  51} Quietus Shadow Keep" }
  let(:multi_line) { "#AREA {51  51}\nScevine Pariah's Paradise~" }
  let(:bad_range) { "#AREA {51 51} Quietus Shadow Keep" }

  it "lets valid headers pass"

  it "detects a missing tilde"

  it "detects a header spanning multiple lines"

  it "detects the wrong number of characters in the level range"

end
